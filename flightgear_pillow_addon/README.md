# Copilot Pillow (FlightGear Add-on)

An automated high-altitude safety watchdog built for long-haul cruise monitoring.

## What it does

Copilot Pillow was born out of a desire for a realistic safety net during long, real-time cruise flights. During a 90-minute cruise phase with navigation enabled—where the engine was leaned out to maximum EGT (Exhaust Gas Temperature) to stretch fuel range—unpredicted atmospheric changes across shifting weather tiles caused the aircraft to bleed speed, stall, and enter a flat spin while the pilot was away from the desk.

Since pausing the simulator manually or using time compression takes away from the experience of a continuous, real-time flight, Copilot Pillow provides a clever workaround. It acts as your automated virtual copilot during steady, long-haul high-altitude cruise phases.

If you step away from the controls and the aircraft drops below **or exceeds** your safety limits while remaining at your high cruise altitude, the add-on instantly triggers FlightGear's native **Pause** state. This safely freezes the simulation mid-air, preventing a catastrophic stall, structural overspeed, or loss of control, giving you complete peace of mind during hours of continuous, uncompressed flight.

## How it Works

* **Altitude Target Threshold (AGL offset)**: This target exists solely to restrict protection when you are at low altitudes (such as takeoff, climb, or approach) where you are actively handling the controls and do not want the watchdog interfering.
* **Minimum & Maximum Speed / RPM Thresholds**:
* **For Airplanes**: This monitors indicated airspeed (kt). Set the minimum with a safe margin above your actual stall speed, and the maximum below your structural Vne (Never Exceed Speed). This gives the watchdog time to react and pause the simulator *before* a true aerodynamic stall or overspeed damage develops.
* **For Helicopters**: The add-on automatically detects if you are flying a helicopter and switches to monitoring physical main rotor RPM. Set the minimum above the critical rotor stall RPM limit and the maximum below the structural over-rev limit.


* **Auto-Disable Safeguard**: When a protection pause is triggered, the add-on automatically disables itself. When you return to your desk, you can simply press **"p"** to unpause and recover the aircraft. If you plan to step away a second time, you must manually toggle Copilot Pillow back on.

## Features

* **Multi-Category Watchdog Engine**: Smart, automated mode switching between Fixed-Wing (Airspeed) and Rotary-Wing (Rotor RPM) aircraft.
* **High-Altitude Stall & Overspeed Prevention**: Actively monitors Live AGL (Above Ground Level) altitude alongside Calibrated Airspeed (CAS via `/velocities/airspeed-kt`) or Main Rotor Speed (RPM via `/rotors/main/rpm`).
* **Resource Efficient**: Built using modern, object-oriented `maketimer` loops to prevent simulator micro-stutters.
* **Persistent Profiles**: Automatically remembers your custom safety targets across your flight sessions.

## Installation

1. Copy or link the `flightgear_pillow_addon` directory into your FlightGear Add-ons folder.
2. Enable the add-on via the FlightGear launcher or your in-game Add-on management menu.

## Configuration Options

Inside the in-game FlightGear menu under **Copilot Pillow Options**, you can configure:

| Option | Unit/Type | Description / Recommended Setting |
| --- | --- | --- |
| **Enable Copilot Pillow** | Boolean Toggle | Activates or deactivates the live watchdog monitoring loop. |
| **Refresh rate** | Seconds | How often the watchdog evaluates your safety criteria (Default: `1`). |
| **AGL offset (ft)** | Feet AGL | The height above ground where protection arms. (e.g., `1500` or higher). |
| **Airspeed min / (RPM min for Heli)** | Knots / Raw RPM | **Planes**: Target airspeed threshold (e.g., `60` kt for the C172P). <br>

<br>**Helis**: Actual physical rotor RPM threshold (e.g., `400` to `450` RPM for light helis like the R22). |

---

## Remote Control & Verification (Via FlightGear HTTPD)

While Copilot Pillow provides an excellent automated safety net, an autopilot cannot fly an aircraft indefinitely without pilot intervention. If you use external moving maps like LittleNavMap, you likely already have FlightGear's built-in web server running. You can leverage this web server to manually toggle and verify your simulation's pause state from a secondary laptop, tablet, or mobile device (such as Termux on Android) over your local network.

### 1. Prerequisites

Ensure FlightGear is launched with the built-in web server enabled:
`--httpd=5400`

### 2. POSIX Shell Helper Function

Add the following shell function to your remote device's profile configuration file (e.g., `~/.bashrc`, `~/.zshrc`, or your `sh` environment). This code executes commands directly on your FlightGear host via SSH, ensuring that interactive password prompts work flawlessly and remote wildcards do not break the session.

```sh
fg_pause() {
    # The HTTPD server port configured on your FlightGear machine
    port=5400

    # -------------------------------------------------------------
    # CONNECTION OPTIONS: Uncomment ONLY ONE target host format below
    # -------------------------------------------------------------
    # OPTION A: Using a standard user/IP address configuration
    target_host="user@192.168.1.100"
    
    # OPTION B: Using a pre-configured .ssh/config host alias
    # target_host="desktop"
    # -------------------------------------------------------------

    echo "🔒 Connecting to $target_host (you may be prompted for your password)..."

    # We pull the current status first to check if the server is even reachable
    response=$(ssh "$target_host" "curl -s --max-time 3 'http://localhost:$port/json/sim/freeze/master'" 2>/dev/null)

    if [ -z "$response" ]; then
        echo "❌ Error: Cannot connect to FlightGear. Is the HTTP server running on port $port?"
        return 1
    fi

    # Trigger the toggle poke
    ssh "$target_host" "curl -s 'http://localhost:$port/run.cgi?value=pause'" >/dev/null 2>&1

    # Final check to see what the toggle changed the state to
    final_state=$(ssh "$target_host" "curl -s 'http://localhost:$port/json/sim/freeze/master'" 2>/dev/null)

    # Evaluate the output of the remote command string
    if echo "$final_state" | grep '"value":true' >/dev/null 2>&1; then
        echo "⏸️  FlightGear is paused"
    else
        echo "✈️  FlightGear runs"
    fi
}

```

> 💡 **Tip for Power Users:** You can map your connection parameters cleanly into your local machine's `~/.ssh/config` file so you do not have to hardcode explicit IP addresses inside scripts.
> **For Password Authentication:**
> ```text
> Host desktop
>      HostName 192.168.1.100
>      User your_username
> 
> ```
> 
> 
> **For SSH Key Authentication (Passwordless):**
> If you have configured public key authentication, simply add your key path to the configuration block:
> ```text
> Host desktop
>      HostName 192.168.1.100
>      User your_username
>      IdentityFile ~/.ssh/id_rsa
> 
> ```
> 
> 

### 3. Usage

Simply run the command directly from your terminal session whenever you need to check on or pause your long-haul flight while away from your primary desk:

```bash
fg_pause

```

## License
The core logic and code of this add-on are original works created by the author and licensed under the **GNU General Public License version 3** (see the local `LICENSE` file for the full text). 

The underlying add-on skeleton and structural configuration are adapted from the [flightgear-addon-littlenavmap](https://github.com/slawekmikula/flightgear-addon-littlenavmap) framework by Slawek Mikula (licensed under GNU GPL v2 or later).
