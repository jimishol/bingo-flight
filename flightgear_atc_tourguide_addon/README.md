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
                  \   Ahead (+/-22.5°)   /
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

You can customize detection ranges, sector angles, keys, and exclusions by editing `config.xml` inside the add-on folder or overriding properties in FlightGear.

```xml
<PropertyList>
  <addons>
    <by-id>
      <com.cholidis.flightgear.tourguide>
        <!-- Periodic announcement interval in flight seconds (0 to disable) -->
        <auto-interval-sec type="double">900.0</auto-interval-sec>

        <!-- Delay (seconds) between sequential message output lines -->
        <speech-queue-interval-sec type="double">5.0</speech-queue-interval-sec>

        <!-- Keyboard Key Code to trigger announcement (96 = Backtick `) -->
        <trigger-key-code type="int">96</trigger-key-code>

        <!-- Base Sector Search Ranges (in Nautical Miles) -->
        <range-ahead-nm type="double">18.0</range-ahead-nm>
        <range-aside-nm type="double">9.0</range-aside-nm>
        <range-behind-nm type="double">6.0</range-behind-nm>

        <!-- Ahead Sector Half-Angle in degrees (+/- off aircraft nose) -->
        <ahead-angle-deg type="double">22.5</ahead-angle-deg>

        <!-- Landmark Type Range Multipliers -->
        <mult-city type="double">2.0</mult-city>
        <mult-town type="double">1.0</mult-town>
        <mult-village type="double">0.5</mult-village>
        <mult-vrp type="double">1.5</mult-vrp>

        <!-- AGL Multiplier for "Directly Below" Zone Radius -->
        <agl-under-multiplier type="double">2.0</agl-under-multiplier>

        <!-- Comma-separated list of POI Type Names or IDs to exclude -->
        <exclude-types type="string">10,1001</exclude-types>
      </com.cholidis.flightgear.tourguide>
    </by-id>
  </addons>
</PropertyList>

```

### Config Property Details

* **`auto-interval-sec`**: Interval for periodic automatic announcements (in simulated flight seconds). Set to `0` to disable automatic messages.
* **`trigger-key-code`**: ASCII key code for manual triggers (default `96` for backtick ```).
* **`exclude-types`**: Filter out unwanted POI types using string identifiers or `poi.dat` numeric codes (e.g., `10` = Country borders, `1001` = Navigational waypoints).

---

## Requirements

* **FlightGear:** v2020.3.0 or higher
* **License:** GNU General Public License v3.0 (GPL-3.0)
* **Author:** Dimitrios Cholidis
