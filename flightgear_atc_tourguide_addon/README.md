# TourGuide Add-on for FlightGear

**TourGuide** is a lightweight, spatial-aware flight announcement add-on for FlightGear. It queries FlightGear's global Point of Interest (POI) database (cities, towns, villages, and Visual Reporting Points) to deliver real-time, sector-based landmark orientation via on-screen ATC messages and text-to-speech engines.

---

## Features

* 🧭 **Multi-Sector Spatial Orientation:** Categorizes landmarks into **Ahead**, **Left**, **Right**, **Behind**, and **Directly Below**, emitting non-blocking combined announcements across all active sectors.
* 🏢 **Hierarchy & Multi-Landmark Synthesis:** Generates intelligent compound announcements when multiple landmarks fall within a sector (e.g., *"Ahead: Approaching SmallTown (8.5 nm) towards BigCity (18.2 nm)"*).
* 🛡️ **Smart VRP Fallback Isolation:** Custom Visual Reporting Points (VRPs) and islands are dynamically isolated—showing only when no populated settlements (cities, towns, villages) are present in that sector.
* ⛰️ **Dynamic Overhead (Directly Below) Zone:** Calculates an altitude-dependent ground cone (AGL-based) to announce landmarks directly beneath the aircraft without suppressing directional announcements.
* ⚡ **High-Performance Querying:** Utilizes a lightweight bounding-box pre-filter to process thousands of global landmarks without frame drops.
* 🎛️ **Fully Configurable Ranges & Multipliers:** Scale detection ranges based on landmark type, with boosted 2.0× priority range for Visual Reporting Points.
* ⏱️ **Flight-Time Auto Announcements & Hotkeys:** Receive periodic tour updates at custom flight-time intervals or trigger an instant update at any time with a single hotkey.
* 🧹 **Text Sanitization:** Automatic ASCII filtering ensures clean rendering on ATC dialogs and seamless pronunciation with Text-To-Speech (TTS) synthesizer engines.

---

## Sector & Detection Logic

Landmarks are grouped into 4 horizontal sectors off your nose heading, plus 1 overhead zone:

```
                  \   Ahead (+/-45°)   /
                   \                  /
                    \   r_ahead*mult /
                     \              /
   Left Sector        \   aircraft /         Right Sector
   (r_aside*mult)      |     ✈     |         (r_aside*mult)
                      /   r_under   \
                     /  (Directly    \
                    /     Below)      \
                   /                   \
                  /    Behind Sector    \
                      (r_behind*mult)

```

### Base Detection Ranges & Multipliers

| Landmark Type | Internal Type ID | Default Range Multiplier | Effective Ahead Range |
| --- | --- | --- | --- |
| **Visual Reporting Point (VRP)** | `visual-reporting-point` (`1000`) | **2.0×** | 32.0 NM |
| **City** | `city` (`12`) | **1.5×** | 24.0 NM |
| **Town** | `town` (`13`) | **1.0×** | 16.0 NM |
| **Village** | `village` (`14`) | **0.5×** | 8.0 NM |

---

## Custom VRPs & `NavData_Override` Integration

Standard FlightGear `poi.dat.gz` datasets omit Type `1000` records. TourGuide leverages custom `poi.dat` injection to deliver rich VFR reporting points and island landmarks without altering core simulator files.

Place your custom `poi.dat` file containing Type `1000` records inside your FlightGear `NavData_Override` folder:

```text
Flightgear/NavData_Override/
└── NavData/
    ├── nav/
    │   └── nav.dat       <-- AIRAC merged navigation data
    └── poi/
        └── poi.dat       <-- Custom Type 1000 VRP database

```

* **Generating Custom POI Files:** To extract and build custom Type `1000` island databases from GeoNames datasets, see our included utility guide in [https://github.com/jimishol/bingo-flight/blob/main/docs/poi_data/readme.md](https://github.com/jimishol/bingo-flight/blob/main/docs/poi_data/readme.md).

---

## Installation

1. Copy or link the `flightgear_atc_tourguide_addon` directory into your FlightGear Add-ons folder.
2. Enable the add-on via the FlightGear launcher or your in-game Add-on management menu.

---

## Usage

### Hotkey Activation

Press the **Backtick key** (```) at any time during flight to trigger an immediate landmark announcement across all sectors.

### Automatic Mode

By default, TourGuide automatically announces nearby landmarks every **15 minutes (900 flight-time seconds)**.

### Example ATC Queue Output

When multiple sectors have active landmarks, messages are delivered sequentially over ATC at configured queue intervals (default: 4.0s):

* `[ATC] Directly below: Chios Airport, 0.4 nm`
* `[ATC] Ahead: Approaching Nisis Chios (5.2 nm) towards Mytilene (21.4 nm)`
* `[ATC] On your left: Lagkada, 3.8 nm`
* `[ATC] On your right: Cesme, 7.1 nm`
* `[ATC] Behind: Just passed Karfas, 2.3 nm`

---

## Configuration Reference

Custom options are set in `addon-config.xml`.

> ⚠️ **Important:** Properties are loaded on initial startup and are **not updated at runtime**. You must **relaunch FlightGear (`fgfs`)** for modified configuration values to take effect.

| Setting | Default | Description |
| --- | --- | --- |
| `auto-interval-sec` | `900.0` | Flight-time interval in seconds for auto announcements (`0` disables). |
| `speech-queue-interval-sec` | `4.0` | Delay in seconds between consecutive sector lines in the ATC queue. |
| `trigger-key-code` | `96` | ASCII code for manual announcement key (default: backtick ```). |
| `range-ahead-nm` / `aside` / `behind` | `16.0` / `8.0` / `4.0` | Base sector search radii (NM) before type multipliers are applied. |
| `ahead-angle-deg` | `45` | Ahead sector half-angle (±22.5° off aircraft nose). |
| `mult-vrp` / `city` / `town` / `village` | `2.0` / `1.5` / `1.0` / `0.5` | Type multipliers applied to base ranges across all sectors. |
| `isolate-vrp-fallback` | `true` | If true, VRPs/islands only show when no city, town, or village is in range for that sector. |
| `agl-under-multiplier` | `2.0` | Scaling factor applied to AGL altitude for the "Directly Below" zone. |
| `exclude-types` | `"10,1001"` | Comma-separated list of POI type names or `poi.dat` numeric IDs to ignore (e.g., 10=Country, 1001=Waypoint). |
| `chunk-size` | `24000` | POIs processed per frame chunk (~800k total). Higher reduces response delay; lower prevents frame lag. |

---

## Requirements

* **FlightGear:** v2020.3.0 or higher
* **License:** GNU General Public License v3.0 (GPL-3.0)
* **Author:** Dimitrios Cholidis
