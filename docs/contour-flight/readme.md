# Contour-Flight

**Contour-Flight** is a standalone, extreme mountain-threading route planner for Little Navmap (`.lnmpln`) and FlightGear (`.fgfp`). Rather than generating standard, high-altitude commercial airways, Contour-Flight computes aggressive, low-level adventure corridors—skimming ridges, hugging canyon walls, and challenging whether an aircraft can weave *through* mountain peaks rather than flying far above them.

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

Contour-Flight operates on saved draft files located in `~/.cache/flight_dispatch/`.
The draft flight plan creator `lnmpln_creator.sh` that run by consuming a formatted briefing of `flight.sh` (unified in `flight()` alias) generate the briefing and stage the cache via the upstream creator pipeline.

Once the draft cache is populated, `contour-flight` intercepts it, calculates the extreme mountain corridor, and synchronizes both formats in-place.

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

* **`default_cruise_alt_ft`**: Fallback cruise altitude in feet when neither a CLI argument nor a cruise altitude tag in the briefing file is provided (if set to `null` or omitted, no fallback altitude is assumed).
* **`DB_SOURCE`, `LNM_DB`** and **`DB_URL`** are copies from main project's `flight.conf`.

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

Contour-Flight reads draft flight plans automatically from the local cache (`~/.cache/flight_dispatch/briefing.lnmpln` or `.fgfp`).

* **Run using the saved briefing file's cruise altitude:**
	```bash
	python contour_route.py
	```

* **Run with a forced CLI cruise altitude override (e.g., 4,500 ft):**
	```bash
	python contour_route.py 4500
	```