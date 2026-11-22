# Contour-Flight

**Contour-Flight** is a standalone, extreme mountain-threading route planner for Little Navmap (`.lnmpln`) and FlightGear (`.fgfp`). Rather than generating standard, high-altitude commercial airways, Contour-Flight computes aggressive, low-level adventure corridors—skimming ridges, hugging canyon walls, and challenging whether an aircraft can weave *through* mountain peaks rather than flying far above them.

## Demo

https://github.com/user-attachments/assets/d44cb45f-6b50-4fd2-bdde-be29bee07667

> [!CAUTION]
> **Simulation Use Only:** Please do not use Contour-Flight for real-world aviation. Low-level mountain threading without certified terrain databases, obstacle data, and regulatory clearance is dangerous and likely illegal—keep it strictly to crashing your simulator in style.

## Core Architecture & Features

- **Any-Angle Theta* Routing**: Calculates non-grid-locked paths that hug complex mountain topography. — [Nash, Daniel, Koenig & Felner, AAAI 2007 (`aaai07a.pdf`)](https://idm-lab.org/bib/abstracts/papers/aaai07a.pdf)
- **Supercover Bresenham Line Checks**: Scans every grid cell touched by route segments to ensure absolute terrain tracking without tunneling through narrow ridges. — [Dedu, Supercover Bresenham](https://dedu.fr/projects/bresenham/)
- **Pure Python GLOBE Elevation Reader**: Fast, native binary parsing of GLOBE dataset tiles with in-memory caching and zero redundant external dependencies.
- **Configurable Grid Stride (`grid_step`)**: Steps every `N`th cell on the GLOBE elevation grid (similar to working on a downsampled image: `step=2` halves per-axis resolution for roughly 4× the area per step; `step=3` gives roughly 9×). Higher integer values speed up long searches within `max_iters` at the cost of coarser turns and potentially skipping narrow passes or straits; `grid_step=1` keeps full grid resolution.
- **Configurable Horizontal Obstacle Inflation**: The `horizontal_buffer_nm` parameter acts as a safety bubble around terrain. By checking a spatial buffer around every grid node, obstacles are effectively inflated—allowing you to tune whether the router carves wide, safe berths around peaks or shaves right against the cliff faces for maximum adrenaline.
- **Terminal Buffer Floor**: Scans airport surroundings to prevent pathfinding crashes caused by airports sitting "underground" relative to nearby inflated terrain barriers—automatically intercepting low inputs, logging an unmissable italicized notice, and rounding up to a viable starting floor.
- **Bi-Format Synchronization & Anchor Preservation**: Reads from and writes back to either Little Navmap (`.lnmpln`) or FlightGear (`.fgfp`) plans in-place while preserving comments, metadata, and manual anchor waypoints (such as `WP1`), labeling newly generated terrain-avoidance points `T01`, `T02`, etc. (`THETA_CORRIDOR_1`, ... in LNM).
- **Flexible CLI, Multi-Leg & External Plan Support**: Splits routes across manual anchor waypoints into independent legs (`Leg 1/N`, `Leg 2/N`, ...), merges near-collinear corridor steps within each leg via `collinear_tol_deg`, and supports optional altitude overrides, `--step` / `--max-iters` flags, and arbitrary `.lnmpln` or `.fgfp` paths (or via `--file` / `-f`).

---

## The Workflow Pipeline

Contour-Flight operates on saved draft files located in `DB_DIR` (by default `~/.cache/flight_dispatch/`).
The draft flight plan creator `lnmpln_creator.sh` that runs by consuming a formatted briefing of `flight.sh` (unified in `flight()` alias) generates the briefing and stages the cache via the upstream creator pipeline.

Once the draft cache is populated, `contour_route.py` checks `briefing.lnmpln` first (falling back to `briefing.fgfp`), calculates the extreme mountain corridor, and synchronizes both formats in-place.

---

## Prerequisites

1. **Python 3.x**
2. **Python Dependencies**:

	```bash
	pip install pyproj
	```

3. **GLOBE Elevation Dataset**: Ensure you have the GLOBE dataset (typically the `all10` directory) available locally on your machine.

---

### Configuration (`config.json`)

`contour_route.py` loads `config.json` from its own directory (`contour-flight/config.json`) so the tool stays portable regardless of your current working directory.

- **`LNM_DB`**, **`DB_URL`**, and **`DB_DIR`** are copied from the main project's `flight.conf`. Airport coordinate lookup checks `LNM_DB` first when present and falls back to `DB_URL` (reporting potential internet issues if resolution fails). `DB_DIR` sets the directory for briefing input and output files without creating empty directories on missing input.
- **`default_cruise_alt_ft`**: Fallback cruise altitude in feet when neither a CLI argument nor a cruise altitude tag in the briefing file is provided (if set to `null` or omitted, no fallback altitude is assumed).

### Cruise Altitude Priority

When planning a route, starting cruise altitude is resolved in this order:

1. **CLI argument** (e.g., `python contour_route.py 1500`)
2. **Briefing file altitude** (`<CruisingAlt>` in `briefing.lnmpln` or `<altitude-ft>` in `briefing.fgfp`, if present) 
3. **`default_cruise_alt_ft`** in `config.json`
4. **`collinear_tol_deg`** (default `0.10`): Maximum bearing difference (in degrees) between consecutive corridor points within a leg to collapse redundant collinear waypoints. Anchor endpoints are never merged; set to `0` to disable merging.

*Notes:*
- *The terminal buffer floor check in `plan()` still runs afterward and automatically raises `cruise_alt` if required for departure/destination terrain clearance.*
- *`config.json` is required at startup (`FileNotFoundError` is raised if missing) and is excluded via `.gitignore` to keep local machine paths private.*

---

## Usage

By default, Contour-Flight reads draft flight plans from `DB_DIR` (`briefing.lnmpln` first, then `briefing.fgfp`; under `~/.cache/flight_dispatch/`) and synchronizes both formats in-place. You can also target any standalone `.lnmpln` or `.fgfp` file directly.

- **Show CLI help:**
	```bash
	python contour_route.py --help
	```

- **Run using the saved briefing file's cruise altitude:**
	```bash
	python contour_route.py
	```

- **Run with a forced CLI cruise altitude override (e.g., 4,500 ft):**
	```bash
	python contour_route.py 4500
	```

- **Tune search stride (`--step` / `--grid_step`) or iteration budget (`--max-iters`) for tricky low-altitude legs:**
	```bash
	python contour_route.py --step=3
	python contour_route.py --max-iters=150000
	```

- **Run against any `.lnmpln` or `.fgfp` file** (altitude and file path can be passed in either order, or via `--file` / `-f`, with optional `--step` and `--max-iters` at the end):
	```bash
	python contour_route.py /path/to/plan.lnmpln
	python contour_route.py /path/to/plan.lnmpln 2500
	python contour_route.py 2500 /path/to/plan.fgfp
	python contour_route.py --file=/path/to/plan.lnmpln 2500
	python contour_route.py /path/to/plan.lnmpln 2500 --step=3 --max-iters=150000
	```

- **Optional shell alias** (add to `~/.bashrc` or `~/.zshrc` to run from any directory):
	```bash
	alias fg-contour='python3 "$HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/docs/contour-flight/contour_route.py"'
	```
