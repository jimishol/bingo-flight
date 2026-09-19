#
# Copilot Pillow addon
#
# Synced strictly to identifier: com.cholidis.flightgear.CopilotPillow
#

var main = func( addon ) {
    var root = addon.basePath;
    
    # Forcing the exact ID so no remnants of org.flightgear.addons.copilot_pillow can ever slip in.
    var myAddonId  = "com.cholidis.flightgear.CopilotPillow"; 
    var mySettingsRootPath = "/addons/by-id/" ~ myAddonId;
    
    var is_loop_running = 0;
    var watchdog_timer = nil;

    var intervalNode = props.globals.getNode(mySettingsRootPath ~ "/interval-sec", 1);
    if (intervalNode.getValue() == nil) {
        intervalNode.setAttribute("userarchive", "y");
        intervalNode.setDoubleValue(1/60);
    }
    var interval = num(intervalNode.getValue()) or (1/60);

    # Off by default logic
    var enabledNode = props.globals.getNode(mySettingsRootPath ~ "/enabled", 1);
    enabledNode.setAttribute("userarchive", "y");
    if (enabledNode.getValue() == nil) enabledNode.setBoolValue(0);

    var heliNode = props.globals.getNode(mySettingsRootPath ~ "/is_helicopter", 1);
    heliNode.setAttribute("userarchive", "y");
    if (heliNode.getValue() == nil) heliNode.setBoolValue(0);

    var altOffsetNode = props.globals.getNode(mySettingsRootPath ~ "/alt_offset", 1);
    altOffsetNode.setAttribute("userarchive", "y");
    if (altOffsetNode.getValue() == nil) altOffsetNode.setDoubleValue(1500);

    var airspeedNode = props.globals.getNode(mySettingsRootPath ~ "/airspeed_offset", 1);
    airspeedNode.setAttribute("userarchive", "y");
    if (airspeedNode.getValue() == nil) airspeedNode.setDoubleValue(60);

    var maxAirspeedNode = props.globals.getNode(mySettingsRootPath ~ "/max_airspeed_offset", 1);
    maxAirspeedNode.setAttribute("userarchive", "y");
    if (maxAirspeedNode.getValue() == nil) maxAirspeedNode.setDoubleValue(125);

    # REVEALED: Initialize last-frame-sim-dt-sec immediately so it shows up in the property tree browser
    var lastFrameDtNode = props.globals.getNode(mySettingsRootPath ~ "/last-frame-sim-dt-sec", 1);
    if (lastFrameDtNode.getValue() == nil) {
        lastFrameDtNode.setDoubleValue(0.0);
    }

    # Track the previous frame's simulation time across timer ticks
    var last_sim_time = nil;

    # 1. CORE WATCHDOG ENGINE
    var check_watchdog = func() {
        if (enabledNode.getValue() != 1 and enabledNode.getValue() != "1") {
            is_loop_running = 0;
            last_sim_time = nil;
            if (watchdog_timer != nil) watchdog_timer.stop();
            logprint(LOG_INFO, "copilot_pillow: Watchdog loop deactivated cleanly.");
            return;
        }

        # Measure simulated frame time elapsed since the previous tick
        var current_sim_time = num(getprop("/sim/time/elapsed-sec"));
        var frame_sim_dt = 0;
        if (last_sim_time != nil and current_sim_time != nil) {
            frame_sim_dt = current_sim_time - last_sim_time;
        }
        last_sim_time = current_sim_time;

        var alt_agl = num(getprop("/position/altitude-agl-ft"));
        var heli = heliNode.getBoolValue();
        
        var ias = nil;
        var rpm = nil;
        
        if (heli) {
            rpm = num(getprop("/rotors/main/rpm"));
        } else {
            ias = num(getprop("/velocities/airspeed-kt"));
        }

        var target_alt = num(altOffsetNode.getValue());
        var target_spd = num(airspeedNode.getValue());
        var target_max = num(maxAirspeedNode.getValue()); 
        
        if (target_alt == nil or target_spd == nil or target_max == nil) {
            logprint(LOG_ALERT, "Copilot Pillow: Invalid or empty GUI inputs detected! Disabling addon safety block.");
            enabledNode.setBoolValue(0);
            is_loop_running = 0;
            last_sim_time = nil;
            watchdog_timer.stop();
            return;
        }

        if (alt_agl == nil) {
            watchdog_timer.restart(interval);
            return;
        }
        
        var trigger = 0;
        
        if (heli) {
            if (rpm != nil) {
                if (alt_agl < target_alt or (rpm > target_spd and rpm < target_max)) {
                    trigger = 0;
                } else {
                    trigger = 1;
                }
            }
        } else {
            if (ias != nil) {
                if (alt_agl < target_alt or (ias > target_spd and ias < target_max)) {
                    trigger = 0;
                } else {
                    trigger = 1;
                }
            }
        }
        
        if (trigger) {
            logprint(LOG_ALERT, sprintf("Copilot Pillow: CRITERIA MATCHED! Sim jumped %.4f sec in triggering frame. Resetting speed-up and pausing.", frame_sim_dt));
            
            # Records the precise dt of the paused frame
            lastFrameDtNode.setDoubleValue(frame_sim_dt);

            setprop("/sim/speed-up", 1);
            fgcommand("pause");
            
            # Turns the addon off again
            enabledNode.setBoolValue(0);
            is_loop_running = 0;
            last_sim_time = nil;
            watchdog_timer.stop();
            return;
        }
        
        watchdog_timer.restart(interval);
    };

    watchdog_timer = maketimer(interval, check_watchdog);
    watchdog_timer.singleShot = 1;

    # 2. DYNAMIC LOOP CONTROL CHECK
    var check_loop_state = func() {
        if (enabledNode.getValue() == 1 or enabledNode.getValue() == "1") {
            if (is_loop_running == 0) {
                is_loop_running = 1;
                last_sim_time = nil; # Prevent stale time if recently enabled
                watchdog_timer.restart(interval);
            }
        } else {
            is_loop_running = 0;
            last_sim_time = nil; # Deepwiki fix: clear stale time when disabled via GUI
            watchdog_timer.stop();
        }
    };

    # 3. NATIVE SIGNAL LISTENERS (Restored to original logic)
    var init_listener = _setlistener(mySettingsRootPath ~ "/enabled", func() {
        check_loop_state();
    });

    var fdm_listener = setlistener("/sim/signals/fdm-initialized", func() {
        removelistener(fdm_listener);
        check_loop_state();
    });

    var reinit_listener = _setlistener("/sim/signals/reinit", func() {
        removelistener(reinit_listener);
        check_loop_state();
    });

    var exit_listener = setlistener("/sim/signals/exit", func() {
        removelistener(exit_listener);
        enabledNode.setBoolValue(0);
        is_loop_running = 0;
        last_sim_time = nil;
        watchdog_timer.stop();
    });

    logprint(LOG_INFO, "Copilot Pillow nodes generated strictly inside: " ~ mySettingsRootPath);
}
