# Contour-Flight

**Contour-Flight** is a standalone, extreme mountain-threading route planner for Little Navmap (`.lnmpln`) and FlightGear (`.fgfp`). Rather than generating standard, high-altitude commercial airways, Contour-Flight computes aggressive, low-level adventure corridors—skimming ridges, hugging canyon walls, and challenging whether an aircraft can weave *through* mountain peaks rather than flying far above them.

## Demo

<!-- Drag & drop your 7.8 MB .mp4 onto the line below in GitHub's web editor and remove this comment -->

## Core Architecture & Features

- **Any-Angle Theta* Routing**: Calculates efficient, non-grid-locked paths that hug complex mountain topography.
- **Supercover Bresenham Line Checks**: Scans every grid cell touched by route segments to ensure absolute terrain tracking without tunneling through narrow ridges.
- **Pure Python GLOBE Elevation Reader**: Fast, native binary parsing of GLOBE dataset tiles with in-memory caching and zero redundant external dependencies.
- **Configurable Horizontal Obstacle Inflation**: The `horizontal_buffer_nm` parameter acts as a safety bubble around terrain. By checking a spatial buffer around every grid node, obstacles are effectively inflated—allowing you to tune whether the router carves wide, safe berths around peaks or shaves right against the cliff faces for maximum adrenaline.
- **Terminal Buffer Floor**: Scans airport surroundings to prevent pathfinding crashes caused by airports sitting "underground" relative to nearby inflated terrain barriers—automatically intercepting low inputs, logging an unmissable italicized notice, and rounding up to a viable starting floor.
- **Bi-Format Synchronization**: Reads from and writes back to either Little Navmap (`.lnmpln`) or FlightGear (`.fgfp`) draft caches in-place while preserving custom comments and metadata.
- **CLI Altitude Override**: Supports passing explicit low-level altitude overrides directly from the command line (e.g., `python contour_route.py 1200`) when carving your path through the peaks.

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

*Notes:*
- *The terminal buffer floor check in `plan()` still runs afterward and automatically raises `cruise_alt` if required for departure/destination terrain clearance.*
- *`config.json` is excluded via `.gitignore` to keep local machine paths private.*

---

## Usage

Contour-Flight reads draft flight plans automatically from `DB_DIR` (`briefing.lnmpln` first, then `briefing.fgfp`; by default under `~/.cache/flight_dispatch/`).

- **Run using the saved briefing file's cruise altitude:**
	```bash
	python contour_route.py
	```

- **Run with a forced CLI cruise altitude override (e.g., 4,500 ft):**
	```bash
	python contour_route.py 4500
	```

- **Optional shell alias** (add to `~/.bashrc` or `~/.zshrc` to run from any directory):
	```bash
	alias fg-contour='python3 "$HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/docs/contour-flight/contour_route.py"'
	```
