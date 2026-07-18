# Bingo-Flight Dispatch Engine

A lightweight, terminal-native flight dispatch and career-tracking engine written in pure Bash and Python 3. Tailored for flight simulation enthusiasts who value terminal efficiency, this self-contained system automates dispatch manifest planning, handles multi-zone cabin payloads, generates localized scenario briefings, and provides a raw command-line logbook to track lifetime aviation goals without tracking pixels, telemetry, or server setups.

```text
~ 🐧 flight lg
Rolling the dice for a random airfield matching prefix 'LG' (DECK-aware)...
=========================================================
                    DISPATCH BRIEFING                    
=========================================================
Destination : Tanagra Air Base
Location    : Tanagra, GR (ICAO: LGTG)
---------------------------------------------------------
Manifest    : 3 Passengers | Baggage: heavy
Context     : CRITICAL LOAD: An entire family loaded to the limit with large suitcases. Performance may hit its boundaries.
---------------------------------------------------------
Log Engine  : [LG] Prefix Progress: 26/53 Fields Met (49.1%).
---------------------------------------------------------
• Pilot Weight          :    210 lbs
• Passenger 1           :    150 lbs
• Passenger 2           :    181 lbs
• Passenger 3           :    208 lbs
• Cargo                 :     97 lbs (heavy load)
=========================================================
Calculate your Weight & Balance carefully before advancing the throttle!
Have a great flight!
~ 🐧 flight -f
=========================================================
                LOGBOOK STORAGE MANAGEMENT                
=========================================================
Cache Directory: /home/jimishol/.cache/flight_dispatch
---------------------------------------------------------
TRACKING FILE          | PROGRESS      | LAST KNOWN POSITION
---------------------------------------------------------
journey_log.txt        |  3  /15       | Last: LTAR
visited_LG.txt         | 26  /53       | Last: LGTG
visited_LI.txt         |  7  /121      | Last: LIRL
visited_LT.txt         |  3  /75       | Last: LTCS
visited_WS.txt         |  1  /7        | Last: WSAP
---------------------------------------------------------
🚀 Spawning logbook workspace shell. Type 'exit' to close.
=========================================================
~/.cache/flight_dispatch 🐧 
```

## 🚀 Features

* **GPL-3.0 Licensed Open-Source Platform**: Built to protect software freedom, ensuring all derivative additions and expansions remain fully accessible to the community.
* **Tiered Fleet Layouts**: Computes strict weight-and-balance manifests based on realistic constraints for Helicopters, Small Airplanes, Medium Airplanes, and Large Airliners via `flight_tiers.conf`.
* **Multi-Format Flight Plan Ingestion**: Seamlessly reads both FlightGear (`.fgfp`) and Little Navmap (`.lnmpln`) native flight plan layouts to convert external tracks into interactive sequential career journeys.
* **Sub-Shell Logbook Workspace**: Direct interactive access to state storage. Spawns an internal terminal sub-shell directly in your cache directory, rejecting opaque database locks to give power users absolute autonomy to audit, repair, or backup career text records using standard terminal utilities.
* **Rich Narrative Logic**: Evaluates your passenger manifests and cargo bounds to select structural text blocks from the localization database, painting context for empty freight runs, heavy operations, or multi-leg journeys.
* **Zero-Dependency POSIX Execution**: Designed as an uncoupled, zero-installation footprint utility. Decoupled native configurations isolate text processing from core script memory, avoiding fragile Python runtime environments or heavy third-party framework layers.

---

## 🏗️ System Architecture

The project splits operational mechanics across dedicated, isolated functional components under the `lib/` directory:

* **`flight.sh`**: The master orchestration layer. Processes command arguments, queries background Python compilation utilities for airport routing lookups, and calculates runtime payload manifests.
* **`lib/config.sh`**: An optimized native INI interpreter. Iterates over section-blocks inside `flight_tiers.conf` to trim trailing spaces, match active configurations, and pull limits for the current profile.
* **`lib/interface_parser.sh`**: A strict POSIX-safe asset parser. Strips UTF-8 Byte Order Marks (BOM), removes outer wrapping symbols, and applies `printf -v` definitions to globally surface `lbl_` interface identifiers to the execution context while protecting memory scope.
* **`lib/story_loader.sh`**: A smart narrative locator. Orchestrates folder resolution rules (`stories/[LANG]/[TIER]`), handling fallbacks to English strings if regional options are absent or corrupted.

---

## ⚙️ Configuration & Setup

### 1. Project Directory Placement
Clone the repository and jump into the engine root directory:

```bash
git clone https://github.com/jimishol/bingo-flight.git
cd bingo-flight
```

After cloning, create your local configs:

```bash
cp flight.conf.example flight.conf && cp flight_tiers.conf.example flight_tiers.conf
```

*(Note: If file executable permissions are altered during structural downloads across varying operating system layouts, apply `chmod +x flight.sh` to restore binary invocation rights).*

### 2. General Preferences (`flight.conf`)

Establish your starting airport metrics, primary fleet parameters, and database paths here:

```bash
VEHICLE_TIER="small_airplane"
HOME_ICAO="LGHI"
CITIES_ALERT_THRESHOLD=5
CONFIRMATION=false  

# Provider options: "GLOBAL" (OurAirports stream) or "LNM" (Local Little Navmap Cache)
DB_SOURCE="LNM"
LNM_DB="/path/to/where_LNM_stores/navigraph_cache.sqlite"

```

> ⚓ **The Role of `HOME_ICAO`:**
> This field defines the pilot's primary operational base. Within the destination generation engine, under **unvisited target tracking (`-n`)**, the pilot's home base is **always considered automatically visited** inside its respective territory prefix. This means the engine will never generate the pilot's home field as a destination target when using the `-n` option, explicitly forcing the exploration of other unvisited airfields.

### 3. Dynamic Environment Overrides (Hot-Swapping)
You do not need to modify `flight.conf` every time you change your tier — the default is small_airplane. By passing the tier environment variable directly ahead of the script invocation, you can execute complex single-flight testing arrays seamlessly:


```bash
# Example A: Force a one-time dispatch using Large Airplane parameters for a random Greek field
VEHICLE_TIER=large_airplane ./flight.sh lg

# Example B: Evaluate an unvisited regional rollout using Helicopter tier weights
VEHICLE_TIER=helicopter ./flight.sh -n lg

```

>   > ### 🪶 Prefers a Zero-Configuration Single File?
>   >
>   >
>   > Unlike typical flight logging applications that force complex global databases and multi-folder configurations onto you from day one, the engine provides an entirely self-contained, lightweight alternative: **`flight_small_standalone.sh`**.
>   > **Operational Context & Constraints:**
>   > * **Fixed Localization:** Operates exclusively using English narrative blocks embedded right within the script file.
>   > * **Locked Fleet Profile:** Configured strictly out-of-the-box for the `small_airplane` performance class.
>   > * **Deterministic Briefings:** Skips external `pax*__bag*.txt` lookups entirely for a clean, predictable text layout.
>   > * **Drop-In Portability:** Ideal for quick test runs or minimalist simulation setups where you only want baseline dispatch weight calculations and text career logs without structural backend folders.
>   >
>   >
>   > To spin it up directly without any configuration files:
>   > ```bash
>   >chmod +x flight_small_standalone.sh
>   > ./flight_small_standalone.sh
>   >
>   > ```
>   >
>   >

---

### 4. Real-Time Flight Plan Generator (Optional)

Add this wrapper function to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.bash_aliases`) to automatically compile and export synchronized flight plans to `$HOME/.cache/flight_dispatch/briefing.[fgfp|lnmpln]` every time you fetch a briefing. This feeds your active routing and remarks directly into FlightGear and Little Navmap without manual file handling.

```bash
flight() {
    case " $* " in
        *" -f "*|*" --files "*|*" -e "*|*" -h "*|*" --help "*|*" --reset *)
            $HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/flight.sh "$@"
            ;;
        *)
            # Pure POSIX pipeline: flight streams to tee, tee splits to screen and creator
            $HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/flight.sh "$@" | tee /dev/tty | $HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/lnmpln_creator.sh
            ;;
    esac
}
```

---

### Departure Resolution Strategies

You can configure how `lnmpln_creator.sh` dynamically locates your next departure airfield (`DEP_ICAO`) by updating the `DEPARTURE_STRATEGY` variable inside the script:

| Strategy | Resolution Chain | Best Used For... |
| --- | --- | --- |
| **`a`** | `LNM Logbook ➔ LNM Cache ➔ FG Live Log ➔ Null` | Pilots tracking airframe positions primarily inside Little Navmap. |
| **`b`** *(Default)* | `FG Live Log ➔ LNM Logbook ➔ LNM Cache ➔ Null` | Mixed/pure FlightGear users; pulls live data directly from active sim logs. |
| **`c`** | `Null Reset (Always Blank)` | A clean slate; completely disables automated history tracking. |

#### Ingestion Sources Breakdown:

* **FG Live Log (`fgfs.log`):** Scrapes the `updateClosestAirport:` engine state to spawn you exactly where you last shut down or parked.
* **LNM Logbook (`little_navmap_logbook.sqlite`):** Queries the SQL database for your last recorded landing destination (excellent for tracking unlogged diversions).
* **LNM Cache (`little_navmap.lnmpln`):** Intercepts your active session if Little Navmap was closed with an unsaved plan (marked with an asterisk `*`). *Note: This temporary cache is deleted automatically by LNM when you explicitly save a plan.*
* **Null Fallback & FlightGear Guard:** If tracking returns nothing (or Strategy `c` is selected), Little Navmap safely generates empty waypoint tags. However, **FlightGear automatically falls back to your configured `HOME_ICAO**` to protect the simulator's routing engine from failing or defaulting to KSFO.
---

## 📖 Command Reference

> 💡 **Tip:** You can view the quick-reference guide directly in your terminal at any time by running `flight -h` or `flight --help`.

### Dispatch & Route Selection

| Directive | Action |
| --- | --- |
| `flight` | Spawn a local dispatch briefing; may show **no destination** when producing base/pattern work at `HOME_ICAO`. |
| `flight <ICAO>` | Generates a fixed route dispatch to a targeted airfield. |
| `flight <PREFIX>` | Selects a random destination matching a 2-letter country prefix code (e.g., `LG`). |
| `flight -n`, `--next <PREFIX>` | Dispatches a random **UNVISITED** airport code matching the country code to avoid tracking repetitions. |

### Advanced Career & System Controls

| Flag / Command | Action |
| --- | --- |
| `VEHICLE_TIER=<TIER> flight [args]` | Dynamically hot-swaps the active aircraft profile layout on the fly for a single dispatch without altering `flight.conf` records. |
| `flight -j <path>` | Ingests an external flight path file—supporting both FlightGear (`.fgfp`) and Little Navmap (`.lnmpln`) extensions—to initiate an active multi-stage **Journey**. |
| `flight -j` | Advances routing metrics to compile the next sequential leg of an imported journey. |
| `flight -j --reset` | Restarts the currently loaded active journey back to the first leg. |
| `flight -c <path.csv>` | Loads a dedicated custom **Target Deck** spreadsheet. Once active, **all routing selection bounds (random and non-repeat `-n` choices) are strictly isolated to this file**. |
| `flight -c --reset` | Deactivates the active Target Deck filter by completely removing `destinations.csv` from the engine environment, restoring unrestricted worldwide random routing options. |
| `flight -f`, `--files` | Displays regional percentage metrics and opens an interactive sub-shell directly inside your cache tracking workspace (`~/.cache/flight_dispatch`). Type `exit` to return. |
| `flight -e <PREFIX>` | Automatically opens a targeted geographic log record under your defined shell `$EDITOR`. |
| `flight --reset` | **WARNING**: Clears history cache blocks, completely wiping lifetime logbooks and completion states. |

---

## 🗺️ Creating Long-Distance Journeys (`-j`)

When preparing long-range, multi-leg expedition plans (such as cross-continental tours), the dispatch engine dynamically parses native flight planning layout tracks. The system fully supports two primary simulation flight plan standards: **FlightGear (`.fgfp`)** layouts and **Little Navmap (`.lnmpln`)** exports.

### Flight Plan Design Guidelines

* **Airport-Only Node Rule:** Ensure your macro-flight plan file contains **only physical airports** as your primary waypoint legs.
* **Avoid Waypoint Clutter:** Do not export micro-routing data, low-altitude intersections, or VOR fixes directly into your main journey file. The script parses every identifier sequentially.
* **Flight Day Workflow:** Treat each leg generated by the dispatch engine as a separate flight. On flight day, you can build a high-fidelity, tactical flight plan featuring local vectors and intermediate navigation waypoints directly inside FlightGear.
* **Automatic Deduplication:** The script automatically handles consecutive identical waypoints (such as origin/departure airport duplicates generated by flight planners) to prevent tracking loops.

---

### ⚖️ Technical Constraints & Fixed Journey Parameters
When an active journey is initialized via the `-j` pipeline, the dispatch core freezes structural payload mechanics to mimic a continuous, unified career tour:

* **Constant Passenger & Spatial Caps:** Unlike standalone random flights where row configurations shift, your passenger seating capacities, zone weights, and cabin labels (`pax1_label`, `pax2_label`, `pax3_label`) are held completely uniform across every single leg of the journey. They are dictated strictly by your baseline selection inside `flight_tiers.conf`.
* **Configurable Journey Zones:** While the standard platform configuration presets evaluate up to 3 distinct sequential narrative stages (`journey_zones=3`), users are free to define a lower count inside their tier blocks if they prefer shorter structural phases.
* **Static Logistical Cargo Arrays:** The engine parses your space-separated string configuration value (e.g., `137 177 126` for small platforms, or `1940 2910 3870` for medium airliners) and converts it natively into an isolated bash index array via a strict internal `read -r -a` redirection pass. If a user reduces the zone count, the engine maps stage payloads directly to the corresponding numeric index values defined inside this configuration line. These values remain invariant from your initial departure point to the final tour destination.

---

### The Three Loading Methods

You can spin up an expedition track using any of these three workflows:

1. **FlightGear Format:** Load an exported FlightGear plan natively:
```bash
./flight.sh -j path/to/plan.fgfp

```

2. **Little Navmap Format:** Load an exported Little Navmap plan directly without converting it:

```bash
./flight.sh -j path/to/plan.lnmpln

```

3. **Scratchpad Method (Manual Hand-Coding):** If you don't want to use a flight planner at all, you can construct a journey line-by-line using raw text. Run the storage shell utility, open or create the journey file in your favorite editor, and type a simple list of ICAO codes (one per line):

```bash
./flight.sh -f
# This drops you into the secure cache directory. From here, just run:
nano journey_log.txt

```

*Note: If you intentionally need back-and-forth legs or circle-routing between identical fields, creating or modifying the text sequence directly inside `journey_log.txt` via this method is the best way to bypass the dynamic auto-deduplication engine.*

---

### 🛩️ FlightGear Companion Tools & Integrations

If you fly within FlightGear and want to enhance or safeguard your flight environment, review these dedicated configurations:

* **Live Tracking Bridge**: Sync real-time telemetry, map nodes, and interactive position briefings dynamically between your flight simulator and tracking software.
👉 **[FlightGear ↔ LittleNavMap Navigation Bridge Setup Guide](https://github.com/jimishol/bingo-flight/blob/main/FlightGear_LittleNavMap_Bridge_Setup.md)**
* **Copilot Pillow Add-on**: A lightweight, high-altitude safety watchdog built in Nasal for steady long-haul cruise phases. It monitors Calibrated Airspeed ($V_{cal}$) and automatically triggers FlightGear's native pause to protect your airframe from a catastrophic stall spin if atmospheric changes shift while you are away from the desk.
👉 **[Copilot Pillow Add-on Documentation](https://github.com/jimishol/bingo-flight/blob/main/flightgear_pillow_addon/README.md)**

---

## 🎯 Creating Custom Target Decks (`-c`)

When you want to restrict random flight options or route calculations exclusively to a specific group of airfields, you can feed the engine a custom CSV database.

### Structure Rules

Unlike standard plaintext logs, custom decks **must have a valid tabular layout header** defined on the first line. The script filters data dynamically using the structural column key `Ident`.

#### Format Example (Tabular Data layout):

```text
Distance NM;Heading °T;Ident;ICAO;FAA;IATA;Local Code;Name;City;State or Province;Country or Area Code;Rating;Elev. ft;Mag. Decl.°;Tower MHz;Largest Ramp;Largest Gate;Longest Runway Length ft;Scenery Paths;Files;Longitude;Latitude
0,0;0;LGAX;;;;;Alexandria;;;EUR;★−−−−;27;5,3E;132,770;;;5.906;;;22,49283409;40,64633179
23;109;LGTS;;;;;Makedonia;;;EUR;★−−−−;22;5,3E;118,050;;;7.907;;;22,97091675;40,51972198

```

#### Format Example (Simple Layout):

A clean, minimalist layout containing only the identification column key (valid real-world ICAOs only):
```text
Ident
LGHI
LGIR
LIML
```

### Little Navmap Export Workflow

The easiest way to generate a flawless target deck matching this structural specification is through your flight planner:

1. Open **Little Navmap** and open the Search or Airport filtering view.
2. Filter the map down to your targeted operational boundary (e.g., specific runways, military fields, or regional zones).
3. Select and copy the filtered table elements directly to your clipboard.
4. Paste the raw table contents directly into an empty file named `my_deck.csv` and inject it:

```bash
./flight.sh -c path/to/my_deck.csv

```
---

### 🚫 Exclude Missing or Unwanted Airports
If your specific simulator (such as FlightGear) is missing certain airfields, or if you simply want to permanently ignore specific locations, you can use `excluded_airports.txt` file in the root directory next to `flight.sh`.

List the ICAO codes you want to ban, one per line (you can use `#` for comments):

```text
# Excluded because they do not exist in my simulator
LG12
LG01

# Permanently ignored
ZXYZ
```

**How it works:**
* **Instant Auto-Sync:** The moment you create or update this file, the dispatch engine hashes the change and instantly rebuilds your local dictionary.
* **Metric Correction:** Excluded airports are immediately wiped from your regional progress percentages (`flight -f`), random dispatch pools (`flight -n`), and custom target card decks. 
* **Smart Detection:** If you manually request an excluded airport (e.g., `flight LG12`), the system smartly skips the internet search and explicitly flags it in the briefing as an intentionally ignored destination.

---

## 📂 Data Structure & Narrative Nodes

You can effortlessly broaden the narrative variety of your flight proposals by populating localized file matrix paths.

**Context File Paths:**
`stories/[LANG]/[TIER]/pax[COUNT]__bag[CLASS].txt`

* `[LANG]`: Target language layout code (e.g., `en`, `el`).
* `[TIER]`: Aircraft complexity classification (e.g., `helicopter`, `small_airplane`).
* `[COUNT]`: Total passenger capacity tier (e.g., `0`, `2`).
* `[CLASS]`: Weight capacity category matching tier limits (`light`, `medium`, or `heavy`).

### Custom Narrative & Story Variants
When structuring or translating your story text assets inside the `stories/` directory, the engine applies explicit routing logic:

* **Standard Mode Randomization:** For regular dispatches, files can contain **multiple non-empty lines** acting as variant strings. The engine dynamically selects one random variant using an internal terminal randomizer to provide fresh, contextual immersion on repetitive runs.
* **Journey Mode Determinism:** When tracking a long-distance active journey (`-j`), the loader automatically intercepts the request to prioritize `journey.txt` instead of passenger variants, processing only the **first non-empty line** deterministically.
* **Automated Failure Fallbacks:** If a configured localization directory or target text module is entirely absent or structurally empty, the engine gracefully catches the error and drops back to the standard English profile (`stories/en/...`) to protect execution states.

**Example Node Asset:**
If a standard dispatch rolls 0 passengers alongside heavy cargo space allocation, the file engine pulls a random line option from `stories/en/small_airplane/pax0__bagheavy.txt`:
> *"Critical equipment transport. Loading heavy crates with generator spare parts and technical documents."*

### 🖥️ Structural UI Localization (`interface.txt`)
While story files provide narrative context for individual flight variants, global UI indicators, interactive gate text prompts, and systems error strings are driven by an isolated interface lookup module.

* **Baseline Rule:** The engine strictly requires an explicit global fallback source of truth to be present at `stories/en/interface.txt`.
* **Regional Overrides:** Inside any custom directory layout (e.g., `stories/el/`), you can supply a localized `interface.txt` mapping text variants onto core context identifiers:
  ```ini
  lbl_proposal=DISPATCH PROPOSAL
  lbl_confirm_prompt=Are you in the mood to fly there today? Should I file the flight destination? (y/N): 
  lbl_err_non_repeat_2=All flyable airfields under your current operational criteria have been visited!

  ```

* **Strict Key Sanitization:** The native UI asset parser strips potential UTF-8 Byte Order Marks (BOM), discards surrounding literal double quotes, and discards all spaces or illegal symbols in line keys. It assigns elements globally using a safe printf -v routine matching regex pattern keys [A-Za-z0-9_].

## 🔄 The Translation & Master Blueprint Pipeline

To make handling localization content simpler, the repository uses a companion script, `blueprint_sync.sh`, at the root level as a centralized CLI engine to orchestrate, compile, and expand multi-variant story structures across localizations (`stories/<lang>/<tier>`). This script allows you to manage translation text strings inside a single master document (`blueprint.txt`) instead of manually tracking dozens of tiny separated text segment files.

### Compilation Mechanics

1. **Clone & Compile New Translation Base**
```bash
./blueprint_sync.sh clone <from_lang> <tier> <to_lang>

```

* *Example:* `./blueprint_sync.sh clone el small_airplane fr`
* *Behavior:* Automatically ingests the flat source variants from your source language directory and compiles them into a single unified `blueprint.txt` template inside your newly spawned target directory.
* *Safety Gate:* If the target folder already exists and contains files, the engine will explicitly **abort** to prevent accidental asset overrides.

2. **Expand Master Blueprint into Flat Files**

```bash
./blueprint_sync.sh expand <lang> <tier>

```

* *Example:* `./blueprint_sync.sh expand fr small_airplane`
* *Behavior:* Explodes a single unified translation `blueprint.txt` template back into its 13 individual structural flat text fragments (pax/bag combinations and journey profiles).
* *Safety Gate (Strict Gating):* The engine will strictly **abort** if any other files or directories exist within that targeted workspace to protect your local configurations from corruption.
* *Post-Processing Cleanup:* Following a successful compilation pass, the original staging file `blueprint.txt` is completely redundant and can be safely deleted or wiped from the directory workspace to maintain a clean directory state.

### Rules for Translation Modifications

* Every narrative line inside a `[filename.txt]` component block in the blueprint must strictly reside on a **single line per variant**.
* Do not introduce arbitrary newlines inside variants, as the parser uses native `while read` iterations to register unique strings sequentially.
* The local generated blueprint build structures (`/blueprint.txt`) are untracked globally by `.gitignore` to maintain an atomic staging area.
* Inside `stories/<lang>/` can exist an optional `interface.txt` acting as a translation override of the default baseline `stories/en/interface.txt` (which must always exist as the core source of truth).

---

## 📄 License

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.**

This program is distributed in the hope that it will be useful, but **WITHOUT ANY WARRANTY**; without even the implied warranty of **MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE**. See the [LICENSE](LICENSE) file for comprehensive operational constraints and permissions.
