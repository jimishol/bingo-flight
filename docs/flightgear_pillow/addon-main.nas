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

    # Core Watchdog Engine Core
    var check_watchdog = func() {
        if (enabledNode.getValue() != "1") {
            is_loop_running = 0;
            print("copilot_pillow: Watchdog loop deactivated cleanly.");
            return; 
        }

        var alt_agl = props.globals.getNode("position/altitude-agl-ft", 1).getValue();
        var ias     = props.globals.getNode("velocities/airspeed-kt", 1).getValue();

        # Pull refresh value safely or fall back to 1 second if empty
        var interval = num(refreshRateNode.getValue());
        if (interval == nil or interval <= 0) { interval = 1; }

        if (alt_agl == nil or ias == nil) {
            settimer(check_watchdog, interval);
            return;
        }

        # Safe parameter check criteria (High and Slow)
        if (alt_agl > num(altOffsetNode.getValue()) and ias < num(airspeedNode.getValue())) {
            props.globals.getNode("sim/pause", 1).setValue(1);
            print("Copilot Pillow: WATCHDOG PAUSED THE SIMULATION.");
            
            enabledNode.setValue("0");
            is_loop_running = 0;
        } else {
            settimer(check_watchdog, interval);
        }
    };

    # Dynamic loop control check
    var check_loop_state = func() {
        if (enabledNode.getValue() == "1") {
            if (is_loop_running == 0) {
                is_loop_running = 1;
                check_watchdog();
            }
        }
    };

    # Native Signal Listeners mapping to property modifications
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
    });

    print("Copilot Pillow node mapping targets built cleanly inside: " ~ mySettingsRootPath);
}
