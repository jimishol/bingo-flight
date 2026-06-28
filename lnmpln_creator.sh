#!/bin/bash

# ==============================================================================
# USER CONFIGURATION: DEPARTURE POINT INGESTION STRATEGY
# ==============================================================================
# Choose one of the following routing hierarchies:
#   "a" -> 1-2-A-3 : LNM Logbook -> LNM Cache -> FlightGear Live Log -> Null Fallback
#   "b" -> A-1-2-3 : FlightGear Live Log -> LNM Logbook -> LNM Cache -> Null Fallback
#   "c" -> 3       : Absolute Reset (Always start with a blank departure point)
DEPARTURE_STRATEGY="b"

# ==============================================================================
# DIRECTORY AND FILE CONFIGURATION
# ==============================================================================
# Source flight.conf to import HOME_ICAO
CONF_FILE="$(dirname "$0")/flight.conf"
if [ -f "$CONF_FILE" ]; then
    source "$CONF_FILE"
fi

# ==============================================================================
# DIRECTORY AND FILE CONFIGURATION
# ==============================================================================
DB_DIR="$HOME/.cache/flight_dispatch"
LNM_OUTPUT_FILE="$DB_DIR/briefing.lnmpln"
FGFP_OUTPUT_FILE="$DB_DIR/briefing.fgfp"

LNM_RECENT_PLAN="$HOME/.config/ABarthel/little_navmap.lnmpln"
LNM_LOGBOOK_DB="$HOME/.config/ABarthel/little_navmap_db/little_navmap_logbook.sqlite"
FG_LOG_FILE="$HOME/.fgfs/fgfs.log"

mkdir -p "$DB_DIR"

RAW_STREAM=$(cat)

# ==============================================================================
# 2. LANGUAGE-AGNOSTIC BRIEFING EXTRACTION & DESTINATION
# ==============================================================================
# If the user selected "No", flight.sh prints the "❌" symbol.
# If detected, clear any existing briefing files and exit immediately.
if echo "$RAW_STREAM" | grep -q "❌"; then
  : > "$LNM_OUTPUT_FILE"
  : > "$FGFP_OUTPUT_FILE"
  exit 0
fi

briefing=$(echo "$RAW_STREAM" | awk '
  /^=/ { eq_count++ }
  eq_count == 2 && !/^=/ { lines[++idx] = $0 }
  END { for (i = 1; i <= idx; i++) print lines[i] }
')

if [ -z "$briefing" ]; then
  : > "$LNM_OUTPUT_FILE"
  : > "$FGFP_OUTPUT_FILE"
  exit 0
fi

DEST_ICAO=$(echo "$RAW_STREAM" | grep -oP '\(ICAO: \K[A-Z0-9]+' | head -n 1)

# ==============================================================================
# 3. MODULAR RESOLUTION FUNCTIONS
# ==============================================================================

get_lnm_logbook() {
  if [ -f "$LNM_LOGBOOK_DB" ]; then
    python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('$LNM_LOGBOOK_DB')
    cursor = conn.cursor()
    cursor.execute('SELECT destination_ident FROM logbook WHERE destination_ident IS NOT NULL ORDER BY departure_time DESC LIMIT 1')
    row = cursor.fetchone()
    if row and row[0].strip().isalnum():
        print(row[0].strip())
    conn.close()
except Exception:
    pass
" 2>/dev/null
  fi
}

get_lnm_cache() {
  if [ -f "$LNM_RECENT_PLAN" ]; then
    grep -oP '(?<=<Ident>)[A-Z0-9]+(?=</Ident>)' "$LNM_RECENT_PLAN" | tail -n 1
  fi
}

get_fg_live_log() {
  if [ -f "$FG_LOG_FILE" ]; then
    # Extracts the last matching ICAO identifier from the FG Environment Manager string
    grep -oP 'FGEnvironmentMgr::updateClosestAirport: selected:\s*\K[A-Z0-9]+' "$FG_LOG_FILE" | tail -n 1
  fi
}

# ==============================================================================
# 4. RESOLVE DEPARTURE POINT BY STRATEGY EVALUATION
# ==============================================================================
DEP_ICAO=""

case "$DEPARTURE_STRATEGY" in
  "a")
    # Hierarchy: 1 -> 2 -> A -> 3
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_lnm_logbook)
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_lnm_cache)
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_fg_live_log)
    ;;
  "b")
    # Hierarchy: A -> 1 -> 2 -> 3
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_fg_live_log)
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_lnm_logbook)
    [ -z "$DEP_ICAO" ] && DEP_ICAO=$(get_lnm_cache)
    ;;
  "c"|*)
    # Hierarchy: 3 (Force absolute null reset)
    DEP_ICAO=""
    ;;
esac

[ -z "$DEP_ICAO" ] && DEP_ICAO=""

# ==============================================================================
# 5. ROUTE GEOMETRY COMPILATION
# ==============================================================================
if [ -z "$DEST_ICAO" ]; then
  FINAL_DEST_ICAO="$DEP_ICAO"
else
  FINAL_DEST_ICAO="$DEST_ICAO"
fi

# FlightGear protective guard: Forces fallback to HOME_ICAO if strategy returns empty,
# preventing the simulator routing engine from collapsing or defaulting to KSFO.
HOME_DEP_ICAO="${DEP_ICAO:-$HOME_ICAO}"

# ==============================================================================
# 6. EXPORT TEMPLATE COMPILATION ENGINE
# ==============================================================================
XML_REMARKS=$(echo "$briefing" | awk '{
  gsub(/&/, "\\&amp;");
  gsub(/</, "\\&lt;");
  gsub(/>/, "\\&gt;");
  print
}')
TIMESTAMP=$(date +'%Y-%m-%dT%H:%M:%S%:z')

# Setup LNM Waypoints
# ------------------------------------------------------------------------------
# BEHAVIOR TOGGLE: By default, LNM allows empty strings if detection fails. 
# If you prefer LNM to mirror FlightGear's behavior and fall back to HOME_ICAO,
# swap out ${DEP_ICAO} with ${HOME_DEP_ICAO} in the block variables below.
# ------------------------------------------------------------------------------
if [ -z "$DEST_ICAO" ]; then
  LNM_WAYPOINT_BLOCK="      <Waypoint>\n        <Ident>${DEP_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>"
  # Mirror FlightGear alternative:
  # LNM_WAYPOINT_BLOCK="      <Waypoint>\n        <Ident>${HOME_DEP_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>"
else
  LNM_WAYPOINT_BLOCK="      <Waypoint>\n        <Ident>${DEP_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>\n      <Waypoint>\n        <Ident>${FINAL_DEST_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>"
  # Mirror FlightGear alternative:
  # LNM_WAYPOINT_BLOCK="      <Waypoint>\n        <Ident>${HOME_DEP_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>\n      <Waypoint>\n        <Ident>${FINAL_DEST_ICAO}</Ident>\n        <Type>AIRPORT</Type>\n      </Waypoint>"
fi

# Write Little Navmap format
cat <<EOF > "$LNM_OUTPUT_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<LittleNavmap xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="https://www.littlenavmap.org/schema/lnmpln.xsd">
  <Flightplan>
    <Header>
      <Comment>${XML_REMARKS}</Comment>
      <CreationDate>${TIMESTAMP}</CreationDate>
      <FileVersion>1.2</FileVersion>
      <ProgramName>Little Navmap</ProgramName>
      <ProgramVersion>3.0.18</ProgramVersion>
    </Header>
    <Waypoints>
$(echo -e "$LNM_WAYPOINT_BLOCK")
    </Waypoints>
  </Flightplan>
</LittleNavmap>
EOF

cat <<EOF > "$FGFP_OUTPUT_FILE"
<?xml version="1.0"?>
<PropertyList>
  <version type="int">2</version>
  <is-route type="bool">true</is-route>
  <flight-rules type="string">V</flight-rules>
  <flight-type type="string">X</flight-type>
  <remarks type="string">${XML_REMARKS}</remarks>
  <departure>
    <airport type="string">${HOME_DEP_ICAO}</airport>
  </departure>
  <destination>
    <airport type="string">${FINAL_DEST_ICAO}</airport>
  </destination>
  <route>
    <wp>
      <type type="string">navaid</type>
      <departure type="bool">true</departure>
      <ident type="string">${HOME_DEP_ICAO}</ident>
    </wp>
    <wp n="1">
      <type type="string">navaid</type>
      <approach type="bool">true</approach>
      <ident type="string">${FINAL_DEST_ICAO}</ident>
    </wp>
  </route>
</PropertyList>
EOF
