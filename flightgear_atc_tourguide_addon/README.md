# TourGuide Add-on for FlightGear

**TourGuide** is a lightweight, spatial-aware flight announcement add-on for FlightGear. It queries FlightGear's global Point of Interest (POI) database (cities, towns, villages, and Visual Reporting Points) to deliver real-time, sector-based landmark orientation via on-screen ATC messages and text-to-speech engines.

---

## Features

* 🧭 **Sector-Aware Spatial Orientation:** Categorizes landmarks into **Ahead**, **Left**, **Right**, **Behind**, and **Directly Below** relative to your aircraft heading.
* 🏢 **Hierarchy & Multi-Landmark Synthesis:** Generates intelligent compound announcements when multiple landmarks fall within a sector (e.g., *"Ahead: Approaching SmallTown towards BigCity, 12.5 nm"*).
* ⛰️ **Dynamic Overhead (Directly Below) Zone:** Calculates an altitude-dependent ground cone (AGL-based) to announce landmarks directly beneath the aircraft.
* ⚡ **High-Performance Querying:** Utilizes a lightweight bounding-box pre-filter to process thousands of global landmarks without frame drops.
* 🎛️ **Fully Configurable Ranges & Multipliers:** Scale detection ranges based on landmark type (e.g., major cities detected further away than small villages, with boosted 1.5× range for Visual Reporting Points).
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
   Left Sector        \     aircraft /         Right Sector
   (r_aside*mult)      |      ✈     |         (r_aside*mult)
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
| **City** | `city` (`12`) | **2.0×** | 36.0 NM |
| **Visual Reporting Point (VRP)** | `visual-reporting-point` (`1000`) | **1.5×** | 27.0 NM |
| **Town** | `town` (`13`) | **1.0×** | 18.0 NM |
| **Village** | `village` (`14`) | **0.5×** | 9.0 NM |

> **Note on Custom VRPs:** Standard FlightGear `poi.dat` datasets omit type `1000`. If you import custom Visual Reporting Points into `FlightGear/NavData_Override`, TourGuide applies a boosted 1.5× multiplier to ensure reporting waypoints stand out during VFR flights.

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

### Example ATC Messages

* **Ahead:** `Ahead: Approaching Concord, 14.2 nm`
* **Compound Ahead:** `Ahead: Approaching Lexington towards Boston, 8.5 nm`
* **Sides:** `On your left: Cambridge and farther Boston, 6.2 nm`
* **Directly Below:** `Directly below: Hansfield Airport, 0.4 nm`
* **Behind:** `Behind: Just passed Bedford, 3.1 nm`

---

## Configuration Reference

Custom options are set in `addon-config.xml`.

> ⚠️ **Important:** Properties are loaded on initial startup and are **not updated at runtime**. You must **relaunch FlightGear (`fgfs`)** for modified configuration values to take effect.

| Setting | Default | Description |
| --- | --- | --- |
| `auto-interval-sec` | `900.0` | Flight-time interval in seconds for auto announcements (`0` disables). |
| `speech-queue-interval-sec` | `5.0` | Delay in seconds between consecutive sector lines in the ATC queue. |
| `trigger-key-code` | `96` | ASCII code for manual announcement key (default: backtick ```). |
| `range-ahead-nm` / `aside` / `behind` | `18.0` / `9.0` / `6.0` | Base sector search radii (NM) before type multipliers are applied. |
| `ahead-angle-deg` | `45` | Ahead sector half-angle (±22.5° off aircraft nose). |
| `mult-city` / `vrp` / `town` / `village` | `2.0` / `1.5` / `1.0` / `0.5` | Type multipliers applied to base ranges across all sectors. |
| `agl-under-multiplier` | `2.0` | Scaling factor applied to AGL altitude for the "Directly Below" zone. |
| `exclude-types` | `"10,1001"` | Comma-separated list of POI type names or `poi.dat` numeric IDs to ignore. |
| `chunk-size` | `24000` | POIs processed per frame chunk (~800k total). Higher reduces response delay; lower prevents frame lag. |

---

## Requirements

* **FlightGear:** v2020.3.0 or higher
* **License:** GNU General Public License v3.0 (GPL-3.0)
* **Author:** Dimitrios Cholidis
