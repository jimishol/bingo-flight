#!/bin/bash

# ==============================================================================
# CONFIGURATION & VEHICLE TIER HIERARCHY
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the user preferences; crashes cleanly if missing
source "$SCRIPT_DIR/flight.conf"

# Resolve localization: if empty, slice the first 2 characters of $LANG (fallback to "en")
LOCALIZATION="${LOCALIZATION:-${LANG:0:2}}"

# ==============================================================================
# LOCALIZATION ENGINE: STRICT INTERFACE PARSER (NO SAFENETS)
# ==============================================================================
INTERFACE_FILE=""
TARGET_LOC_FILE="$SCRIPT_DIR/stories/$LOCALIZATION/interface.txt"
BASELINE_EN_FILE="$SCRIPT_DIR/stories/en/interface.txt"

# Select local override file, or fall back to English baseline truth
if [ -f "$TARGET_LOC_FILE" ] && [ -s "$TARGET_LOC_FILE" ]; then
    INTERFACE_FILE="$TARGET_LOC_FILE"
elif [ -f "$BASELINE_EN_FILE" ] && [ -s "$BASELINE_EN_FILE" ]; then
    INTERFACE_FILE="$BASELINE_EN_FILE"
else
    echo "FATAL ERROR: Initialization failed. Baseline English interface asset" >&2
    echo "is missing or corrupted at: $BASELINE_EN_FILE" >&2
    exit 1
fi

# ==============================================================================
# INTERFACE.TXT PARSER (POSIX-SAFE, NO sed/xargs/awk, PRESERVES INDENTATION)
# ==============================================================================

# --- Inside flight.sh ---
source "$SCRIPT_DIR/lib/interface_parser.sh"

# Define Paths (same logic as before)
TARGET_LOC_FILE="$SCRIPT_DIR/stories/$LOCALIZATION/interface.txt"
BASELINE_EN_FILE="$SCRIPT_DIR/stories/en/interface.txt"

# Select File
if [ -f "$TARGET_LOC_FILE" ] && [ -s "$TARGET_LOC_FILE" ]; then
    INTERFACE_FILE="$TARGET_LOC_FILE"
elif [ -f "$BASELINE_EN_FILE" ] && [ -s "$BASELINE_EN_FILE" ]; then
    INTERFACE_FILE="$BASELINE_EN_FILE"
else
    echo "FATAL: Interface assets missing." >&2; exit 1
fi

# Load Assets
if ! load_interface_assets "$INTERFACE_FILE"; then
    echo "FATAL: Could not parse interface file: $INTERFACE_FILE" >&2
    exit 1
fi

# ==============================================================================
# INTERNAL STORAGE MECHANICS (Application State)
# ==============================================================================
# These are internal system paths that the main script handles automatically.
DB_DIR="$HOME/.cache/flight_dispatch"
DB_FILE="$DB_DIR/airports.json"

# Adventure & Target Profile Files
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
JOURNEY_LOG="$DB_DIR/journey_log.txt"
HASH_FILE="$DB_DIR/.script_hash"

# Source helper libs if present
if [ -f "$SCRIPT_DIR/lib/config.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/lib/config.sh"
fi

if [ -f "$SCRIPT_DIR/lib/story_loader.sh" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/lib/story_loader.sh"
fi

# Custom Filter Card Targets (Moved entirely inside secure application cache)
CSV_TARGET_FILE="$DB_DIR/destinations.csv"
EXCLUSION_FILE="$SCRIPT_DIR/excluded_airports.txt"

mkdir -p "$DB_DIR"

# ==============================================================================
# THE SYNC ENGINE: DYNAMIC DICTIONARY INTERSECTION & INJECTION
# ==============================================================================
# Hash includes both the script and the exclusion list. If either changes, the DB rebuilds.
CURRENT_HASH=$(cat "$SCRIPT_PATH" "$EXCLUSION_FILE" 2>/dev/null | md5sum | cut -d' ' -f1)
LAST_HASH=""
[ -f "$HASH_FILE" ] && LAST_HASH=$(cat "$HASH_FILE")

SCRIPT_UPDATED=0
if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
    SCRIPT_UPDATED=1
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi

# Fallback Interlock Gating for Missing Little Navmap Database
if [ "$DB_SOURCE" = "LNM" ] && [ ! -f "$LNM_DB" ]; then
    echo "========================================================="
    echo "               ⚠️ DATA CAPTURE ALIGNMENT ERROR            "
    echo "========================================================="
    echo "Source configuration is set to LNM, but no database file"
    echo "was found at: $LNM_DB"
    echo "---------------------------------------------------------"
    echo "Options:"
    echo "  1) Abort and change DB_SOURCE to 'GLOBAL' in flight.conf (or fix path)."
    echo "  2) Hot-swap runtime configuration over to global GLOBAL baseline."
    echo "---------------------------------------------------------"
    read -r -p "Choose fallback routing path (1 or 2): " fallback_choice
    if [ "$fallback_choice" = "2" ]; then
        echo "Modifying active session environment configuration..."
        DB_SOURCE="GLOBAL"
    else
        echo "Operational startup cancelled by user. Exiting."
        exit 1
    fi
fi

if [ ! -f "$DB_FILE" ] || [ "$SCRIPT_UPDATED" -eq 1 ] || [ ! -s "$DB_FILE" ]; then
    echo "Sync baseline stale or missing. Executing cross-reference engine ($DB_SOURCE mode)..."
    python3 -c "
import csv, json, urllib.request, sqlite3, os

csv_url = '$DB_URL'
db_file = '$DB_FILE'
lnm_db = '$LNM_DB'
db_source = '$DB_SOURCE'
exclusion_file = '$EXCLUSION_FILE'

excluded_icaos = set()
if os.path.exists(exclusion_file):
    with open(exclusion_file, 'r') as f:
        excluded_icaos = set([line.strip().upper() for line in f if line.strip() and not line.startswith('#')])

valid_icaos = set()
lnm_fallback_data = {}

# 1. If in LNM mode, grab the master list of flyable airports
if db_source == 'LNM' and os.path.exists(lnm_db):
    try:
        conn = sqlite3.connect(lnm_db)
        cursor = conn.cursor()
        cursor.execute('''SELECT ident, name, city, country FROM airport WHERE ident IS NOT NULL''')
        for row in cursor.fetchall():
            ident = row[0].upper()
            if ident in excluded_icaos: continue
            valid_icaos.add(ident)
            lnm_fallback_data[ident] = {
                'icao': ident,
                'name': row[1] if row[1] else 'Unknown LNM Field',
                'city': row[2] if row[2] else 'Unknown City',
                'country': row[3] if row[3] else 'Unknown',
                'type': 'small_airport'
            }
        conn.close()
        print(f'Found {len(valid_icaos)} verified flyable airfields in LNM database.')
    except Exception as e:
        print(f'Warning reading LNM DB: {e}')

# 2. Download OurAirports and filter it
try:
    print('Downloading and merging OurAirports size metadata...')
    req = urllib.request.Request(csv_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        lines = [l.decode('utf-8') for l in response.readlines()]
        
    reader = csv.DictReader(lines)
    compiled_data = {}
    
    for row in reader:
        ident = row.get('ident', '').upper()
        if ident in excluded_icaos: continue
        apt_type = row.get('type', 'small_airport')
        
        if apt_type == 'closed' or len(ident) < 3 or len(ident) > 4:
            continue
            
        # If we are in LNM mode, skip airports that aren't in the simulator!
        if db_source == 'LNM' and valid_icaos and ident not in valid_icaos:
            continue
            
        compiled_data[ident] = {
            'icao': ident,
            'name': row.get('name', 'Unknown'),
            'city': row.get('municipality', 'Unknown'),
            'country': row.get('iso_country', 'Unknown'),
            'type': apt_type
        }
        
    # 3. Safety Net: Inject LNM airports that OurAirports might have missed (LNM Mode Only)
    if db_source == 'LNM' and valid_icaos:
        for ident in valid_icaos:
            if ident not in compiled_data and len(ident) >= 3 and len(ident) <= 4:
                compiled_data[ident] = lnm_fallback_data[ident]

    with open(db_file, 'w', encoding='utf-8') as f:
        json.dump(compiled_data, f, indent=4)
        
    print(f'Cross-reference complete! Cached {len(compiled_data)} active airfields.')
except Exception as e:
    print(f'Error compiling database: {e}')
"
fi

# ==============================================================================
# HELP & DOCUMENTATION SYSTEM (-h / --help handler)
# ==============================================================================
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    echo "========================================================="
    echo "                FLIGHT DISPATCH SERVICE HELP             "
    echo "========================================================="
    echo "Usage Syntax: flight [OPTION] [TARGET/FILE]"
    echo "---------------------------------------------------------"
    echo "Standard Commands:"
    echo "  flight                   - Roll the dice for a basic abstract manifest."
    echo "  flight <ICAO>            - Briefing & career tracking for a specific field."
    echo "  flight <PX>              - Dispatches a random airfield matching 2-letter prefix."
    echo "  flight -n | --next <PX>  - Dispatches an UNVISITED random airfield matching prefix."
    echo ""
    echo "Adventure & Management:"
    echo "  flight -j | --journey    - Run next leg of loaded adventure."
    echo "  flight -j <file.fgfp>    - Load a high-adventure .fgfp path flight plan."
    echo "  flight -j --reset        - Restart loaded adventure back to the first leg."
    echo "  flight -c <file.csv>     - Create/overwrite custom target card from external CSV."
    echo "  flight -c --reset        - Remove active target deck filter overlay."
    echo "  flight -f | --files      - View active logbooks and cache folder storage."
    echo "  flight -e <PX>           - Open a specific country logbook in your editor."
    echo "  flight --reset           - Wipe out all country/territory logbook files."
    echo "  flight -h | --help       - Display this operational guide."
    echo "---------------------------------------------------------"
    echo "💡 SYNTAX NOTE: Options (like -n, -j, -c) must precede any targets."
    echo "   Correct: 'flight -n LG'  |  Incorrect: 'flight LG -n'"
    echo "---------------------------------------------------------"
    echo "💡 HIT 100% IN A COUNTRY OR CUSTOM CARD? NEXT STEPS:"
    echo "  1. Explore Locally : You can still fly inside completed regions."
    echo "  2. Expand Horizons : Cross borders to an adjacent country prefix"
    echo "                       (e.g. leave LG for LI) to auto-generate a new log."
    echo "  3. Swap Custom Card: Use 'flight -c <file.csv>' to ingest a fresh card."
    echo "  4. Reset Territory : Run 'flight -f' to access the log directory."
    echo "========================================================="
    exit 0
fi

# ==============================================================================
# REGIONAL PREFIX SUMMARY UTILITY (Used by both logs and dashboard calculation)
# ==============================================================================
calculate_prefix_metrics() {
    local target_prefix="$1"
    python3 -c "
import sys, json, os

tier = '$VEHICLE_TIER'
prefix = '$target_prefix'
db_file = '$DB_FILE'
db_dir = '$DB_DIR'

exclude_types = set()
if tier == 'small_airplane': exclude_types.add('heliport')
elif tier == 'medium_airplane': exclude_types.update(['heliport', 'small_airport'])
elif tier == 'large_airplane': exclude_types.update(['heliport', 'small_airport', 'medium_airport'])

try:
    with open(db_file, 'r') as f: db = json.load(f)
    valid_pool = {k: v for k, v in db.items() if k.startswith(prefix) and v.get('type') not in exclude_types}
    total = len(valid_pool)
    
    if total == 0:
        print('0|0|100.0%|0|')
    else:
        v_file = os.path.join(db_dir, f'visited_{prefix}.txt')
        history = set()
        if os.path.exists(v_file):
            with open(v_file, 'r') as f: history = set([line.strip().upper() for line in f if line.strip()])
            
        visited_valid = [icao for icao in history if icao in valid_pool]
        v_count = len(visited_valid)
        pct = (v_count / total) * 100
        rem = total - v_count
        
        cities = ''
        if 0 < rem <= int('$CITIES_ALERT_THRESHOLD'):
            cities = ', '.join([valid_pool[k].get('city', 'Unknown') for k in valid_pool if k not in history])
            
        print(f'{v_count}|{total}|{pct:.1f}%|{rem}|{cities}')
except Exception:
    print('0|1|0.0%|1|')
"
}

calculate_deck_metrics() {
    python3 -c "
import sys, os

csv_file = '$CSV_TARGET_FILE'
db_dir = '$DB_DIR'

if not os.path.exists(csv_file):
    print('INACTIVE')
    sys.exit(0)

try:
    deck_icaos = set()
    with open(csv_file, 'r', encoding='utf-8') as f:
        next(f)
        for line in f:
            if line.strip(): deck_icaos.add(line.strip().upper())
            
    total_goals = len(deck_icaos)
    if total_goals == 0:
        print('0|0|100.0%|0')
        sys.exit(0)
        
    visited_goals = 0
    for icao in deck_icaos:
        px = icao[:2]
        px_file = os.path.join(db_dir, f'visited_{px}.txt')
        if os.path.exists(px_file):
            with open(px_file, 'r') as f:
                history = [l.strip().upper() for l in f if l.strip()]
            if icao in history:
                visited_goals += 1
                
    pct = (visited_goals / total_goals) * 100
    rem = total_goals - visited_goals
    print(f'{visited_goals}|{total_goals}|{pct:.1f}%|{rem}')
except Exception:
    print('INACTIVE')
"
}

# ==============================================================================
# TARGET CARD MANAGER SYSTEM (-c / --create_csv handler)
# ==============================================================================
if [ "${1:-}" = "-c" ] || [ "${1:-}" = "--create_csv" ]; then
    if [ "${2:-}" = "--reset" ]; then
        if [ -f "$CSV_TARGET_FILE" ]; then
            rm -f "$CSV_TARGET_FILE"
            echo "SUCCESS: Custom target filter deck removed cleanly. Reverted to standard prefix rules."
        else
            echo "Notice: No custom target deck was active."
        fi
        exit 0
    elif [ -n "${2:-}" ]; then
        if [ -f "$2" ]; then
            echo "Ingesting custom filter card deck from: $2"
            
            # Ultra-Strict Extractor: Target precise 'ident' labels, verifying authenticity against JSON DB
            python3 -c "
import sys, json, os

src_file = '$2'
dest_file = '$CSV_TARGET_FILE'
db_file = '$DB_FILE'

try:
    with open(src_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
    delim = ';' if ';' in content.split('\n')[0] else ','
    lines = [l.strip() for l in content.split('\n') if l.strip()]
    if not lines:
        print('ERROR: Source CSV file is empty!')
        sys.exit(1)
        
    headers = [h.strip().lower() for h in lines[0].split(delim)]
    
    ident_idx = -1
    target_tags = ['ident', 'icao', 'airport code', 'code', 'id']
    for tag in target_tags:
        for idx, h in enumerate(headers):
            if tag == h or (tag in h and len(h) < 15):
                ident_idx = idx
                break
        if ident_idx != -1:
            break
            
    if ident_idx == -1:
        print('=========================================================')
        print('                 ⚠️ CSV INGESTION REJECTED                ')
        print('=========================================================')
        print('ERROR: Could not find a valid identifier header column!')
        print('Your CSV header must include one of these labels:')
        print('  ident, icao, code, id, or airport code')
        print('---------------------------------------------------------')
        print('Aborting process. Existing custom deck filter remains untouched.')
        print('=========================================================')
        sys.exit(1)
        
    # Load global database to validate true operational ICAO records
    valid_global_icaos = set()
    if os.path.exists(db_file):
        try:
            with open(db_file, 'r') as db_f:
                valid_global_icaos = set(json.load(db_f).keys())
        except Exception:
            pass

    extracted_icaos = []
    for line in lines[1:]:
        cols = line.split(delim)
        if len(cols) > ident_idx:
            val = cols[ident_idx].strip().upper()
            # Absolute Validation Layer: Check syntax AND confirm code exists globally
            if val and len(val) >= 3 and len(val) <= 4 and val.isalnum():
                if not valid_global_icaos or val in valid_global_icaos:
                    extracted_icaos.append(val)
                
    if not extracted_icaos:
        print('ERROR: No valid ICAO identifiers extracted from target column.')
        sys.exit(1)
        
    with open(dest_file, 'w', encoding='utf-8') as out:
        out.write('Ident\n')
        for icao in sorted(list(set(extracted_icaos))):
            out.write(f'{icao}\n')
            
    print(f'SUCCESS: Custom deck tracking filter created with {len(set(extracted_icaos))} unique goals!')
except Exception as e:
    print(f'ERROR parsing deck: {e}')
    sys.exit(1)
"
            exit 0
        else
            echo "ERROR: Target CSV source file does not exist: $2"
            exit 1
        fi
    fi
fi

# ==============================================================================
# DANGEROUS GLOBAL PROFILE RESET EXECUTION (--reset handler)
# ==============================================================================
if [ "${1:-}" = "--reset" ]; then
    echo "⚠️ WARNING: You are about to wipe ALL country/territory pilot logbooks!"
    read -r -p "Are you absolutely sure you want to delete all metrics? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Clearing profile career history files..."
        rm -f "$DB_DIR"/visited_*.txt
        echo "SUCCESS: Career profile metrics reset to zero."
    else
        echo "Reset operation aborted."
    fi
    exit 0
fi

# ==============================================================================
# SURGICAL HISTORY EDITOR TARGET ENGINE (-e / --edit handler)
# ==============================================================================
if [ "${1:-}" = "-e" ] || [ "${1:-}" = "--edit" ]; then
    prefix="${2:-}"
    if [ -z "$prefix" ]; then
        echo "ERROR: Please specify a country prefix to edit."
        exit 1
    fi
    prefix="${prefix^^}"
    target_log="$DB_DIR/visited_${prefix}.txt"
    touch "$target_log"
    USER_EDITOR="${EDITOR:-nano}"
    "$USER_EDITOR" "$target_log"
    exit 0
fi

# ==============================================================================
# MANAGEMENT TOOLS & METADATA VIEW (-f / --files handler with caps)
# ==============================================================================
if [ "${1:-}" = "-f" ] || [ "${1:-}" = "--files" ]; then
    echo "========================================================="
    echo "                LOGBOOK STORAGE MANAGEMENT                "
    echo "========================================================="
    echo "Cache Directory: $DB_DIR"
    echo "---------------------------------------------------------"
    printf "%-22s | %-13s | %s\n" "TRACKING FILE" "PROGRESS" "LAST KNOWN POSITION"
    echo "---------------------------------------------------------"
    
    (
        cd "$DB_DIR" || exit 1
        files=(*)
        for f in "${files[@]}"; do
            [ -e "$f" ] || continue
            if [[ "$f" =~ ^visited_(..)\.txt$ ]]; then
                px="${BASH_REMATCH[1]}"
                metrics=$(calculate_prefix_metrics "$px")
		IFS='|' read -r v_c t_c _ <<< "$metrics"
                last_pos=$(tail -n 1 "$f")
                [ -z "$last_pos" ] && last_pos="Empty Logbook"
                
                # Create a perfectly spaced progress layout: "XX  /  YY"
		prog_str=$(printf "%2s  /%s" "$v_c" "$t_c")
                printf "%-22s | %-13s | Last: %s\n" "$f" "$prog_str" "$last_pos"
                
            elif [ "$f" = "journey_log.txt" ]; then
                total=$(grep -cE '^[A-Z0-9#]' "$f")
                done=$(grep -c '^#' "$f")
                last_leg=$(grep '^#' "$f" | tail -n 1 | tr -d '# ')
                [ -z "$last_leg" ] && last_leg="Not Started"
                
                prog_str=$(printf "%2s  /%s" "$done" "$total")
                printf "%-22s | %-13s | Last: %s\n" "$f" "$prog_str" "$last_leg"
                
            elif [ "$f" = "destinations.csv" ]; then
                goals=$(($(grep -c '^' "$f") - 1))
                printf "%-22s | %-13i | Custom Target Filter Deck Overlay\n" "$f" "$goals"
            fi
        done
    )
    echo "---------------------------------------------------------"
    (
        cd "$DB_DIR" || exit 1
        echo "🚀 Spawning logbook workspace shell. Type 'exit' to close."
        echo "========================================================="
        $SHELL
    )
    exit 0
fi

# ==============================================================================
# ADVENTURE SYSTEM ENTRY ROUTINE (-j / --journey engine)
# ==============================================================================
JOURNEY_MODE=0
if [ "${1:-}" = "-j" ] || [ "${1:-}" = "--journey" ]; then
    JOURNEY_MODE=1
    if [ "${2:-}" = "--reset" ]; then
        echo "⚠️ WARNING: You are about to wipe your active adventure journey progress!"
        read -r -p "Are you sure you want to reset this expedition? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            if [ -f "$JOURNEY_LOG" ]; then
                mapfile -t current_lines < "$JOURNEY_LOG"
                true > "$JOURNEY_LOG"
                for line in "${current_lines[@]}"; do
                    echo "${line#\# }" >> "$JOURNEY_LOG"
                done
                echo "SUCCESS: Adventure tracker reset cleanly."
            else
                echo "Notice: No tracking logs found to reset."
            fi
        else
            echo "Journey reset operation aborted."
        fi
        exit 0
    elif [ -n "${2:-}" ]; then
	if [ -f "$2" ]; then
	    # Ingest fresh expedition track from: $2
	    echo "Initializing fresh expedition track from: $(basename "$2")"
	    
	    # Check 1: Try standard FlightGear identifier string attributes
	    mapfile -t new_legs < <(grep -oP '(?<=<ident type="string">)[^<]+(?=</ident>)' "$2" | uniq)
	    
	    # Check 2: Fallback to FlightGear raw airport string tags
	    if [ ${#new_legs[@]} -eq 0 ]; then
	        mapfile -t new_legs < <(grep -oP '(?<=<airport type="string">)[^<]+(?=</airport>)' "$2" | uniq)
	    fi
	    
	    # Check 3: Fallback to Little Navmap universal waypoint schema
	    if [ ${#new_legs[@]} -eq 0 ]; then
	        mapfile -t new_legs < <(grep -oP '(?<=<Ident>)[^<]+(?=</Ident>)' "$2" | uniq)
	    fi
	    
	    # Final Verification
	    if [ ${#new_legs[@]} -eq 0 ]; then
	        echo "ERROR: No valid journey legs found inside the file!"
	        exit 1
	    fi
            
            true > "$JOURNEY_LOG"
            for leg in "${new_legs[@]}"; do
                echo "$leg" >> "$JOURNEY_LOG"
            done
        else
            echo "ERROR: Specified flight plan file does not exist: $2"
            exit 1
        fi
    fi

    if [ ! -f "$JOURNEY_LOG" ] || [ ! -s "$JOURNEY_LOG" ]; then
        echo "ERROR: High-adventure flight plan log is uninitialized!"
	echo "Provide a file to start: flight -j path/to/plan.[fgfp|lnmpln]"
        exit 1
    fi

    total_legs=$(grep -cE '^[A-Z0-9#]' "$JOURNEY_LOG")
    done_legs=$(grep -c '^#' "$JOURNEY_LOG")

    if [ "$done_legs" -eq "$total_legs" ] && [ "$total_legs" -gt 0 ]; then
        final_icao=$(tail -n 1 "$JOURNEY_LOG" | tr -d '# ')
        echo "========================================================="
        echo "            🏆 HIGH-ADVENTURE JOURNEY COMPLETED 🏆           "
        echo "========================================================="
        echo " Location     : (ICAO: $final_icao)"
        echo " Status       : Expedition successfully archived."
        echo "                Run 'flight -j --reset' to fly it again!"
        echo "========================================================="
        exit 0
    fi

    destination=""
    while IFS= read -r line; do
        if [[ ! "$line" =~ ^# ]]; then
            destination=$(echo "$line" | xargs)
            break
        fi
    done < "$JOURNEY_LOG"
    icao="$destination"
fi

# ==============================================================================
# MAIN CORE FLOW ENTRY 
# ==============================================================================
IS_LOCAL_FLIGHT=0
NON_REPEAT_MODE=0

if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--next" ]; then
    NON_REPEAT_MODE=1
    shift
fi

if [ "$JOURNEY_MODE" -eq 0 ]; then
    # 🌟 FIX: If no arguments/prefixes are supplied, IMMEDIATELY drop to local flight mode
    if [ -z "${1:-}" ]; then
        IS_LOCAL_FLIGHT=1
        icao="$HOME_ICAO"
    else
        input_token="${1^^}"
        if [[ "$input_token" =~ ^[A-Z]{2}$ ]]; then
	    echo "Rolling the dice for a random airfield matching prefix '$input_token' (DECK-aware)..."
            rolled_icao=$(python3 -c "
import sys, json, os, random

tier = '$VEHICLE_TIER'
prefix = '$input_token'
db_file = '$DB_FILE'
db_dir = '$DB_DIR'
csv_file = '$CSV_TARGET_FILE'
non_repeat = int('$NON_REPEAT_MODE')

exclude_types = set()
if tier == 'small_airplane': exclude_types.add('heliport')
elif tier == 'medium_airplane': exclude_types.update(['heliport', 'small_airport'])
elif tier == 'large_airplane': exclude_types.update(['heliport', 'small_airport', 'medium_airport'])
try:
    with open(db_file, 'r') as f: db = json.load(f)
    db_pool = [k for k, v in db.items() if k.startswith(prefix) and v.get('type') not in exclude_types]
    
    deck_pool = []
    if os.path.exists(csv_file):
        with open(csv_file, 'r') as f:
            next(f)
            deck_targets = set([line.strip().upper() for line in f if line.strip()])
        deck_pool = [k for k in db_pool if k in deck_targets]
        
    active_pool = deck_pool if deck_pool else db_pool

    if not active_pool:
        print('MISSING_PREFIX')
        sys.exit(0)

    if non_repeat:
        px_file = os.path.join(db_dir, f'visited_{prefix}.txt')
        history = set()
        if os.path.exists(px_file):
            with open(px_file, 'r') as f: history = set([l.strip().upper() for l in f if l.strip()])
        
        # 1. Υπολογισμός unvisited
        unvisited = [icao for icao in active_pool if icao not in history]
        
        # 2. Έλεγχος εξάντλησης: Αν το candidate set είναι άδειο, σταματάμε αμέσως!
        if not unvisited:
            print('POOL_EXHAUSTED')
            sys.exit(0)
            
        print(random.choice(unvisited))
    else:
        print(random.choice(active_pool))
except Exception:
    print('FAIL')
")
            if [ "$rolled_icao" = "MISSING_PREFIX" ]; then
                echo "⚠️  NOTICE: Prefix '$input_token' has no operational airfields inside configuration."
                echo "Switching runtime profile to local abstract manifest..."
                IS_LOCAL_FLIGHT=1
                icao="$HOME_ICAO"
            elif [ "$rolled_icao" = "POOL_EXHAUSTED" ]; then
                # Dynamically bind localized interface strings with the active token context
		echo -e "   ${lbl_err_non_repeat_1//%TOKEN%/$input_token}" >&2
		echo -e "   $lbl_err_non_repeat_2" >&2
		echo -e "   $lbl_err_non_repeat_3" >&2
		echo -e "   $lbl_err_non_repeat_4\n" >&2
                exit 1
            elif [ "$rolled_icao" = "FAIL" ] || [ -z "$rolled_icao" ]; then
                echo "ERROR: Dynamic compilation issue generating airfield arrays."
                exit 1
            else
                icao="$rolled_icao"
            fi
        else
            icao="$input_token"
            if [[ ! "$icao" =~ ^[A-Z0-9]{3,4}$ ]]; then
                echo "ERROR: '$1' is not a valid identifier format."
                exit 1
            fi
        fi
    fi
fi

# Fetch metadata attributes for selected airfield
apt_name=""
apt_city=""
apt_country=""
apt_type=""
is_confirmed_airport=0

if [ -f "$DB_FILE" ]; then
    parsed_data=$(python3 -c "
import sys, json
try:
    with open('$DB_FILE', 'r') as f:
        ap = json.load(f).get('$icao', {})
    if ap: print(f\"{ap.get('name', '')}|{ap.get('city', '')}|{ap.get('country', '')}|{ap.get('type', '')}\")
    else: print('|||')
except Exception: print('|||')
" 2>/dev/null)
    IFS='|' read -r apt_name apt_city apt_country apt_type <<< "$parsed_data"
    [ -n "$apt_name" ] && is_confirmed_airport=1
fi

# Check if the requested ICAO is intentionally excluded before falling back to the internet
IS_EXCLUDED=0
if grep -iqE "^[[:space:]]*${icao}[[:space:]]*$" "$EXCLUSION_FILE" 2>/dev/null; then
    IS_EXCLUDED=1
fi

# Fallback 1: If not found locally AND not excluded, search the online OurAirports CSV dataset
if [ -z "$apt_name" ] && [ "$IS_LOCAL_FLIGHT" -eq 0 ] && [ "$IS_EXCLUDED" -eq 0 ]; then
    echo "Notice: ICAO '$icao' not found locally. Searching global OurAirports dataset online..."
    parsed_data=$(python3 -c "
import sys, csv, json, urllib.request, os

icao = '$icao'
csv_url = '$DB_URL'
db_file = '$DB_FILE'

try:
    req = urllib.request.Request(csv_url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as response:
        lines = [l.decode('utf-8', errors='ignore') for l in response.readlines()]
        reader = csv.DictReader(lines)
        for row in reader:
            if row.get('ident', '').upper() == icao:
                name = row.get('name', 'Unknown')
                city = row.get('municipality', 'Unknown')
                country = row.get('iso_country', 'Unknown')
                atype = row.get('type', 'small_airport')
                print(f\"{name}|{city}|{country}|{atype}\")
                
		excluded = False
                if os.path.exists('$EXCLUSION_FILE'):
                    with open('$EXCLUSION_FILE', 'r') as ef:
                        if icao in [l.strip().upper() for l in ef]: excluded = True
                
                if not excluded and os.path.exists(db_file):
                    try:
                        with open(db_file, 'r') as f: data = json.load(f)
                        data[icao] = {'icao': icao, 'name': name, 'city': city, 'country': country, 'type': atype}
                        with open(db_file, 'w') as f: json.dump(data, f, indent=4)
                    except: pass
                sys.exit(0)
except Exception: pass
print('|||')
" 2>/dev/null)
    
    IFS='|' read -r apt_name apt_city apt_country apt_type <<< "$parsed_data"
    if [ -n "$apt_name" ]; then
        echo "✔ Found '$icao' online! Added to local database."
        is_confirmed_airport=1
    fi
fi

# Fallback 2: Catch-All for truly invalid/fake ICAOs (e.g. XXXY)
if [ -z "$apt_name" ] && [ "$IS_LOCAL_FLIGHT" -eq 0 ]; then
    apt_name="Uncharted Airfield"
    apt_city="Unknown Region"
    apt_country="Unknown"
    is_confirmed_airport=0
fi

# ==============================================================================
# WEIGHT DETECT ENGINE & CONTEXT TEXT CORES
# ==============================================================================

# compute baggage weight using tier-specific max (config.sh provides max_baggage)
if [ "$JOURNEY_MODE" -eq 1 ]; then
    passengers="$journey_zones"
else
    passengers=$(( RANDOM % 4 ))
fi

baggage_weight=$(( RANDOM % max_baggage ))

# classify
bag_class="light"
[ "$baggage_weight" -ge "$threshold_medium" ] && bag_class="medium"
[ "$baggage_weight" -ge "$threshold_heavy" ] && bag_class="heavy"

# Load story from external files; loader returns empty if no file exists
story=""
if command -v load_story >/dev/null 2>&1; then
  story=$(load_story "$VEHICLE_TIER" "$passengers" "$bag_class" 2>/dev/null || true)
fi

# Strict mode: abort if no story file exists
if [ -z "${story:-}" ]; then
  echo "ERROR: No story file found for ${VEHICLE_TIER} pax=${passengers} bag=${bag_class}."
  echo "Expected pax${passengers}__bag${bag_class}.txt in stories/en/${VEHICLE_TIER}"
  exit 1
fi

# ==============================================================================
# ACT 1: THE DISPATCH PROPOSAL
# ==============================================================================
echo "========================================================="
if [ "$CONFIRMATION" = true ] && [ "$IS_LOCAL_FLIGHT" -eq 0 ]; then
    echo "                    $lbl_proposal                    "
else
    echo "                    $lbl_briefing                    "
fi
echo "========================================================="

# choose manifest wording per tier (singular/plural handled)
if [ "$VEHICLE_TIER" = "medium_airplane" ] || [ "$VEHICLE_TIER" = "large_airplane" ]; then
  manifest_word="Zone"
else
  manifest_word="Passenger"
fi
# pluralize when needed
if [ "${passengers:-0}" -ne 1 ]; then
  manifest_word="${manifest_word}s"
fi

if [ "$IS_LOCAL_FLIGHT" -eq 1 ]; then
    echo "$lbl_manifest    : $passengers ${manifest_word} | $lbl_baggage: $bag_class"
    echo "$lbl_context     : $story"
else
    echo "$lbl_destination : $apt_name"
    echo "$lbl_location    : $apt_city, $apt_country (ICAO: $icao)"
    echo "---------------------------------------------------------"
    echo "$lbl_manifest    : $passengers ${manifest_word} | $lbl_baggage: $bag_class"
    echo "$lbl_context     : $story"
fi

# Trigger the mood confirmation gate if enabled
if [ "$CONFIRMATION" = true ] && [ "$IS_LOCAL_FLIGHT" -eq 0 ]; then
    echo "---------------------------------------------------------" >&2
    read -r -p "$lbl_confirm_prompt" choice
    case "$choice" in 
        [Yy]*) 
            echo "" >&2
            echo "✔ $lbl_confirm_success" >&2
            ;;
        *) 
            echo ""
            echo "❌ $lbl_confirm_cancel"
            echo "========================================================="
            exit 0 
            ;;
    esac
fi

# ==============================================================================
# ACT 2: UPDATE LOGS & EVALUATE METRICS
# ==============================================================================
mode_text=""
alert_text=""

if [ "$IS_LOCAL_FLIGHT" -eq 0 ]; then
    prefix="${icao:0:2}"
    prefix_file="$DB_DIR/visited_${prefix}.txt"
    
    # Commit the verified flight to the permanent history text file
    if [ "$is_confirmed_airport" -eq 1 ]; then
        touch "$prefix_file"
        if ! grep -Fxq "$icao" "$prefix_file"; then
            echo "$icao" >> "$prefix_file"
        fi
    fi

    # Keep base airfield initialization safe
    home_prefix="${HOME_ICAO:0:2}"
    home_file="$DB_DIR/visited_${home_prefix}.txt"
    if [ ! -s "$home_file" ] || ! grep -Fxq "$HOME_ICAO" "$home_file" 2>/dev/null; then
        touch "$home_file"
        echo "$HOME_ICAO" >> "$home_file"
    fi

    # Advance the journey track safely *after* authentication gate passed
    if [ "$JOURNEY_MODE" -eq 1 ]; then
        awk -v dest="$icao" '{if ($0 == dest) print "# " dest; else print}' "$JOURNEY_LOG" > "$JOURNEY_LOG.tmp" && mv "$JOURNEY_LOG.tmp" "$JOURNEY_LOG"
        updated_done=$(grep -c '^#' "$JOURNEY_LOG")
        rem_legs=$((total_legs - updated_done))
        
        adv_pct=$(python3 -c "
total = $total_legs
done = $updated_done - 1
if total <= 0: print('0.0%')
else: print(f'{(done / total) * 100:.1f}%')
")
	if [ "$rem_legs" -eq 0 ]; then
	    mode_text="Journey: Leg ${updated_done}/${total_legs} (100.0% Dispatched) | 🏁 FINAL LEG!"
	    alert_text="$lbl_alert_journey_final"
	    
	else
	    mode_text="Journey: Leg ${updated_done}/${total_legs} Dispatched ($adv_pct completed prior)."
	
	    # Normal leg → journey reset hint
	    alert_text="💡 (Execute 'flight -j --reset' to clear journey)"
	fi
    else
	if [ "$is_confirmed_airport" -eq 0 ]; then
            mode_text="[UNVERIFIED ICAO] Off the grid. Not tracked in regional career metrics."
            
            # Check if it was intentionally excluded (ignoring spaces and \r carriage returns)
            if grep -iqE "^[[:space:]]*${icao}[[:space:]]*$" "$EXCLUSION_FILE" 2>/dev/null; then
                alert_text="🚫 Destination intentionally ignored (found in excluded list)."
            else
                alert_text="⚠️ Destination uncharted in master database!"
            fi
        else
            px_metrics=$(calculate_prefix_metrics "$prefix")
            IFS='|' read -r vp_count tp_count cp_pct rp_count cities_left <<< "$px_metrics"
            
            mode_text="[$prefix] Prefix Progress: $vp_count/$tp_count Fields Met ($cp_pct)."
            
            if [ "$cp_pct" = "100.0%" ]; then
                alert_text="${lbl_alert_prefix_start} [${prefix}] ${lbl_alert_prefix_end}"
            elif [ -n "$cities_left" ] && [ "$rp_count" -gt 0 ]; then
                alert_text="Only $cities_left left to complete your territory card!"
            fi
        fi
    fi
else
    # Give mode_text a beautiful default so it's never "lost" on local flights!
    mode_text="[LOCAL] Manifest Operations at Base ($HOME_ICAO). Pattern work untracked."
fi

# Check for custom overlay target card deck status (Now executes safely for ALL flight types!)
deck_status=$(calculate_deck_metrics)
if [ "$deck_status" != "INACTIVE" ] && [ -n "$deck_status" ]; then
    IFS='|' read -r vd_count td_count cd_pct rd_count deck_left <<< "$deck_status"
    deck_text="[DECK] Goals Covered:  $vd_count/$td_count Card Targets ($cd_pct)."
    deck_hint="💡 (Execute 'flight -c --reset' to unregister the target deck.)"
    
    # Add 100% completion text, or list the remaining targets if under threshold
    if [ "$cd_pct" = "100.0%" ]; then
	deck_text="${deck_text}"$'\n'"              ${lbl_alert_deck_complete}"
    elif [ -n "$deck_left" ] && [ "$rd_count" -gt 0 ]; then
        deck_text="${deck_text}"$'\n'"              Remaining Targets: ${deck_left}"
    fi
    
    if [ -n "${alert_text:-}" ]; then
        alert_text="${alert_text}"$'\n\n'"                     ${deck_text}"$'\n'"                     ${deck_hint}"
    else
        alert_text="${deck_text}"$'\n'"                     ${deck_hint}"
    fi
fi

# Display compiled stats block
echo "---------------------------------------------------------"
echo "$lbl_log_engine  : $mode_text"
if [ -n "${alert_text:-}" ]; then
    echo "$lbl_alert       : $alert_text"
fi

# ==============================================================================
# ACT 3: WEIGHT DETAILS & PRE-FLIGHT OUTRO
# ==============================================================================
echo "---------------------------------------------------------"

# Fallback to 'lbs' if the user hasn't defined WEIGHT_UNIT in their config yet
UNIT="${WEIGHT_UNIT:-lbs}"

if [ "$VEHICLE_TIER" = "small_airplane" ] || [ "$VEHICLE_TIER" = "helicopter" ]; then
    crew_label="$lbl_crew_pilot"
else
    crew_label="$lbl_crew_team"
fi

printf "• %-21s : %6i %s\n" "$crew_label" "$crew" "$UNIT"

if [ "$passengers" -ne 0 ]; then
    i=1
    while [ "$i" -le "$passengers" ]; do
        if [ "$JOURNEY_MODE" -eq 1 ]; then
            # Pull the locked, static weight from your configuration array
            p_weight="${journey_cargo[$((i-1))]}"
        else
            # Roll a dynamic variable weight for random flights
            p_weight=$(( (pax_min + RANDOM % pax_range) * seats_per_zone ))
        fi

        label_var="pax${i}_label"
        label="${!label_var}"
        printf "• %-20s  : %6i %s\n" "$label" "$p_weight" "$UNIT"

        i=$(( i + 1 ))
    done
fi

printf "• %-20s  : %6i %s (%s %s)\n" "$lbl_cargo" "$baggage_weight" "$UNIT" "$bag_class" "load"
echo "========================================================="
echo "$lbl_outro_balance"
echo "$lbl_outro_fly"
