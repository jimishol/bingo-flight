## Profile 1: Thrustmaster T.A320 Copilot (Joystick)

This controller handles your primary flight controls, independent wheel braking, look-around views, cockpit camera tracking/seating adjustments, and the engine fuel primer.

### ✈️ Primary Axis Layout

| Axis ID | Primary Function | FlightGear Target Property | Directional Details |
| --- | --- | --- | --- |
| **Axis 0** | Aileron (Roll) | `/controls/flight/aileron` | Standard scaling (`1`) |
| **Axis 1** | Elevator (Pitch) | `/controls/flight/elevator` | Inverted scaling (`-1`) |
| **Axis 2** | Rudder (Yaw) | `/controls/flight/rudder` | Standard scaling (`1`) |
| **Axis 3** | Mixture Axis | `/controls/engines/mixture-all` | Full physical throw range |
| **Axis 4** | Horizontal View | Panning camera left / right | Relative adjustment step $\pm2^\circ$ |
| **Axis 5** | Vertical View | Panning camera up / down | Relative adjustment step $\pm1^\circ$ |

### 🔘 Button Map & System Scripts

* **Button 0 (Trigger):** Master Wheel Brakes
* *Action:* Applies **both** left and right main wheel brakes smoothly on hold; completely releases them upon lifting your index finger.


* **Button 1:** Instant Cockpit View Reset
* *Action:* Snaps camera coordinates back to center pilot level (`y-offset: 0.285m`), sets a natural Field of View (`42`), centers horizontal heading, and tilts down slightly (`-14^\circ`) directly toward the main instrument panel instrument cluster.


* **Button 2:** View Cycle Forwards (`view.stepView(1)`)
* **Button 3:** View Cycle Backwards (`view.stepView(-1)`)
* **Button 4:** Elevator Trim Down (`controls.elevatorTrim(1)`) [Repeatable]
* **Button 5:** Differential Left Brake Only
* *Action:* Targets `/controls/gear/brakes[0]` via Nasal array. Useful for tight taxi pivot turns.


* **Button 6:** Virtual Seat Adjustment Up
* *Action:* Slowly elevates your point-of-view eye height in steps of `0.005m` up to a solid ceiling limit of `0.35m`.


* **Button 7:** Virtual Seat Adjustment Down
* *Action:* Lowers your point-of-view height down to a minimum safety limit floor of `0.15m`.


* **Button 8:** Differential Right Brake Only
* *Action:* Targets `/controls/gear/brakes[1]` via Nasal array.


* **Button 9:** Elevator Trim Up (`controls.elevatorTrim(-1)`) [Repeatable]
* **Button 10:** Zoom View Out / Decrease Field of View (`view.decrease(0.75)`)
* **Button 15:** Zoom View In / Increase Field of View (`view.increase(0.75)`)
* **Button 16:** Engine Fuel Primer Pump Loop (`c172p.pumpPrimer()`)
* *Action:* Injected module execution that strokes the manual primer line on both physical click-down *and* pull-release cycles.



---

## Profile 2: Thrustmaster TCA Quadrant (Engines 1&2)

This unit handles your engine management, flaps deployment settings, dual-stage magnetos, starter circuits, your custom lever-transition takeoff trim system, and advanced autopilot toggle processing.

### ✈️ Primary Axis Layout

| Axis ID | Primary Function | FlightGear Target Property | Directional Details |
| --- | --- | --- | --- |
| **Axis 1** | Main Engine Throttle | `/controls/engines/throttle-all` | Maps full travel axis cleanly |

### 🔘 Button Map & System Scripts

* **Button 0:** Flaps Up (`controls.flapsDown(-1)`)
* **Button 1:** Flaps Down (`controls.flapsDown(1)`)
* **Button 2:** Magnetos Step Left / Coarse Tuning
* *Press:* `controls.stepMagnetos(2)`
* *Release (`<mod-up>`):* `controls.stepMagnetos(-2)`


* **Button 3:** Magnetos Step Right / Fine Tuning
* *Press:* `controls.stepMagnetos(1)`
* *Release (`<mod-up>`):* `controls.stepMagnetos(-1)`


* **Button 4:** KAP140 Autopilot Native Master Engagement Switch
* *Press:* Instantly plays standard internal cockpit audio feedback sound (`c172p.click("kap140")`) and feeds system runtime clocks (`sim/time/elapsed-sec`) directly down into the aircraft state engine. Includes conditional validation checks verifying pitch reference states and active system safety buses are clear.
* *Release (`<mod-up>`):* Sets the panel button tracking property cleanly back to zero.


* **Button 5:** Engine Starter Interlock Loop
* *Action:* Safety-gated loop script. If and only if your magneto selection dial is currently locked on BOTH (`== 3`), holding this physical button forces starter motor engagement (`controls.startEngine(1)`). Releasing the button instantly drops the starter out (`controls.startEngine(0)`).


* **Button 6:** Left Lever Position (Takeoff Trim Procedure)
* *Press:* Intentionally does nothing when resting fully in the Left Detent slot.
* *Release (`<mod-up>`):* **The transition trick.** Moving this lever away from Left and slipping it down into the empty Middle position immediately fires the script that sets your `/controls/flight/elevator-trim` variable directly to `-0.1` (Takeoff configuration).


* **Button 7:** Right Lever Position (Latching Parking Brake Switch)
* *Press:* Slipping the physical hardware switch cleanly into the Right Detent assigns `/controls/gear/brake-parking` directly to `1` (Brakes Locked).
* *Release (`<mod-up>`):* Moving the switch back out into the neutral Middle position triggers the release code, setting the parking brake property back to `0`.


* **Button 15:** Thrust Reverser Toggle Handler (`controls.reverserTogglePosition()`)

---

### 💡 Quick Maintenance Notes for the Future:

1. All property-assign loops target absolute flightdeck nodes. If you ever copy snippets from native instruments inside aircraft folders, **always remember to append the leading forward slash (`/`)** so the joystick knows it is referencing global properties rather than looking for a local hardware tree!
2. Buttons utilizing `__js1` or `__js2` namespaces ensure that cross-talk calls between separate USB hardware channels don't override or drop execution sequences when you run complex macro actions simultaneously.
