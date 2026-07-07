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
    if (enabledNode.getValue() == nil) {
        enabledNode.setValue("0");
    }

    var refreshRateNode = props.globals.getNode(mySettingsRootPath ~ "/refresh-rate", 1);
    refreshRateNode.setAttribute("userarchive", "y");
    if (refreshRateNode.getValue() == nil) {
        refreshRateNode.setValue("1");
    }

    var altOffsetNode = props.globals.getNode(mySettingsRootPath ~ "/alt_offset", 1);
    altOffsetNode.setAttribute("userarchive", "y");
    if (altOffsetNode.getValue() == nil) {
        altOffsetNode.setValue("1500");
    }

    var airspeedNode = props.globals.getNode(mySettingsRootPath ~ "/airspeed_offset", 1);
    airspeedNode.setAttribute("userarchive", "y");
    if (airspeedNode.getValue() == nil) {
        airspeedNode.setValue("60");
    }

    # 1. CORE WATCHDOG ENGINE CORE
    var check_watchdog = func() {
        if (enabledNode.getValue() != "1") {
            is_loop_running = 0;
            if (watchdog_timer != nil) { watchdog_timer.stop(); }
            print("copilot_pillow: Watchdog loop deactivated cleanly.");
            return; 
        }

        # Force numeric conversions on live flight data
        var alt_agl = num(props.globals.getNode("position/altitude-agl-ft", 1).getValue());
        var ias     = num(props.globals.getNode("velocities/airspeed-kt", 1).getValue());

        # Force numeric conversions on GUI user inputs
        var target_alt = num(altOffsetNode.getValue());
        var target_spd = num(airspeedNode.getValue());

        var interval = num(refreshRateNode.getValue());
        if (interval == nil or interval <= 0) { interval = 1; }

        if (alt_agl == nil or ias == nil or target_alt == nil or target_spd == nil) {
            if (watchdog_timer != nil) { watchdog_timer.restart(interval); }
            return;
        }

        # Evaluation criteria match (High and Slow)
        if (alt_agl > target_alt and ias < target_spd) {
            print("Copilot Pillow: CRITERIA MATCHED! TRIGGERING PAUSE STATE.");
            
            fgcommand("pause");
            
            enabledNode.setValue("0");
            is_loop_running = 0;
            if (watchdog_timer != nil) { watchdog_timer.stop(); }
        } else {
            if (watchdog_timer != nil) { watchdog_timer.restart(interval); }
        }
    };

    # Instantiate the modern Object-Oriented timer as a single-shot engine
    watchdog_timer = maketimer(1.0, check_watchdog);
    watchdog_timer.singleShot = 1;

    # 2. DYNAMIC LOOP CONTROL CHECK
    var check_loop_state = func() {
        if (enabledNode.getValue() == "1") {
            if (is_loop_running == 0) {
                is_loop_running = 1;
                var interval = num(refreshRateNode.getValue()) or 1;
                watchdog_timer.restart(interval);
            }
        } else {
            is_loop_running = 0;
            watchdog_timer.stop();
        }
    };

    # 3. NATIVE SIGNAL LISTENERS
    var init_listener = _setlistener(mySettingsRootPath ~ "/enabled", func() {
        check_loop_state();
    });

    var fdm_listener = setlistener("/sim/signals/fdm-initialized", func() {
        removelistener(fdm_listener);
        check_loop_state();
    });

    var reinit_listener = _setlistener("/sim/signals/reinit", func {
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
