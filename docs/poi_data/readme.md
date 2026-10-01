# FlightGear Custom POI Generator (`poi_generator.py`)

A light, standalone Python utility that parses raw **GeoNames** geographical dumps and generates a filtered, FlightGear-compatible Points of Interest database file (`poi.dat`).

This tool specifically extracts major individual islands, converting them into **Visual Reporting Points (Type `1000`)** while stripping away sea-level rocks, reefs, archipelagos, and administrative boundaries.

---

## Features

* **FlightGear-Safe Encoding:** Uses ASCII names (`asciiname` column) to prevent character encoding crashes or rendering glitches inside FlightGear.
* **Smart Elevation Filtering:** Employs a **Digital Elevation Model (DEM)** floor filter. Automatically filters out minor low-lying rocks and shallow reefs (under 20 meters average elevation) while retaining inhabited islands.
* **Granular Feature Selection:** Filters explicitly for terrain features (`T`) and individual island codes (`ISL`), excluding archipelago/group names (`ISLS`).
* **Auto-Formatted Headers:** Prepends the mandatory 2-line header comment expected by FlightGear's C++ loader (`poidb.cxx`).

---

## Prerequisites & Data Source

### Prerequisites
* **Python:** Python 3.6+ (uses built-in standard module `csv`).
* **Input File:** Tab-delimited GeoNames country dump file.

### Obtaining Data Files
This script is designed to run directly against official country dumps downloaded from the **[GeoNames Dump Server](https://download.geonames.org/export/dump/)**.

1. Visit **[https://download.geonames.org/export/dump/](https://download.geonames.org/export/dump/)**.
2. Download your target country archive (e.g., `GR.zip` for Greece, `IT.zip` for Italy, `ES.zip` for Spain).
3. Unzip the file and place the `.txt` dataset (e.g., `GR.txt`) in the same folder as `poi_generator.py`.

---

## Usage

Run the script directly via terminal or command prompt:

```bash
python3 poi_generator.py

```

### Sample Console Output

```text
Scan Complete.
- Total 'ISL' terrain entries found: 412
- Islands exported to poi.dat (DEM >= 20m): 85
- Flat islets/rocks filtered out: 327

```

---

## Configuration Zone

All operational controls are located in the **CONFIGURATION ZONE** at the top of `poi_generator.py`:

```python
# ==============================================================================
# CONFIGURATION ZONE
# ==============================================================================
INPUT_FILE = "GR.txt"              # Source GeoNames dump file
OUTPUT_FILE = "poi.dat"            # Target FlightGear POI output
POI_TYPE = 1000                    # FlightGear POI Type ID (1000 = VISUAL_REPORTING_POINT)
FEATURE_CLASS = "T"                # 'T' = Terrain features
ACCEPTED_FEATURE_CODES = ["ISL"]   # 'ISL' = Single/Individual Islands
MIN_DEM_ELEVATION = 20             # Minimum average elevation in meters (DEM index 16)
# ==============================================================================

```

### Key Parameter Details

| Variable | Default | Purpose |
| --- | --- | --- |
| `POI_TYPE` | `1000` | Assigns `VISUAL_REPORTING_POINT`. Avoids misidentifying islands as cities/towns or triggering `SG_RANGE_EXCEPTION` in `poidb.cxx`. |
| `FEATURE_CLASS` | `"T"` | Filters strictly for Terrain features, ignoring administrative zones (`A`) or populated places (`P`). |
| `ACCEPTED_FEATURE_CODES` | `["ISL"]` | Python list of accepted codes. Excludes `ISLS` (island chains/archipelagos) to ensure targets point to distinct islands. |
| `MIN_DEM_ELEVATION` | `20` | Evaluates Column 17 (DEM average). Items under 20 meters (flat reefs, micro-islets) are skipped. |

---

## Output File Format (`poi.dat`)

The generated output adheres strictly to the schema required by FlightGear's `poidb.cxx`:

```text
# poi.dat v1.02 - Filtered Main Islands
# Data extracted from GeoNames (GR.txt)
# ID = 1000 (Visual Reporting Points for Major Islands)

# ID | LAT | LON | NAME
1000 38.3683300 26.0638900 Nisis Chios
1000 39.1000000 26.5500000 Lesvos Island
1000 37.7500000 26.9833300 Samos Island

```

---

## Installing into FlightGear

By leveraging the `NavData_Override` folder structure, FlightGear treats your custom POI database as a top-priority patch layer while keeping the core installation untouched.

Place your generated `poi.dat` in the following directory layout inside your custom scenery or FlightGear root path:

```text
Flightgear/NavData_Override/
└── NavData/
    ├── nav/
    │   └── nav.dat       <-- AIRAC merged navigation data
    └── poi/
        └── poi.dat       <-- Custom Type 1000 VRP database

```

---

## License & Data Attribution

Data is sourced from **[GeoNames](https://www.geonames.org/)** under the **Creative Commons Attribution 4.0 License (CC BY 4.0)**.

```
