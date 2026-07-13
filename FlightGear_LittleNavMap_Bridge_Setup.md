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

> [!IMPORTANT]
> **FGconnect Upstream Status**
>
> The FlightGear LittleNavMap add‑on is fully updated upstream, but **FGconnect upstream `main` is still missing several required fixes**.  
> Until these are merged, users **must use the patched `combined-fixes` branch** to avoid incorrect aircraft positioning (e.g., appearing in the wrong airport).
>
> https://github.com/jimishol/fgconnect/tree/combined-fixes
>
> The patched FGconnect includes:
> - corrected ground/air status  
> - updated model path  
> - safe flightplan extraction  
> - multiplayer & carrier detection  
> - ghost ID filtering  
> - universal fuel telemetry  
>
> **Clone the patched FGconnect:**
> ```bash
> git clone -b combined-fixes https://github.com/jimishol/fgconnect.git
> ```

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

To map the exact same radio communication nodes and navigation vectors inside the simulator engine, inject the matching AIRAC parameters into FlightGear's loading stack.

Navigate inside your custom user download directory (`--download-dir=/path_to/Flightgear`) and initialize an override path:

```text
Flightgear/NavData_Override 🐧 tree
.
└── NavData
    └── nav

```

1. Extract or copy the `earth_nav.dat` text file from your active AIRAC database.
2. Drop it directly into your newly created `nav/` folder.
3. Rename the file explicitly to lowercase: **`nav.dat`**

### Active the Override Path in-sim

1. Launch the standard **`fgfs` launcher**.
2. Go directly to the **Add-ons** preference tab.
3. Locate the **Additional scenery folders** configurations panel.
4. Click **Add** and link the absolute directory path pointing to your folder: `Flightgear/NavData_Override`
