import csv

# ==============================================================================
# CONFIGURATION ZONE
# ==============================================================================
INPUT_FILE = "GR.txt"
OUTPUT_FILE = "poi.dat"

# FlightGear POI type code (1000 = VISUAL_REPORTING_POINT)
# Type 1000 treats islands as visual landmarks without misclassifying them as 
# cities/towns or triggering SG_RANGE_EXCEPTION errors in poidb.cxx.
POI_TYPE = 1000

# Feature Class 'T' stands for Terrain features in GeoNames (mountains, islands, rocks, etc.).
# Filtering strictly by 'T' prevents administrative boundaries (Class 'A') or 
# populated places (Class 'P') from mixing with geographical island markers.
FEATURE_CLASS = "T"

# 'ISL' = Single/Individual Island in GeoNames.
# Restricting to 'ISL' excludes archipelagos/groups ('ISLS') like the Cyclades or 
# Sporades, ensuring flight vectors target specific islands rather than region names.
ACCEPTED_FEATURE_CODES = ["ISL"]

# Minimum average elevation in meters (Column 17 / DEM index 16).
# WHY THIS REPLACES NAME KEYWORDS:
# Sea-level rocks, reefs, and low-lying islets register a DEM grid average between 
# 0m and 15m. Major inhabited islands (e.g., Lemnos, Ios, Chios) have high interior 
# terrain, giving them a DEM average of >= 20m. Setting this floor cleanly drops 
# flat coastal rocks without risking false-positive keyword exclusions.
MIN_DEM_ELEVATION = 20

# FlightGear POI Header definition.
# FlightGear's POILoader (poidb.cxx) skips the first 2 lines automatically. 
# Subsequent lines starting with '#' are parsed as comments and ignored.
HEADER = f"""# poi.dat v1.02 - Filtered Main Islands
# Data extracted from GeoNames ({INPUT_FILE})
# ID = {POI_TYPE} (Visual Reporting Points for Major Islands)

# ID | LAT | LON | NAME
"""
# ==============================================================================


def is_valid_island(row):
    """
    Evaluates a GeoNames CSV row against the Configuration Zone settings.
    
    GeoNames 'geoname' table structure (0-indexed):
    row[2]  : asciiname (Clean ASCII string, avoids encoding bugs in FlightGear)
    row[4]  : latitude
    row[5]  : longitude
    row[6]  : feature_class ('T', 'P', 'A', etc.)
    row[7]  : feature_code ('ISL', 'ISLS', 'ISLET', etc.)
    row[16] : dem (Digital Elevation Model average in meters)
    """
    # Ensure row contains enough fields for DEM evaluation
    if len(row) < 17:
        return False

    feature_class = row[6]
    feature_code = row[7]

    # 1. Feature Class & Feature Code Filter
    if feature_class != FEATURE_CLASS or feature_code not in ACCEPTED_FEATURE_CODES:
        return False

    # 2. DEM Elevation Filter
    # Parses SRTM/GTOPO30 elevation to strip low-altitude islets and rocks
    dem_str = row[16].strip()
    dem = int(dem_str) if dem_str.lstrip("-").isdigit() else 0
    if dem < MIN_DEM_ELEVATION:
        return False

    # 3. Name check (Column 3 / Index 2: asciiname)
    name_ascii = row[2].strip()
    if not name_ascii:
        return False

    return True


def process_geonames_to_poi():
    total_islands = 0
    kept_islands = 0

    with open(INPUT_FILE, mode="r", encoding="utf-8") as infile, \
         open(OUTPUT_FILE, mode="w", encoding="utf-8") as outfile:

        # Write required FlightGear POI header
        outfile.write(HEADER)
        reader = csv.reader(infile, delimiter="\t")

        for row in reader:
            if len(row) < 8:
                continue

            # Track total 'ISL' entries in the input file
            if row[6] == FEATURE_CLASS and row[7] in ACCEPTED_FEATURE_CODES:
                total_islands += 1

            if is_valid_island(row):
                name = row[2].strip()  # Column 3: asciiname
                lat = float(row[4])    # Column 5: Latitude
                lon = float(row[5])    # Column 6: Longitude

                # Format expected by poidb.cxx: <rawType> <lat> <lon> <name>
                outfile.write(f"{POI_TYPE} {lat:.7f} {lon:.7f} {name}\n")
                kept_islands += 1

    print(f"Scan Complete.")
    print(f"- Total 'ISL' terrain entries found: {total_islands}")
    print(f"- Islands exported to {OUTPUT_FILE} (DEM >= {MIN_DEM_ELEVATION}m): {kept_islands}")
    print(f"- Flat islets/rocks filtered out: {total_islands - kept_islands}")


if __name__ == "__main__":
    process_geonames_to_poi()
