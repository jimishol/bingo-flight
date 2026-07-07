# Copilot Pillow (FlightGear Add-on)

An automated high-altitude safety watchdog built for long-haul cruise monitoring.

## What it does
Copilot Pillow was born out of a desire for a realistic safety net during long, real-time cruise flights. During a 90-minute cruise phase with navigation enabled—where the engine was leaned out to maximum EGT (Exhaust Gas Temperature) to stretch fuel range—unpredicted atmospheric changes across shifting weather tiles caused the aircraft to bleed speed, stall, and enter a flat spin while the pilot was away from the desk.

Since pausing the simulator manually or using time compression takes away from the experience of a continuous, real-time flight, Copilot Pillow provides a clever workaround. It acts as your automated virtual copilot during steady, long-haul high-altitude cruise phases. 

If you step away from the controls and the aircraft drops below your safe airspeed limit while remaining at your high cruise altitude, the add-on instantly triggers FlightGear's native **Pause** state. This safely freezes the simulation mid-air, preventing a catastrophic stall spin and giving you complete peace of mind during hours of continuous, uncompressed flight.

## How it Works
- **Altitude Target Threshold**: This target exists solely to restrict protection when you are cruising at low altitudes (such as takeoff, climb, or approach) where you are actively handling the controls and don't want the watchdog interfering.
- **Speed Target Threshold**: This should be set with a safe margin above your actual stall speed to give the watchdog time to react and pause the simulator *before* a true aerodynamic stall develops.
- **Auto-Disable Safeguard**: When a protection pause is triggered, the addon automatically disables itself. When you return to your desk, you can simply press **"p"** to unpause and recover the aircraft. If you plan to step away a second time, you must manually toggle Copilot Pillow back on.

## Features
- **High-Altitude Stall Prevention**: Actively monitors Live AGL (Above Ground Level) altitude and Calibrated Airspeed (CAS via `/velocities/airspeed-kt`) during cruise.
- **Resource Efficient**: Built using modern, object-oriented `maketimer` loops to prevent simulator micro-stutters.
- **Persistent Profiles**: Automatically remembers your custom safety targets across your flight sessions.

## Installation
1. Copy or link the `flightgear_pillow_addon` directory into your FlightGear Add-ons folder.
2. Enable the add-on via the FlightGear launcher or your in-game Add-on management menu.

## License
This add-on is a derivative work based on the `flightgear-addon-littlenavmap` framework and is licensed under the **GNU GPL version 2 or later** (see the local `LICENSE` file for details).
