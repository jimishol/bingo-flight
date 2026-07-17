#
# Copilot Pillow addon
#
# Synced dynamically to identifier: com.cholidis.flightgear.CopilotPillow
#

var main = func( addon ) {
    var root = addon.basePath;
    var myAddonId  = addon.id; 
    var mySettingsRootPath = "/addons/by-id/" ~ myAddonId;
    var is_loop_running = 0;
    var watchdog_timer = nil;

    # Track structural generation targets
    var enabledNode = props.globals.getNode(mySettingsRootPath ~ "/enabled", 1);
    enabledNode.setAttribute("userarchive", "y");
    if (enabledNode.getValue() == nil) enabledNode.setValue("0");

    var refreshRateNode = props.globals.getNode(mySettingsRootPath ~ "/refresh-rate", 1);
    refreshRateNode.setAttribute("userarchive", "y");
    if (refreshRateNode.getValue() == nil) refreshRateNode.setValue("1");

    var altOffsetNode = props.globals.getNode(mySettingsRootPath ~ "/alt_offset", 1);
    altOffsetNode.setAttribute("userarchive", "y");
    if (altOffsetNode.getValue() == nil) altOffsetNode.setValue("1500");

    var airspeedNode = props.globals.getNode(mySettingsRootPath ~ "/airspeed_offset", 1);
    airspeedNode.setAttribute("userarchive", "y");
    if (airspeedNode.getValue() == nil) airspeedNode.setValue("60");

    # Single dual-purpose node for Max Airspeed / RPM
    var maxAirspeedNode = props.globals.getNode(mySettingsRootPath ~ "/max_airspeed_offset", 1);
    maxAirspeedNode.setAttribute("userarchive", "y");
    if (maxAirspeedNode.getValue() == nil) maxAirspeedNode.setValue("125");

    #
    # ✔ Single, clean helicopter detection
    #
    var is_helicopter = func() {
        var tags = props.globals.getNode("/sim/tags", 0);
        if (tags == nil) return 0;

        foreach (var c; tags.getChildren("tag")) {
            if (c.getValue() == "helicopter") return 1;
        }
        return 0;
    };

    # 1. CORE WATCHDOG ENGINE CORE
    var check_watchdog = func() {
        if (enabledNode.getValue() != "1") {
            is_loop_running = 0;
            if (watchdog_timer != nil) watchdog_timer.stop();
            print("copilot_pillow: Watchdog loop deactivated cleanly.");
            return;
        }
    
        var alt_agl = num(getprop("position/altitude-agl-ft"));
        var heli    = is_helicopter();
    
        var ias = nil;
        var rpm = nil;
    
        if (heli) {
            rpm = num(getprop("rotors/main/rpm"));
        } else {
            ias = num(getprop("velocities/airspeed-kt"));
        }
    
        # Fetch directly from GUI nodes, no guessing or hardcoded fallbacks
        var target_alt = num(altOffsetNode.getValue());
        var target_spd = num(airspeedNode.getValue());
        var target_max = num(maxAirspeedNode.getValue()); 
        var interval = num(refreshRateNode.getValue());
    
        # NEW STRICT VALIDATION: If the GUI input is missing or broken, disable the addon entirely!
        if (target_alt == nil or target_spd == nil or target_max == nil or interval == nil) {
            print("Copilot Pillow: Invalid or empty GUI inputs detected! Disabling addon safety block.");
            enabledNode.setValue("0");
            is_loop_running = 0;
            watchdog_timer.stop();
            return;
        }

        # Wait safely for altitude to populate from FDM
        if (alt_agl == nil) {
            watchdog_timer.restart(interval);
            return;
        }
    
        var trigger = 0;
    
        # EXACT user logic applied: 
        # if alt < altOffset OR (V > min AND V < max) then not pause else pause
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
            print("Copilot Pillow: CRITERIA MATCHED! TRIGGERING PAUSE STATE.");
            fgcommand("pause");
            
            # RESTORED EXACT ORIGINAL TOGGLE MECHANISM
            enabledNode.setValue("0");
            is_loop_running = 0;
            watchdog_timer.stop();
            return;
        }
    
        watchdog_timer.restart(interval);
    };

    # Instantiate the modern Object-Oriented timer as a single-shot engine
    watchdog_timer = maketimer(1.0, check_watchdog);
    watchdog_timer.singleShot = 1;

    # 2. DYNAMIC LOOP CONTROL CHECK
    var check_loop_state = func() {
        if (enabledNode.getValue() == "1") {
            if (is_loop_running == 0) {
                is_loop_running = 1;
                # Kept original 'or 1' exclusively here for timer boot safety
                var interval = num(refreshRateNode.getValue()) or 1;
                watchdog_timer.restart(interval);
            }
        } else {
            is_loop_running = 0;
            watchdog_timer.stop();
        }
    };

    # 3. NATIVE SIGNAL LISTENERS (Untouched)
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
        enabledNode.setValue("0");
        is_loop_running = 0;
        watchdog_timer.stop();
    });

    print("Copilot Pillow node mapping targets built cleanly inside: " ~ mySettingsRootPath);
}
