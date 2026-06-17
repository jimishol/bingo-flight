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

# 2. Isolate the Briefing block using structural terminal boundaries
# Note: Keeping Greek matching labels as the flight engine outputs localized text
briefing=$(echo "$RAW_STREAM" | sed -n '/^Προορισμός/,/^• Φορτίο/p')

# Safety catch: If briefing is empty (e.g. execution error), clear the plan file and abort
# Uses explicit null command ':' before redirection to prevent LSP/linter warnings
if [ -z "$briefing" ]; then
    : > "$LNM_OUTPUT_FILE"
    exit 0
fi

# 3. Parse the destination ICAO marker out of the raw text stream
DEST_ICAO=$(echo "$RAW_STREAM" | grep -oP '\(ICAO: \K[A-Z0-9]+' | head -n 1)

# Abort cleanly by blanking out the layout file if no target airfield is resolved
if [ -z "$DEST_ICAO" ]; then
    : > "$LNM_OUTPUT_FILE"
    exit 0
fi

# ==============================================================================
# 4. RESOLVE DEPARTURE POINT VIA RECENT LITTLE NAVMAP WORKSPACE FILE
# ==============================================================================
DEP_ICAO=""

if [ -f "$LNM_RECENT_PLAN" ]; then
    # Capture the LAST waypoint identifier tag inside the active flight plan
    # (Your previous destination footprint acts as your current departure node)
    DEP_ICAO=$(grep -oP '(?<=<Ident>)[A-Z0-9]+(?=</Ident>)' "$LNM_RECENT_PLAN" | tail -n 1)
fi

# Global baseline safety fallback if the active tracker is unreadable or empty
if [ -z "$DEP_ICAO" ]; then
    DEP_ICAO="LGTS"
fi

FINAL_DEST_ICAO="$DEST_ICAO"

# ==============================================================================
# 5. COMPILE STRUCTURAL LITTLE NAVMAP SPECIFICATION ENGINE (XML Layout)
# ==============================================================================

# Escape XML illegal tokens to secure structural parsing consistency across profiles
XML_REMARKS=$(echo "$briefing" | sed 's/&/\&amp;/g' | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
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
      <Waypoint>
        <Ident>${DEP_ICAO}</Ident>
        <Type>AIRPORT</Type>
      </Waypoint>
      <Waypoint>
        <Ident>${FINAL_DEST_ICAO}</Ident>
        <Type>AIRPORT</Type>
      </Waypoint>
    </Waypoints>
  </Flightplan>
</LittleNavmap>
EOF
