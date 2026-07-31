import sys
import re
import gzip
import os

# ==============================================================================
# CONFIGURATION ZONE
# ==============================================================================

# 1. Source AIRAC file (expected in the root folder alongside this script)
SOURCE_AIRAC_FILE = "nav_AIRAC.dat"  # Can also be "nav_modern.dat"

# 2. FlightGear System Root (containing Airports/apt.dat.gz and Navaids/nav.dat.gz)
FG_ROOT = os.environ.get("FG_ROOT", "/usr/share/flightgear")

# 3. Target Override Output Directory
FG_NAV_OVERRIDE_DIR = os.environ.get(
    "FG_NAV_OVERRIDE", 
    "/mnt/data/games/Flightgear/NavData_Override/NavData/nav"
)

# ==============================================================================
# DERIVED PATHS & CONSTANTS
# ==============================================================================

SYSTEM_APT_GZ = os.path.join(FG_ROOT, "Airports", "apt.dat.gz")
SYSTEM_NAV_GZ = os.path.join(FG_ROOT, "Navaids", "nav.dat.gz")
OUTPUT_FILE = os.path.join(FG_NAV_OVERRIDE_DIR, "nav.dat")

ILS_ROW_TYPES = {"4", "5", "6", "12", "13"}


def open_system_gz(system_path):
    """
    Safely opens a system base compressed file (.gz).
    """
    if os.path.exists(system_path):
        print(f"Reading base system database: {system_path}")
        return gzip.open(system_path, 'rt', encoding='utf-8', errors='ignore')
    return None


def build_scenery_runway_database():
    """
    Parses apt.dat.gz from FG_ROOT to build a map of valid scenery runways.
    """
    f = open_system_gz(SYSTEM_APT_GZ)
    if not f:
        print(f"Warning: Could not locate system apt.dat.gz at '{SYSTEM_APT_GZ}'. Runway auto-correction disabled.")
        return {}

    valid_runways = {}
    current_icao = None

    with f:
        for line in f:
            tokens = line.strip().split()
            if not tokens:
                continue

            row_code = tokens[0]
            # Airport headers (1 = land, 16 = seaplane, 17 = heliport)
            if row_code in ('1', '16', '17') and len(tokens) >= 5:
                current_icao = tokens[4]
                if current_icao not in valid_runways:
                    valid_runways[current_icao] = set()

            # Runway definition (Row 100)
            elif row_code == '100' and current_icao and len(tokens) >= 18:
                valid_runways[current_icao].add(tokens[8])
                valid_runways[current_icao].add(tokens[17])

    print(f"Successfully mapped runways for {len(valid_runways)} airports.")
    return valid_runways


def clean_modern_ils_line(tokens, valid_runways):
    row_type = tokens[0]

    # 1. Strip country code token if present (e.g., 'LG' between ICAO and Rwy)
    if len(tokens) >= 10 and len(tokens[9]) == 2 and tokens[9].isalpha() and not tokens[9].isdigit():
        del tokens[9]
    elif len(tokens) >= 10 and len(tokens[8]) == 2 and tokens[8].isalpha() and not tokens[8].isdigit():
        del tokens[8]

    # 2. Clean heading multiplier (e.g., 100722.910 -> 722.910)
    if row_type == "4" and len(tokens) > 6:
        try:
            hdg_val = float(tokens[6])
            if hdg_val >= 100000.0:
                tokens[6] = f"{hdg_val % 100000.0:.3f}"
        except ValueError:
            pass

    # 3. Smart Runway Auto-Correction using apt database
    if len(tokens) >= 10:
        icao = tokens[8]
        rwy = tokens[9]

        if icao in valid_runways:
            if rwy not in valid_runways[icao]:
                stripped_rwy = re.sub(r'[LRCrc]$', '', rwy)
                if stripped_rwy in valid_runways[icao]:
                    tokens[9] = stripped_rwy

    return " ".join(tokens) + "\n"


def process_nav_files():
    # 1. Load Scenery Runways directly from FG_ROOT/Airports/apt.dat.gz
    valid_runways = build_scenery_runway_database()

    output_lines = []
    base_ils_keys = set()

    # 2. Extract Base FlightGear ILS Data directly from FG_ROOT/Navaids/nav.dat.gz
    f_base = open_system_gz(SYSTEM_NAV_GZ)
    if f_base:
        with f_base:
            for line in f_base:
                tokens = line.strip().split()
                if not tokens or not tokens[0].isdigit():
                    continue
                if tokens[0] in ILS_ROW_TYPES:
                    output_lines.append(line)
                    if len(tokens) >= 10:
                        base_ils_keys.add((tokens[0], tokens[7], tokens[8]))
    else:
        print(f"Warning: Could not locate base nav.dat.gz at '{SYSTEM_NAV_GZ}'. Proceeding without base ILS fallback.")

    # 3. Process local AIRAC file
    if not os.path.exists(SOURCE_AIRAC_FILE):
        print(f"Error: Source AIRAC file '{SOURCE_AIRAC_FILE}' not found in current folder.")
        print(f"Please place your new nav data here and rename it to '{SOURCE_AIRAC_FILE}'.")
        sys.exit(1)

    print(f"Processing AIRAC file '{SOURCE_AIRAC_FILE}'...")
    with open(SOURCE_AIRAC_FILE, 'r', encoding='utf-8', errors='ignore') as f:
        for idx, line in enumerate(f):
            tokens = line.strip().split()
            if not tokens:
                continue

            # Preserve header metadata lines
            if idx < 3 and not tokens[0].isdigit():
                output_lines.insert(idx, line)
                continue

            row_type = tokens[0]
            if row_type not in ILS_ROW_TYPES:
                output_lines.append(line)
            else:
                cleaned_line = clean_modern_ils_line(tokens.copy(), valid_runways)
                cleaned_tokens = cleaned_line.strip().split()
                if len(cleaned_tokens) >= 10:
                    key = (cleaned_tokens[0], cleaned_tokens[7], cleaned_tokens[8])
                    if key not in base_ils_keys:
                        output_lines.append(cleaned_line)

    # 4. Ensure target override directory exists
    try:
        os.makedirs(FG_NAV_OVERRIDE_DIR, exist_ok=True)
    except Exception as e:
        print(f"Error: Could not create directory '{FG_NAV_OVERRIDE_DIR}': {e}")
        sys.exit(1)

    # 5. Output directly to the override directory
    print(f"Writing sanitized hybrid database to '{OUTPUT_FILE}'...")
    try:
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            f.writelines(output_lines)
    except Exception as e:
        print(f"Error writing to output file: {e}")
        sys.exit(1)

    print("Success! Processed nav.dat deployed directly to FlightGear override location.")


if __name__ == "__main__":
    process_nav_files()
