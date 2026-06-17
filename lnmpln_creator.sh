#!/bin/bash

# ==============================================================================
# DIRECTORY AND FILE CONFIGURATION
# ==============================================================================
DB_DIR="$HOME/.cache/flight_dispatch"
LNM_OUTPUT_FILE="$DB_DIR/briefing.lnmpln"
LNM_RECENT_PLAN="$HOME/.config/ABarthel/little_navmap.lnmpln"

mkdir -p "$DB_DIR"

# 1. Read the raw text stream from the standard input process pipeline (tee)
RAW_STREAM=$(cat)

# ==============================================================================
# 2. LANGUAGE-AGNOSTIC BRIEFING EXTRACTION (Structural Boundary Isolation)
# ==============================================================================
# Drops everything from the start through the SECOND line starting with '=',
# and drops everything from the FINAL line starting with '=' to the end of stream.
briefing=$(echo "$RAW_STREAM" | awk '
    /^=/ { eq_count++ }
    
    # Core Strategy: Only capture data when we are inside the briefing body
    eq_count == 2 && !/^=/ { 
        lines[++idx] = $0 
    }
    
    END { 
        for (i = 1; i <= idx; i++) print lines[i] 
    }
')

# Safety catch: If stream does not contain a structured briefing matrix, wipe and abort
if [ -z "$briefing" ]; then
    : > "$LNM_OUTPUT_FILE"
    exit 0
fi

# 3. Parse the destination ICAO marker out of the raw text stream
DEST_ICAO=$(echo "$RAW_STREAM" | grep -oP '\(ICAO: \K[A-Z0-9]+' | head -n 1)

# ==============================================================================
# 4. RESOLVE DEPARTURE POINT VIA RECENT LITTLE NAVMAP WORKSPACE FILE
# ==============================================================================
DEP_ICAO=""

if [ -f "$LNM_RECENT_PLAN" ]; then
    # Capture the LAST waypoint identifier tag inside the active flight plan
    DEP_ICAO=$(grep -oP '(?<=<Ident>)[A-Z0-9]+(?=</Ident>)' "$LNM_RECENT_PLAN" | tail -n 1)
fi

# Global baseline safety fallback if the active tracker is unreadable or empty
if [ -z "$DEP_ICAO" ]; then
    DEP_ICAO="LGTS"
fi

# ==============================================================================
# 5. DETECT LOCAL FLIGHT VS CROSS-COUNTRY ROUTE
# ==============================================================================
# If briefing was extracted but no destination ICAO is resolved, it's a valid local flight
if [ -z "$DEST_ICAO" ]; then
    FINAL_DEST_ICAO="$DEP_ICAO"
    WAYPOINT_BLOCK="      <Waypoint>
        <Ident>${DEP_ICAO}</Ident>
        <Type>AIRPORT</Type>
      </Waypoint>"
else
    FINAL_DEST_ICAO="$DEST_ICAO"
    WAYPOINT_BLOCK="      <Waypoint>
        <Ident>${DEP_ICAO}</Ident>
        <Type>AIRPORT</Type>
      </Waypoint>
      <Waypoint>
        <Ident>${FINAL_DEST_ICAO}</Ident>
        <Type>AIRPORT</Type>
      </Waypoint>"
fi

# ==============================================================================
# 6. COMPILE STRUCTURAL LITTLE NAVMAP SPECIFICATION ENGINE (XML Layout)
# ==============================================================================

# Escape XML illegal tokens to secure structural parsing consistency across profiles
XML_REMARKS=$(echo "$briefing" | awk '{
    gsub(/&/, "\\&amp;");
    gsub(/</, "\\&lt;");
    gsub(/>/, "\\&gt;");
    print
}')
TIMESTAMP=$(date +'%Y-%m-%dT%H:%M:%S%:z')

cat <<EOF > "$LNM_OUTPUT_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<LittleNavmap xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://www.littlenavmap.org/schema/lnmpln.xsd">
  <Flightplan>
    <Header>
      <FlightplanType>VFR</FlightplanType>
      <CruisingAlt>4500</CruisingAlt>
      <CruisingAltF>4500.00000000</CruisingAltF>
      <Comment>${XML_REMARKS}</Comment>
      <CreationDate>${TIMESTAMP}</CreationDate>
      <FileVersion>1.2</FileVersion>
      <ProgramName>Little Navmap</ProgramName>
      <ProgramVersion>3.0.18</ProgramVersion>
      <Documentation>https://www.littlenavmap.org/lnmpln.html</Documentation>
    </Header>
    <SimData Cycle="1801">NAVIGRAPH</SimData>
    <NavData Cycle="1801">NAVIGRAPH</NavData>
    <AircraftPerformance>
      <FilePath>My initial Cessna 2POB.lnmperf</FilePath>
      <Type>c172p</Type>
      <Name>Cessna 172P Skyhawk (1982)</Name>
    </AircraftPerformance>
    <Waypoints>
${WAYPOINT_BLOCK}
    </Waypoints>
  </Flightplan>
</LittleNavmap>
EOF
