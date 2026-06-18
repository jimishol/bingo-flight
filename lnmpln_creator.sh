#!/bin/bash

# ==============================================================================
# DIRECTORY AND FILE CONFIGURATION
# ==============================================================================
DB_DIR="$HOME/.cache/flight_dispatch"
LNM_OUTPUT_FILE="$DB_DIR/briefing.lnmpln"
LNM_RECENT_PLAN="$HOME/.config/ABarthel/little_navmap.lnmpln"
LNM_LOGBOOK_DB="$HOME/.config/ABarthel/little_navmap_db/little_navmap_logbook.sqlite"

mkdir -p "$DB_DIR"

# 1. Read the raw text stream from the standard input process pipeline (tee)
RAW_STREAM=$(cat)

# ==============================================================================
# 2. LANGUAGE-AGNOSTIC BRIEFING EXTRACTION (Structural Boundary Isolation)
# ==============================================================================
briefing=$(echo "$RAW_STREAM" | awk '
  /^=/ { eq_count++ }
  eq_count == 2 && !/^=/ { lines[++idx] = $0 }
  END { for (i = 1; i <= idx; i++) print lines[i] }
')

if [ -z "$briefing" ]; then
  : > "$LNM_OUTPUT_FILE"
  exit 0
fi

DEST_ICAO=$(echo "$RAW_STREAM" | grep -oP '\(ICAO: \K[A-Z0-9]+' | head -n 1)

# ==============================================================================
# 3. RESOLVE DEPARTURE POINT (LOGBOOK DB -> FALLBACK TO RECENT PLAN)
# ==============================================================================
DEP_ICAO=""

# Option A: Always query the SQLite logbook first for the true last landing site
if [ -f "$LNM_LOGBOOK_DB" ]; then
  DEP_ICAO=$(python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('$LNM_LOGBOOK_DB')
    cursor = conn.cursor()
    cursor.execute('''
        SELECT destination_ident 
        FROM logbook 
        WHERE destination_ident IS NOT NULL 
        ORDER BY departure_time DESC 
        LIMIT 1
    ''')
    row = cursor.fetchone()
    if row:
        ident = row[0].strip()
        # Ensure it is a valid ICAO, rejecting degree-based coordinates
        if ident.isalnum():
            print(ident)
    conn.close()
except Exception:
    pass
" 2>/dev/null)
fi

# Option B: Fallback to the current legacy behavior (most recent flight plan)
if [ -z "$DEP_ICAO" ] && [ -f "$LNM_RECENT_PLAN" ]; then
  DEP_ICAO=$(grep -oP '(?<=<Ident>)[A-Z0-9]+(?=</Ident>)' "$LNM_RECENT_PLAN" | tail -n 1)
fi

if [ -z "$DEP_ICAO" ]; then
  case "$LNM_OUTPUT_FILE" in
    "$DB_DIR"/*) rm -f -- "$LNM_OUTPUT_FILE" ;;
    *) printf 'Refusing to remove %s — not inside %s\n' "$LNM_OUTPUT_FILE" "$DB_DIR" >&2 ;;
  esac
fi

# ==============================================================================
# 4. DETECT LOCAL FLIGHT VS CROSS-COUNTRY ROUTE
# ==============================================================================
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
# 5. COMPILE STRUCTURAL LITTLE NAVMAP SPECIFICATION ENGINE (XML Layout)
# ==============================================================================
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
