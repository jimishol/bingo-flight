import csv
import os
import sys
import zipfile

# ==============================================================================
# CONFIGURATION ZONE
# ==============================================================================
# FlightGear POI type code (1000 = VISUAL_REPORTING_POINT)
POI_TYPE = 1000

# Feature Class 'T' (Terrain features in GeoNames)
FEATURE_CLASS = "T"

# Terrain rules & DEM elevation thresholds (in meters):
FEATURE_RULES = {
    # --- Active Features ---
    "ISL":  {"min_dem": 20,   "enabled": True, "append_alt": False, "desc": "Islands"},
    "MT":   {"min_dem": 350,  "enabled": True, "append_alt": True,  "desc": "Mountains"},
    "PK":   {"min_dem": 1000, "enabled": True, "append_alt": True,  "desc": "Peaks"},

    # --- Commented Examples (Uncomment to enable) ---
    # "MTS":  {"min_dem": 400, "enabled": True, "append_alt": True,  "desc": "Mountain Ranges"},
    # "PKS":  {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Peak Groups"},
    # "PASS": {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Mountain Passes"},
    # "RDGE": {"min_dem": 500, "enabled": True, "append_alt": True,  "desc": "Ridges"},
    # "RK":   {"min_dem": 10,  "enabled": True, "append_alt": False, "desc": "Rocks / Islets"},
    # "VAL":  {"min_dem": 200, "enabled": True, "append_alt": False, "desc": "Valleys"},
}
# ==============================================================================


def get_country_code() -> str:
    """Gets the prefix from CLI arguments or exits if missing."""
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print("Error: prefix must be supplied")
        sys.exit(1)

    return sys.argv[1].strip().upper()


def ensure_input_extracted(country_code: str, target_dir: str, input_txt: str, zip_file: str) -> bool:
    """Extracts XX.zip into XX/ directory, overwriting existing files if zip exists."""
    if os.path.exists(zip_file):
        print(f"Extracting '{zip_file}' into '{target_dir}/'...")
        os.makedirs(target_dir, exist_ok=True)
        with zipfile.ZipFile(zip_file, "r") as zip_ref:
            zip_ref.extractall(target_dir)
        return os.path.exists(input_txt)

    return os.path.exists(input_txt)


def get_dem_elevation(row: list) -> int:
    """Extracts DEM average elevation in meters from Column 17 (Index 16)."""
    if len(row) < 17:
        return 0
    dem_str = row[16].strip()
    return int(dem_str) if dem_str.lstrip("-").isdigit() else 0


def process_geonames_to_poi():
    country_code = get_country_code()
    zip_file = f"{country_code}.zip"
    target_dir = country_code
    input_txt = os.path.join(target_dir, f"{country_code}.txt")
    output_file = os.path.join(target_dir, "poi.dat")

    header = f"""# poi.dat v1.02 - Custom VFR Reporting Points ({country_code})
# Data extracted from GeoNames ({country_code})
# ID = {POI_TYPE} (Visual Reporting Points)

# ID | LAT | LON | NAME
"""

    if not ensure_input_extracted(country_code, target_dir, input_txt, zip_file):
        print(f"Error: Neither '{input_txt}' nor '{zip_file}' was found.")
        print(f"Please place '{zip_file}' next to 'poi_generator.py' or extract it to '{target_dir}/'.")
        sys.exit(1)

    os.makedirs(target_dir, exist_ok=True)

    stats = {code: {"found": 0, "kept": 0} for code in FEATURE_RULES}
    total_written = 0

    with open(input_txt, mode="r", encoding="utf-8") as infile, \
         open(output_file, mode="w", encoding="utf-8") as outfile:

        outfile.write(header)
        reader = csv.reader(infile, delimiter="\t")

        for row in reader:
            if len(row) < 8:
                continue

            feature_class = row[6].strip()
            feature_code = row[7].strip()

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

            if rule["append_alt"] and dem_m > 0:
                dem_ft = int(round(dem_m * 3.28084))
                formatted_name = f"{name_ascii} ({dem_ft} ft)"
            else:
                formatted_name = name_ascii

            outfile.write(f"{POI_TYPE} {lat:.7f} {lon:.7f} {formatted_name}\n")

            stats[feature_code]["kept"] += 1
            total_written += 1

    print("=" * 60)
    print(f"GeoNames POI Generator ({country_code}) - Scan Summary")
    print("=" * 60)
    for code, rule in FEATURE_RULES.items():
        if rule["enabled"]:
            found = stats[code]["found"]
            kept = stats[code]["kept"]
            min_dem = rule["min_dem"]
            desc = rule["desc"]
            print(f"- {code:4s} ({desc:15s}): {kept:4d} exported / {found:4d} found (DEM >= {min_dem}m)")
    print("-" * 60)
    print(f"Total VRP entries written to {output_file}: {total_written}")
    print("=" * 60)


if __name__ == "__main__":
    process_geonames_to_poi()
