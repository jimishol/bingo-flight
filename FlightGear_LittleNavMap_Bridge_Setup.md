# 🛩️ FlightGear ↔ LittleNavMap Bridge Setup (FGconnect Quickstart)

An integrated companion pipeline linking live FlightGear simulation telemetry directly to your LittleNavMap tracking suite. This layout uses a real-time data bridge to sync aircraft coordinates, flight plans, and geographic positioning nodes across systems automatically.

---

## 📋 1. Prerequisites & Tool Acquisition

Download and prepare the following packages into your designated applications workspace. 

* **LittleNavMap (Core Engine)**: Download the latest official Linux archive from the release repository:
  https://github.com/albar965/littlenavmap

* **FlightGear LittleNavMap Add-on**: Tracks native protocol links. Clone the official connector extension https://github.com/slawekmikula/flightgear-addon-littlenavmap:
  ```bash
  git clone https://github.com/slawekmikula/flightgear-addon-littlenavmap.git
  ```

* **FGconnect** (Live Telemetry Server): Ingests raw multi-threaded loop feeds.
    Clone the official controller https://github.com/Em-Ant/fgconnect:
  ```bash  
  git clone https://github.com/Em-Ant/fgconnect.git
  ```  

---

### System Dependencies

Ensure your Python execution environment contains the required XML structure
parser:

```bash
pip3 install xmltodict
```

---

## ⚙️ 2. Configure the FlightGear Simulator Add-on

Launch FlightGear, navigate to your top system menu bar, and open **Add-ons** ➡️ **Little Nav Map**. Apply the following network settings:

```ini
Enable export:   true
Refresh rate:    10
UDP host:        localhost
UDP port:        7755

```

> [!TIP]
> **Enhance Long-Haul Cruise Safety**
> Since you are already managing FlightGear add-ons for this tracking layout, consider enabling **Copilot Pillow** (located locally in this repository under `flightgear_pillow_addon/`).
> While this LittleNavMap bridge monitors your live path tracking, Copilot Pillow acts as a high-altitude safety watchdog—monitoring your Calibrated Airspeed (CAS) during long, real-time steady cruise legs and automatically pausing the simulator if changing weather frames threaten to stall your airframe while you are away from the desk.

---

## 🚀 3. Network Connection Matrix (FGconnect Server)

You can launch the telemetry utility using either the interactive graphical interface or a streamlined headless terminal switch.

### Option A: Standalone Mode (Headless)
For automation or scripted operation, you can run `fgconnect` without the GUI by using the standalone `-s` flag. If no other arguments are passed, it defaults to your local loop ports automatically:

```bash
python3 fgconnect.py -s

```

#### Advanced Argument Customization

If you need to override the default interfaces or tracking hooks, pass the explicit configuration flags:

```bash
python3 fgconnect.py -s --fgip 127.0.0.1 --fglnmpt 7755 --lnmip 127.0.0.1 --lnmpt 51968

```

**Default Network Map:**

* **FlightGear UDP (Telemetry Ingest):** `127.0.0.1:7755`
* **FlightGear HTTP (Web Server link):** `127.0.0.1:5400`
* **LittleNavMap (Output Broadcast):** `127.0.0.1:51968`

---

### Option B: Interactive GUI Window

If you prefer a visual window layout to track connections manually, launch the default interface helper:

```bash
cd path/to/fgconnect
python3 gui_tk.py

```

Inside the interactive **FGconnect GUI** window, match your local network interface ports precisely:

* **FlightGear Interface**: `IP: 127.0.0.1` | `Port: 7755`
* **LittleNavMap Interface**: `IP: 127.0.0.1` | `Port: 51968`

Click **Start** on both connections to initialize the real-time background socket loop.

---

## 🗺️ 4. Active Tracking inside LittleNavMap

1. Launch your main tracking software utility.
2. Navigate to the top options menu: **Tools** ➡️ **Connect to Flight Simulator**.
3. Select the **Remote/Network** protocol option, enter your localhost IP (`127.0.0.1`), set the Port to `51968`, and connect.

The system will automatically link your physical simulation coordinates, displaying live positioning updates directly on your custom flight plans and target maps!

---

## 🛠️ 5. Linux Automation Setup (Optional)

To streamline your simulation pre-flight pipeline, you can group the headless telemetry bridge and mapping applications into a single execution utility. By using the standalone background mode, you completely remove the need to manage background application windows or write custom tiling window manager rules (e.g., Hyprland pinning).

### Automation Script (`fgnav.sh`)

Create an uncoupled shell utility to automate launcher processes safely, adapting directory path variables to match your personal installation workspace layout:

```bash
#!/bin/bash
# fgnav.sh - Companion Suite Orchestration Script

# 1. Spawn FGconnect server in the background (Standalone headless mode)
cd "$HOME/games/git/fgconnect" || exit 1
# Using -s starts the telemetry hooks automatically without a GUI
python3 fgconnect.py -s &
sleep 1

# 2. Open Little Navmap in the foreground (blocking execution thread)
cd "$HOME/games/flightgear-navigation_tools/LittleNavmap-linux-ubuntu-24.04-3.0.18" || exit 1
./littlenavmap "$HOME/.cache/flight_dispatch/briefing.lnmpln"

# 3. Clean up telemetry hooks automatically upon map exit
# Kill the headless background script instead of a GUI window instance
pkill -f "fgconnect.py -s"
```

### System Launcher Entry (`fgnav.desktop`)

To pin the mapping suite cleanly to your system dashboard or application menus, build a standard desktop entry tracking your active script script path:

```ini
[Desktop Entry]
Type=Application
Name=FG Navigation Suite
Comment=Launch FlightGear telemetry bridge and LittleNavMap simultaneously
Exec=sh -c "$HOME/.local/share/applications/fgnav.sh"
Icon=airplane
Terminal=false
Categories=Game;Simulation;
```

---

## 🎭 6. Database Synchronization (Tricking LittleNavMap Scenery Loader)

Because LittleNavMap requires an X-Plane file ecosystem to unlock its native "Load Scenery Library" module, you can build a dummy directory architecture to link FlightGear's airfield layout and modern AIRAC parameters simultaneously.

### Step A: Initialize the Fake X-Plane Environment

Create a directory named `Fake_XPlane/` at a convenient location on your drive.

Next, configure the X-Plane path registry file so LittleNavMap knows where to look. Create a hidden folder named `.x-plane` inside your home directory and place an orchestration file named `x-plane_install_11.txt` inside it containing the path to your fake folder:

* **File Path:** `$HOME/.x-plane/x-plane_install_11.txt`
* **File Content:** `/path_to/Fake_XPlane/`

### Step B: Construct the Target Directory Tree

Build the precise internal folder framework inside your `Fake_XPlane/` directory:

```text
Fake_XPlane 🐧 tree -d
.
├── Custom Scenery
│   └── Global Airports
└── Resources
    ├── default data
    └── default scenery
        └── default apt dat
            └── Earth nav data

```

Inside the `Fake_XPlane/Custom Scenery/` folder, establish your scenery definition file:

```text
Fake_XPlane/Custom Scenery 🐧 tree
.
├── Global Airports
└── scenery_packs.ini

```

Create `scenery_packs.ini` with the following configuration contents:

```text
I
1000 Version
SCENERY

SCENERY_PACK Custom Scenery/Global Airports/

```

### Step C: Install AIRAC Navaids into LittleNavMap

Copy your modern X-Plane 11 formatted AIRAC database files directly into the `default data/` tree folder:

```text
/Fake_XPlane/Resources/default data 🐧 tree -L 1  
.
├── CIFP
├── cycle_info.txt
├── cycle.json
├── earth_awy.dat
├── earth_fix.dat
├── earth_hold.dat
├── earth_mora.dat
├── earth_msa.dat
├── earth_nav.dat
└── user_fix_georef.dat

```

### Step D: Install FlightGear's Airport Layouts into LittleNavMap

To synchronize airfield structures perfectly, move the core FlightGear airport data file into your fake directory tree:

1. Copy `/usr/share/flightgear/Airports/apt.dat.gz` into `Fake_XPlane/Resources/default scenery/default apt dat/Earth nav data/`
2. Open a terminal in that folder. You will see:
```text
apt.dat.gz

```

3. Extract the archive. Run this command to retain the original archive file as a visual reminder:
```bash
gunzip -k apt.dat.gz

```

*(Alternatively, run `gunzip apt.dat.gz` if you do not wish to keep the compressed file).*

---

## 📡 7. Instruct FlightGear to use AIRAC Frequencies

To map modern radio communication nodes and navigation vectors inside the simulator engine, inject modern AIRAC parameters directly into FlightGear's loading stack using our Python merger script.

The script automatically pulls stock runway layout data directly from your system installation (apt.dat.gz), cleans and sanitizes modern AIRAC entries from a user-provided nav_AIRAC.dat (correcting runway designations to match stock layouts), and deploys a hybrid nav.dat file directly into your override folder.

### Step 1: Set Up the Override Directory Structure

Ensure your custom FlightGear user download path has the `NavData_Override` folder initialized:

```text
Flightgear/NavData_Override 🐧 tree
.
└── NavData
    └── nav

```

### Step 2: Process and Deploy Modern AIRAC Data

1. Place your raw AIRAC navigation file (usually earth_nav.dat) inside `docs/nav_merged_ILS/` and rename it to **`nav_AIRAC.dat`**.
2. Run the deployment script:
```bash
python3 docs/nav_merged_ILS/merge_and_clean_nav.py

```


3. The script will decompress system base data in memory, reconcile runway numbering mismatches (e.g., modern `26R` mapped back to scenery `27R`), drop orphaned country codes, and output the cleaned, hybrid `nav.dat` directly to:
`/mnt/data/games/Flightgear/NavData_Override/NavData/nav/nav.dat`

---

### Activate the Override Path In-Sim

1. Launch the standard **`fgfs` launcher**.
2. Navigate to the **Add-ons** preference tab.
3. Locate the **Additional scenery folders** configuration panel.
4. Click **Add** and select your absolute override directory path: `/mnt/data/games/Flightgear/NavData_Override`

---

> [!NOTE]
> **Scenery Sync & ILS Restoration**
> Using raw, unedited AIRAC databases normally breaks ILS needles at legacy airports because modern AIRAC runway designators (e.g., `28C`) fail to match FlightGear's base scenery definitions (e.g., `28`).
> The automated Python workflow solves this by:
> * **Scanning modern AIRAC runways** against base scenery (`apt.dat.gz`) to find mismatching runway identifiers.
> * **Smart-matching and renaming** identifiers (stripping letters or shifting headings for magnetic drift) so ILS localizers and Glide Slopes lock onto active runways seamlessly.
> * **Preserving raw format alignments** so FlightGear's strict parser can read the override file cleanly without crashing.

## 8. Updating FlightGear’s METAR Capability List

FlightGear uses a file:

```
/usr/share/flightgear/Airports/metar.dat.gz
```

to decide which airports have METAR available.  
This file is old and contains airports that **no longer report METAR**, or whose **last METAR is days or months stale**, causing FlightGear to request non‑existent METAR files and blocking fallback to nearby stations.

The generator script:

```
docs/METAR_live_data/generate_metar_dat.py
```

downloads all 24 NOAA METAR cycle files and builds a **current list** of airports that truly report METAR today.  
The path to FlightGear’s METAR file is **configurable at the top of the script**:

```
FG_METAR_PATH = "/usr/share/flightgear/Airports/metar.dat.gz"
```

### How the script evaluates stations

The script checks all 24 METAR cycle files and counts how many times each ICAO appears.  
An airport is accepted **only if it appears in 12 or more cycles**:

```
FILTER_COUNT = 12
```

This “12‑cycle sweet spot” produces a **stable, low‑noise list** and filters out airports with intermittent or stale METAR.  
Although METAR availability changes minute‑to‑minute, **most changes occur at airports far outside the user’s usual flying region**, so updates are rarely needed.

### Logging

A log file (`metar_update.log`) can be created.  
Logging is **disabled by default**:

```
LOG_ENABLED = False
```

Users may enable logging **only for the first run** to obtain a persistent diff against FlightGear’s shipped list.  
After that, console output is sufficient to decide whether replacing `metar.dat.gz` is worthwhile.

### Typical usage

Most runs show additions or removals only for airports irrelevant to where the user normally flies.  
A “0 added / 0 removed” result is **possible but not common**.  
Users typically decline updating FlightGear’s file unless the changes are meaningful.

### FlightGear database rebuild

If you choose to replace `metar.dat.gz`, FlightGear **will rebuild its navigation databases** on the next startup.  
Since users usually decline updates, rebuilds happen **only when truly needed**.

### Running the update

```
python3 generate_metar_dat.py
```

If changes exist, the script asks:

```
Do you want to replace FlightGear's metar.dat.gz? [y/N]
```

Answer **y** only when the diff is relevant to your flying area.

### After FlightGear updates

FlightGear overwrites `metar.dat.gz` during updates, so rerun the script afterwards to restore the corrected METAR capability list.

### Command-line options & Shell Aliases

You can pass arguments to bypass interactive prompts:

* **`PREFIX` (e.g. `lg`, `eg`):** Auto-updates **only** if changes match a 2-letter ICAO region. If unaffected, it skips writing so FlightGear won't waste time rebuilding its database.
* **`-y`, `--yes`:** Auto-accepts all global updates.
* **`-h`, `--help`:** Shows usage instructions.

#### Automated launch alias vs. Direct launch

You can chain the updater directly to your launcher command using a region prefix:

```bash
# Add to ~/.bashrc or ~/.zshrc (using double quotes to expand $HOME)
fgfs-metar() {
    # -------------------------------------------------------------------------
    # CONFIGURATION
    # -------------------------------------------------------------------------
    # Set argument for generate_metar_dat.py ("lg", "eg", "-y", or "" for prompt)
    local METAR_ARG="lg"
    
    # Path to Little Navmap briefing cache
    CACHE="$HOME/.cache/flight_dispatch/briefing.lnmpln"
    # -------------------------------------------------------------------------

    DEP=""

    if [ -f "$CACHE" ]; then
        WAYPOINTS=$(sed -n '/<Waypoints>/,/\<\/Waypoints\>/p' "$CACHE" | grep "<Ident>" | sed 's/.*<Ident>\(.*\)<\/Ident>.*/\1/')
        DEP=$(echo "$WAYPOINTS" | head -n 1)
    fi

    if [ -n "$METAR_ARG" ]; then
        python3 "$HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/docs/METAR_live_data/generate_metar_dat.py" "$METAR_ARG"
    else
        python3 "$HOME/games/flightgear-navigation_tools/setup_related_files/bingo-flight/docs/METAR_live_data/generate_metar_dat.py"
    fi

    if [ -n "$DEP" ]; then
        exec fgfs --airport="$DEP" --flight-plan="$HOME/.cache/flight_dispatch/briefing.fgfp" --launcher
    else
        exec fgfs --launcher
    fi
}
```

**The Trade-off:**

* **Via Dispatch (`fgfs-metar`):**
* Automatically sets your departure airport directly from your Little Navmap briefing (.lnmpln) and loads the route from briefing.fgfp (whether auto-generated or exported from your edited .lnmpln), completely bypassing the launcher's built-in flight planner and manual airport selection. To prevent the launcher from overriding these settings, add empty --airport and --flight-plan entries in the Additional Settings section (and ignore the “No flight‑plan” warning in the Summary).
* Ensures your local METAR database is refreshed before flight, but adds a **~40-second network delay** during startup while fetching METAR cycles.


* **Direct Launch (`fgfs` / standard launcher):**
* Launches FlightGear instantly with zero startup delay.
* Requires manually setting your departure airport and route inside the launcher's flight planner, and requires running `generate_metar_dat.py` manually to update live weather data.
