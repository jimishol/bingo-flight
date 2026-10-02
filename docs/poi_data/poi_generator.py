import csv
import os
import zipfile

# ==============================================================================
# CONFIGURATION ZONE
# ==============================================================================
# Country code (matches XX.zip downloaded beside this script)
COUNTRY_CODE = "GR"

# Paths
ZIP_FILE = f"{COUNTRY_CODE}.zip"
TARGET_DIR = COUNTRY_CODE
INPUT_TXT = os.path.join(TARGET_DIR, f"{COUNTRY_CODE}.txt")
OUTPUT_FILE = os.path.join(TARGET_DIR, "poi.dat")

# FlightGear POI type code (1000 = VISUAL_REPORTING_POINT)
POI_TYPE = 1000

# Feature Class 'T' (Terrain features in GeoNames)
FEATURE_CLASS = "T"

# Terrain rules & DEM elevation thresholds (in meters):
# Commenting out any line completely excludes that feature type from processing.
FEATURE_RULES = {
    # --- Active Features ---
    "ISL":  {"min_dem": 20,  "enabled": True, "append_alt": False, "desc": "Islands"},
    "MT":   {"min_dem": 350, "enabled": True, "append_alt": True,  "desc": "Mountains"},
    "PK":   {"min_dem": 1000, "enabled": True, "append_alt": True,  "desc": "Peaks"},

    # --- Commented Examples (Uncomment to enable) ---
    # "MTS":  {"min_dem": 400, "enabled": True, "append_alt": True,  "desc": "Mountain Ranges"},
    # "PKS":  {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Peak Groups"},
    # "PASS": {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Mountain Passes"},
    # "RDGE": {"min_dem": 500, "enabled": True, "append_alt": True,  "desc": "Ridges"},
    # "RK":   {"min_dem": 10,  "enabled": True, "append_alt": False, "desc": "Rocks / Islets"},
    # "VAL":  {"min_dem": 200, "enabled": True, "append_alt": False, "desc": "Valleys"},
}

# FlightGear POI Header definition
HEADER = f"""# poi.dat v1.02 - Custom VFR Reporting Points ({COUNTRY_CODE})
# Data extracted from GeoNames ({COUNTRY_CODE})
# ID = {POI_TYPE} (Visual Reporting Points)

# ID | LAT | LON | NAME
"""
# ==============================================================================


def ensure_input_extracted():
    """Checks if GR/GR.txt exists. If missing, extracts GR.zip into GR/ folder."""
    if os.path.exists(INPUT_TXT):
        return True

    if os.path.exists(ZIP_FILE):
        print(f"Extracting '{ZIP_FILE}' into '{TARGET_DIR}/'...")
        os.makedirs(TARGET_DIR, exist_ok=True)
        with zipfile.ZipFile(ZIP_FILE, "r") as zip_ref:
            zip_ref.extractall(TARGET_DIR)
        return os.path.exists(INPUT_TXT)

    return False


def get_dem_elevation(row):
    """Extracts DEM average elevation in meters from Column 17 (Index 16)."""
    if len(row) < 17:
        return 0
    dem_str = row[16].strip()
    return int(dem_str) if dem_str.lstrip("-").isdigit() else 0


def process_geonames_to_poi():
    if not ensure_input_extracted():
        print(f"Error: Neither '{INPUT_TXT}' nor '{ZIP_FILE}' was found.")
        print(f"Please place '{ZIP_FILE}' next to 'poi_generator.py' or extract it to '{TARGET_DIR}/'.")
        return

    os.makedirs(TARGET_DIR, exist_ok=True)

    stats = {code: {"found": 0, "kept": 0} for code in FEATURE_RULES}
    total_written = 0

    with open(INPUT_TXT, mode="r", encoding="utf-8") as infile, \
         open(OUTPUT_FILE, mode="w", encoding="utf-8") as outfile:

        outfile.write(HEADER)
        reader = csv.reader(infile, delimiter="\t")

        for row in reader:
            if len(row) < 8:
                continue

            feature_class = row[6].strip()
            feature_code = row[7].strip()

            # Skipping missing feature keys here guarantees commented-out rules are ignored
            if feature_class != FEATURE_CLASS or feature_code not in FEATURE_RULES:
                continue

            rule = FEATURE_RULES[feature_code]
            if not rule["enabled"]:
                continue

            stats[feature_code]["found"] += 1

            dem_m = get_dem_elevation(row)
            if dem_m < rule["min_dem"]:
                continue

            name_ascii = row[2].strip()
            if not name_ascii:
                continue

            lat = float(row[4])
            lon = float(row[5])

            # Build name string formatted for FlightGear poidb.cxx
            if rule["append_alt"] and dem_m > 0:
                dem_ft = int(round(dem_m * 3.28084))
                formatted_name = f"{name_ascii} ({dem_ft} ft)"
            else:
                formatted_name = name_ascii

            # Format: <rawType> <lat> <lon> <name>
            outfile.write(f"{POI_TYPE} {lat:.7f} {lon:.7f} {formatted_name}\n")
            
            stats[feature_code]["kept"] += 1
            total_written += 1

    print("=" * 60)
    print(f"GeoNames POI Generator ({COUNTRY_CODE}) - Scan Summary")
    print("=" * 60)
    for code, rule in FEATURE_RULES.items():
        if rule["enabled"]:
            found = stats[code]["found"]
            kept = stats[code]["kept"]
            min_dem = rule["min_dem"]
            desc = rule["desc"]
            print(f"- {code:4s} ({desc:15s}): {kept:4d} exported / {found:4d} found (DEM >= {min_dem}m)")
    print("-" * 60)
    print(f"Total VRP entries written to {OUTPUT_FILE}: {total_written}")
    print("=" * 60)


if __name__ == "__main__":
    process_geonames_to_poi()
