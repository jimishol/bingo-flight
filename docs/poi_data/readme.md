# FlightGear Custom POI Generator (`poi_generator.py`)

A light, standalone Python utility that parses raw **GeoNames** geographical dumps and generates a filtered, FlightGear-compatible Points of Interest database file (`poi.dat`).

This tool extracts prominent terrain landmarks (mountains, peaks, islands, passes), converting them into **Visual Reporting Points (Type `1000`)** while stripping away sea-level rocks, minor hills, and administrative boundaries.

---

## Features

* **Automatic Zip Extraction:** Extracts `GR.zip` automatically into a target `GR/` directory if raw text files aren't pre-extracted.
* **FlightGear-Safe Encoding:** Uses ASCII names (`asciiname` column) to prevent character encoding crashes or rendering glitches inside FlightGear.
* **Smart Elevation Filtering:** Employs per-feature **Digital Elevation Model (DEM)** floor filters to ignore minor topography while keeping major landmarks.
* **Granular Feature Selection:** Uses a configurable dictionary (`FEATURE_RULES`) allowing you to enable, disable, or comment out specific GeoNames terrain codes (`MT`, `PK`, `ISL`, `PASS`, etc.).
* **Visual Elevation Tags:** Appends calculated elevations in feet (`Olympos (9573 ft)`) to display names for instant cockpit awareness.
* **Auto-Formatted Headers:** Prepends the mandatory header comments expected by FlightGear's C++ loader (`poidb.cxx`).

---

## Prerequisites & Data Source

### Prerequisites
* **Python:** Python 3.6+ (uses built-in standard modules `csv`, `os`, `zipfile`).
* **Input File:** Target country `.zip` archive from GeoNames.

### Obtaining Data Files & Running

1. Visit the **[GeoNames Dump Server](https://download.geonames.org/export/dump/)**.
2. Download your target country archive (e.g., `GR.zip` for Greece).
3. Place `GR.zip` in the same folder as `poi_generator.py`.
4. Run the script:

```bash
python3 poi_generator.py

```

> **Note:** The script automatically creates a `GR/` subfolder, extracts `GR.txt`, and outputs `GR/poi.dat`.

---

## Sample Console Output

```text
Extracting 'GR.zip' into 'GR/'...
============================================================
GeoNames POI Generator (GR) - Scan Summary
============================================================
- ISL  (Islands        ):  396 exported / 1035 found (DEM >= 20m)
- MT   (Mountains      ):  751 exported /  820 found (DEM >= 350m)
- PK   (Peaks          ):  406 exported / 1091 found (DEM >= 1000m)
------------------------------------------------------------
Total VRP entries written to GR/poi.dat: 1553
============================================================
```

---

## Configuration Zone

All operational controls are located in the `FEATURE_RULES` dictionary at the top of `poi_generator.py`.

Features can be toggled via `"enabled": True/False` or simply by **commenting out** the feature line:

```python
FEATURE_RULES = {
    # --- Active Features ---
    "ISL":  {"min_dem": 20,  "enabled": True, "append_alt": False, "desc": "Islands"},
    "MT":   {"min_dem": 350, "enabled": True, "append_alt": True,  "desc": "Mountains"},
    "PK":   {"min_dem": 1000, "enabled": True, "append_alt": True,  "desc": "Peaks"},

    # --- Commented Examples (Uncomment to enable) ---
    # "MTS":  {"min_dem": 400, "enabled": True, "append_alt": True,  "desc": "Mountain Ranges"},
    # "PKS":  {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Peak Groups"},
    # "PASS": {"min_dem": 600, "enabled": True, "append_alt": True,  "desc": "Mountain Passes"},
}

```

### Parameter Details

* **`min_dem`:** Minimum average elevation in meters (GeoNames DEM index 16). Features below this floor are skipped.
* **`enabled`:** Set to `False` to temporarily skip a feature without deleting the rule.
* **`append_alt`:** When `True`, converts DEM meters to feet and appends it to the POI display name (e.g., `Olympos (9573 ft)`).
* **Commenting Out Rules:** Any line commented out (`# "ISL": ...`) is completely excluded from memory and processing.

---

## Output File Format (`poi.dat`)

The generated database is saved to `GR/poi.dat` and adheres strictly to the schema required by FlightGear's `poidb.cxx`:

```text
# poi.dat v1.02 - Custom VFR Reporting Points (GR)
# Data extracted from GeoNames (GR)
# ID = 1000 (Visual Reporting Points)

# ID | LAT | LON | NAME
1000 39.9423500 25.2433000 Lemnos
1000 40.0817500 22.3495400 Mount Olympus (9462 ft)
1000 38.5352800 22.6218800 Parnassus (7933 ft)
```

---

## Installing into FlightGear

By leveraging the `NavData_Override` folder structure, FlightGear treats your custom POI database as a top-priority patch layer while keeping the core installation untouched.

Place your generated `poi.dat` in the following directory layout inside your custom scenery or FlightGear root path:

```text
Flightgear/NavData_Override/
└── NavData/
    ├── nav/
    │   └── nav.dat        <-- AIRAC merged navigation data
    └── poi/
        └── poi.dat        <-- Custom Type 1000 VRP database

```

---

## License & Data Attribution

Data is sourced from **[GeoNames](https://www.geonames.org/)** under the **Creative Commons Attribution 4.0 License (CC BY 4.0)**.
