# 🛩️ FlightGear ↔ LittleNavMap Bridge Setup (FGconnect Quickstart)

An integrated companion pipeline linking live FlightGear simulation telemetry directly to your LittleNavMap tracking suite. This layout uses a real-time data bridge to sync aircraft coordinates, flight plans, and geographic positioning nodes across systems automatically.

---

## 📋 1. Prerequisites & Tool Acquisition

Download and prepare the following packages into your designated applications workspace:

* **LittleNavMap (Core Engine)**: Download the latest official Linux archive from the release repository:  
  [https://github.com/albar965/littlenavmap](https://github.com/albar965/littlenavmap)
* **FlightGear LittleNavMap Add-on**: Tracks native protocol links. Clone the connector extension directly from the developer source:  
  [https://github.com/slawekmikula/flightgear-addon-littlenavmap](https://github.com/slawekmikula/flightgear-addon-littlenavmap)
* **FGconnect (Live Telemetry Server)**: Ingests raw multi-threaded loop feeds. Clone the controller directly from the repository source:  
  [https://github.com/Em-Ant/fgconnect](https://github.com/Em-Ant/fgconnect)

### System Dependencies
Ensure your Python execution environment contains the required XML structure parser:
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

---

## 🚀 3. Network Connection Matrix (FGconnect Server)

Launch your telemetry utility via terminal or script workspace:

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

To streamline your simulation pre-flight pipeline, you can group the telemetry bridge and mapping applications into a single execution utility.

### Automation Script (`fgnav.sh`)

Create an uncoupled shell utility to automate launcher processes safely, adapting directory path variables to match your personal installation workspace layout:

```bash
#!/bin/bash
# fgnav.sh - Companion Suite Orchestration Script

# 1. Spawn FGconnect server in the background
cd "$HOME/games/git/fgconnect" || exit 1
python3 gui_tk.py &
sleep 1

# Optional: Window manager rules (e.g., Hyprland workspace pinning)
# hyprctl dispatch movetoworkspacesilent special:magic

# 2. Open Little Navmap in the foreground (blocking execution thread)
cd "$HOME/games/flightgear-navigation_tools/LittleNavmap-linux-ubuntu-24.04-3.0.18" || exit 1
./littlenavmap "$HOME/.cache/flight_dispatch/briefing.lnmpln"

# 3. Clean up telemetry hooks automatically upon map exit
pkill -f gui_tk.py

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
