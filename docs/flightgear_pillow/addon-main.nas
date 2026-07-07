#
# Copilot Pillow addon
#
# Mirrored perfectly from Slawek Mikula's LittleNavMap structure
#

var main = func( addon ) {
    var root = addon.basePath;
    var myAddonId  = addon.id;
    var mySettingsRootPath = "/addons/by-id/" ~ myAddonId;
    var is_loop_running = 0;

    # Initialize Property Nodes with User Archive Attributes
    var enabledNode = props.globals.getNode(mySettingsRootPath ~ "/enabled", 1);
    enabledNode.setAttribute("userarchive", "y");
    if (enabledNode.getValue() == nil) {
        enabledNode.setValue("0");
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

    var notifyHostNode = props.globals.getNode(mySettingsRootPath ~ "/notify_host", 1);
    notifyHostNode.setAttribute("userarchive", "y");
    if (notifyHostNode.getValue() == nil) {
        notifyHostNode.setValue("");
    }

    var notifyHost2Node = props.globals.getNode(mySettingsRootPath ~ "/notify_host2", 1);
    notifyHost2Node.setAttribute("userarchive", "y");
    if (notifyHost2Node.getValue() == nil) {
        notifyHost2Node.setValue("");
    }

    # Core Notification Delivery System
    var send_notifications = func(msg) {
        var host1 = notifyHostNode.getValue();
        if (host1 != nil and host1 != "") {
            os.execute("ssh " ~ host1 ~ " notify-send '" ~ msg ~ "' &"); 
        }
        var host2 = notifyHost2Node.getValue();
        if (host2 != nil and host2 != "") {
            os.execute("ssh " ~ host2 ~ " notify-send '" ~ msg ~ "' &"); 
        }
    };

    # Core Watchdog Logic
    var check_watchdog = func() {
        if (enabledNode.getValue() != "1") {
            is_loop_running = 0;
            print("copilot_pillow: Monitoring loop stopped cleanly.");
            return; 
        }

        var alt_agl = props.globals.getNode("position/altitude-agl-ft", 1).getValue();
        var ias     = props.globals.getNode("velocities/airspeed-kt", 1).getValue();

        if (alt_agl == nil or ias == nil) {
            settimer(check_watchdog, 1);
            return;
        }

        if (alt_agl > num(altOffsetNode.getValue()) and ias < num(airspeedNode.getValue())) {
            props.globals.getNode("sim/pause", 1).setValue(1);
            send_notifications("Copilot Pillow: paused (high & slow)");
            
            enabledNode.setValue("0");
            is_loop_running = 0;
            print("copilot_pillow: Watchdog triggered pause. Disarming monitor.");
        } else {
            settimer(check_watchdog, 1);
        }
    };

    # Background monitoring control hook
    var check_loop_state = func() {
        if (enabledNode.getValue() == "1") {
            if (is_loop_running == 0) {
                is_loop_running = 1;
                check_watchdog();
            }
        }
    };

    # Lifecycle Signal Handlers matching LNM layout architecture
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
}
