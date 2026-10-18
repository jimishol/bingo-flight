# FlightGear AIRAC Runway Merger & Navaid Sanitizer

This utility automates the patching of modern AIRAC 1100-style `nav_AIRAC.dat` files for FlightGear.

It resolves discrepancies between modern real-world runway designators (e.g., `28C`, `27R`) and stock scenery definitions in FlightGear's `apt.dat.gz` (e.g., `28`). By ensuring radio navaids (ILS, GS, DME, and Markers) properly bind to physical ground models, it prevents C++ database lookup failures and missing radio signals.

---

## Technical Overview

1. **Scenery Inspection:** Reads system `apt.dat.gz` in memory to build a dictionary of valid runway designators for every airport in the stock scenery database (parsing row code `100` indices `8` and `17`).
2. **Navaid Reconciliation:** Evaluates ILS (`4`), Glide Slope (`6`), Outer/Middle/Inner Markers (`7`, `8`, `9`), and DME-ILS (`12`) records:
   * **Suffix Stripping:** Converts designators like `28C` -> `28` if stock scenery omits parallel runway letters.
   * **Magnetic Drift Alignment:** Matches nearby numeric headings (e.g., `27` -> `28`) within +/- 2 numbers.
3. **Format Preservation:** Uses regex splitting (`re.split(r'(\s+)', line)`) to replace runway tokens without altering surrounding whitespace or column alignment.

---

## Usage Instructions

### 1. File Placement
Place your updated AIRAC navigation file (e.g., `earth_nav.dat`) in this directory (`docs/nav_merged_ILS/`) and rename it to:
`nav_AIRAC.dat`

### 2. Run the Patch Script
Execute the script from inside this directory:

```bash
cd docs/nav_merged_ILS/
python3 merge_and_clean_nav.py

```

### 3. Target Output

The patched file is automatically deployed to `OUTPUT_FILE` (defined inside the script configuration):
`/mnt/data/games/Flightgear/NavData_Override/NavData/nav/nav.dat`

*Note: Edit the `OUTPUT_DIR` variable inside `merge_and_clean_nav.py`.*
---

## Environment Variables

The script uses sensible system defaults, but you can override paths via environment variables if needed:

* `FG_ROOT`: FlightGear data directory (Default: `/usr/share/flightgear`)
* `FG_HOME`: User configuration folder (Default: `~/.fgfs`)
