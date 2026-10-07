# TourGuide Add-on for FlightGear

**TourGuide** is a lightweight, spatial-aware flight announcement add-on for FlightGear. It queries FlightGear's global Point of Interest (POI) database (cities, towns, villages, and Visual Reporting Points) to deliver real-time, sector-based landmark orientation via on-screen ATC messages and text-to-speech engines.

---

## Features

* 🧭 **8-Sector Spatial Orientation:** Categorizes landmarks into **8 directional sectors** (**Ahead**, **Front Right**, **Right**, **Back Right**, **Behind**, **Back Left**, **Left**, **Front Left**) plus **1 Overhead Zone** (**Directly Below**), emitting non-blocking combined announcements across all active sectors.
* 🚦 **Output Density Capping (`max-directional-lines`):** Priorities are assigned by closest distance, capping directional callouts (default: 4 lines) so ATC message queues stay concise in dense landmark regions without suppressing the reserved overhead slot.
* 🏢 **Hierarchy & Multi-Landmark Synthesis:** Generates intelligent compound announcements when multiple landmarks fall within a sector (e.g., *"Ahead: Approaching SmallTown (8.5 nm) towards BigCity (18.2 nm)"*).
* 🛡️ **Smart VRP Fallback Isolation:** Custom Visual Reporting Points (VRPs) and islands are dynamically isolated—showing only when no higher-priority non-VRP landmarks are present in that local sector.
* ⛰️ **Dynamic Overhead (Directly Below) Zone:** Calculates an altitude-dependent ground cone (AGL-based) to announce landmarks directly beneath the aircraft without suppressing directional announcements.
* ⚡ **Non-Blocking Chunked Querying:** Processes thousands of global landmarks in lightweight frame chunks (`chunk-size`), preventing frame drops during background spatial searches.
* 🎛️ **Fully Configurable Ranges & Multipliers:** Scale detection ranges based on landmark type, with configurable priority multipliers.
* ⏱️ **Flight-Time Auto Announcements & Hotkeys:** Receive periodic tour updates at custom flight-time intervals or trigger an instant update at any time with a single hotkey.
* 🧹 **Text Sanitization:** Automatic ASCII filtering ensures clean rendering on ATC dialogs and seamless pronunciation with Text-To-Speech (TTS) synthesizer engines.

---

## Sector & Detection Logic

Landmarks are grouped into **8 directional horizontal sectors** centered around the aircraft's track plus **1 overhead zone**, allowing a theoretical maximum output of **8 + 1 distinct announcement lines** per scan:

```text
                        \     Ahead     /
   Front Left            \   (±alpha)  /            Front Right
   (r_aside * mult)       \           /        (r_aside * mult)
                           \         /
   Left --------------------✈ aircraft -------------------- Right
   (r_aside * mult)        / Directly\        (r_aside * mult)
                          /   Below   \
   Back Left             / (r_under)   \            Back Right
   (r_aside * mult)     /               \     (r_aside * mult)
                       /     Behind      \
                      / (r_behind * mult) \

```

### Alpha Angle (α) & Sector Tuning

The angular span of each sector is governed by the sector half-angle parameter `sector-half-angle-deg` (α):

* **Default Uniform 8-Sector Layout (α = 22.5°):** Divides the 360° horizon into 8 perfectly equal 45° sectors. Each of the 4 cardinal sectors covers 2 * α = 45°, and each of the 4 off-side sectors covers 90° - 2 * α = 45°.
* **Deviating Toward 45.0° (Narrows Off-Side Sectors):** Increasing α expands cardinal sectors up to 90° while narrowing off-side sectors (90° - 2 * α). At α = 45.0°, off-side sectors shrink to 0°, collapsing the system into a strict 4-cardinal sector layout.
* **Deviating Toward 0.0° (Narrows Cardinal Sectors):** Decreasing α expands off-side sectors up to 90° while narrowing cardinal sectors (2 * α). At α = 0.0°, cardinal sectors shrink to 0°, collapsing the system into a 4-diagonal off-side sector layout.
* **Output Line Reduction:** Any deviation away from 22.5° narrows four of the eight directional sectors, naturally lowering the likelihood of landmarks landing in those sectors and reducing output lines alongside the hard `max-directional-lines` cap.

### Base Detection Ranges & Multipliers

| Landmark Type | Internal Type ID | Default Range Multiplier | Effective Ahead Range |
| --- | --- | --- | --- |
| **Visual Reporting Point (VRP)** | `visual-reporting-point` (`1000`) | **1.3x** | 20.8 NM |
| **City** | `city` (`12`) | **1.0x** | 16.0 NM |
| **Town** | `town` (`13`) | **0.7x** | 11.2 NM |
| **Village** | `village` (`14`) | **0.35x** | 5.6 NM |

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

* **Generating Custom POI Files:** To extract and build custom Type `1000` island databases from GeoNames datasets, see our included utility guide in [docs/poi_data/readme.md](https://github.com/jimishol/bingo-flight/blob/main/docs/poi_data/readme.md).

---

## Installation

1. Copy or link the `flightgear_atc_tourguide_addon` directory into your FlightGear Add-ons folder.
2. Create your local active configuration file from the example:

```bash
cp flightgear_atc_tourguide_addon/addon-config.xml_example flightgear_atc_tourguide_addon/addon-config.xml

```

3. Enable the add-on via the FlightGear launcher or in-game Add-ons menu.

---

## Usage

### Hotkey Activation

Press the **Backtick key** (```) at any time during flight to trigger an immediate landmark announcement across all sectors.

### Automatic Mode

By default, TourGuide automatically announces nearby landmarks every **15 minutes (900 flight-time seconds)**.

---

## Configuration Reference

Custom options are set in `addon-config.xml`.

> ℹ️ **Note on Runtime Updates:** Modifying `addon-config.xml` on disk requires restarting FlightGear. However, scan limits, ranges, angles, multipliers, and filters can be adjusted live in-game without restarting via **Debug → Browse Property Tree** under `/addons/by-id/com.cholidis.flightgear.tourguide/`.

| Setting | Default | Description |
| --- | --- | --- |
| `auto-interval-sec` | `900.0` | Flight-time interval in seconds for auto announcements (`0` disables). *(Requires restart)* |
| `speech-queue-interval-sec` | `5.0` | Delay in seconds between consecutive spoken/ATC sector messages. *(Requires restart)* |
| `trigger-key-code` | `96` | ASCII code for manual announcement key (default: backtick ```) (`0` or `nil` disables). *(Requires restart)* |
| `max-directional-lines` | `4` | Maximum directional sectors spoken per scan (1 to 8; excluding +1 "Directly below" slot). Sectors with closest landmarks take priority. |
| `range-ahead-nm` / `aside` / `behind` | `16.0` / `8.0` / `4.0` | Base sector search radii (NM) before type multipliers are applied. |
| `sector-half-angle-deg` | `22.5` | Sector half-angle (α) in degrees. At 22.5°, all 8 sectors are 45° wide. Deviating toward 0° or 45° shrinks 4 sectors. |
| `mult-city` / `town` / `village` / `vrp` | `1.0` / `0.7` / `0.35` / `1.3` | Type multipliers applied to base ranges across all sectors. |
| `isolate-vrp-fallback` | `true` | If true, VRPs/islands only show when no non-VRP landmark exists in that sector. |
| `agl-under-multiplier` | `2.0` | Scaling factor applied to AGL altitude for the "Directly Below" zone. |
| `exclude-types` | `"10,1001"` | Comma-separated list of POI type names or `poi.dat` numeric IDs to ignore (e.g., 10=Country, 1001=Waypoint). |
| `chunk-size` | `24000` | POIs evaluated per frame chunk (~800k total). Higher reduces response delay; lower prevents frame lag. |

---

## Requirements

* **FlightGear:** v2020.3.0 or higher
* **License:** GNU General Public License v3.0 (GPL-3.0)
* **Author:** Dimitrios Cholidis
