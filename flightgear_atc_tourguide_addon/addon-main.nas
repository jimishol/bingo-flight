# ==============================================================================  
# FlightGear ATC TourGuide Addon - Main Script  
# ==============================================================================  
  
var all_pois   = nil;  
var auto_timer = nil;  
var msg_queue  = [];  
var msg_timer  = nil;  
  
# Map FGPositioned type strings -> poi.dat numeric codes (for exclusion config)  
var TYPE_CODES = {  
    "country":                10,  
    "city":                   12,  
    "town":                   13,  
    "village":                14,  
    "visual-reporting-point": 1000,  
    "waypoint":               1001,  
};  
  
# Direct accessors for Positioned ghost objects  
var poi_lat  = func(p) { return p.lat;  };  
var poi_lon  = func(p) { return p.lon;  };  
var poi_name = func(p) { return p.name; };  
var poi_type = func(p) { return p.type; };  

# Dynamic Property Config Reader  
var get_cfg = func(addon, node_path, default_val) {  
    if (addon == nil or addon.node == nil) return default_val;  
    var cfg_node = addon.node.getNode(node_path);  
    return (cfg_node != nil) ? cfg_node.getValue() : default_val;  
};  
  
# Helper: Basic Whitespace Trimmer (preserves hyphens and underscore identifiers)
var trim_str = func(s) {
    if (s == nil) return "";
    var str = "" ~ s;
    while (size(str) > 0 and str[0] == 32) str = substr(str, 1);
    while (size(str) > 0 and str[size(str) - 1] == 32) str = substr(str, 0, size(str) - 1);
    return str;
};

# ------------------------------------------------------------------------------  
# Text Sanitizer (Discards non-ASCII landmarks for speech/ATC output)  
# ------------------------------------------------------------------------------  
var clean_tts_text = func(text) {  
    if (text == nil or text == "") return "";  
  
    var cleaned = "";  
    var last_was_space = 1;  
  
    for (var i = 0; i < size(text); i += 1) {  
        var c = text[i];  
  
        if (c == 40 or c == 41 or c == 45 or c == 47 or c == 95 or c == 46 or c == 44) {  
            c = 32;  
        }  
  
        if ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57)) {  
            cleaned ~= chr(c);  
            last_was_space = 0;  
        } elsif (c == 32) {  
            if (!last_was_space) {  
                cleaned ~= " ";  
                last_was_space = 1;  
            }  
        }  
    }  
  
    var sz = size(cleaned);  
    if (sz > 0 and cleaned[sz - 1] == 32) {  
        cleaned = substr(cleaned, 0, sz - 1);  
    }  
  
    return cleaned;  
};  

# Build Exclusion Lookup Map from Config  
var build_exclusion_map = func(raw_cfg) {  
    var map = {};  
    if (raw_cfg == nil) return map;  
  
    var tokens = split(",", "" ~ raw_cfg);  
    foreach (var tok; tokens) {  
        var t = trim_str(tok);  
        if (t != "") map[t] = 1;  
    }  
    return map;  
};  
  
# Returns 1 if this POI type is excluded (matched by name or by numeric code)  
var is_excluded = func(p_type, excluded_map) {  
    if (p_type == nil) return 0;  
    if (contains(excluded_map, "" ~ p_type)) return 1;  
    if (contains(TYPE_CODES, p_type)) {  
        var code = "" ~ TYPE_CODES[p_type];  
        if (contains(excluded_map, code)) return 1;  
    }  
    return 0;  
};  
  
# Defer C++ Database Load to Initial Load Frame  
var ensure_cache_loaded = func {  
    if (all_pois != nil) return;  
  
    all_pois = [];  
    foreach (var t; ["city", "town", "village", "visual-reporting-point"]) {  
        var res = positioned.findByName("", t);  
        if (res != nil) {  
            foreach (var p; res) append(all_pois, p);  
        }  
    }  
  
    print("[TourGuide] Global landmark database connected (" ~ size(all_pois) ~ " items).");  
};  

# Helper: Compound Announcement Generator for Sectors  
var format_sector_message = func(items, prefix_single, prefix_compound) {  
    var sort_by_dist = func(a, b) { return a.dist - b.dist; };  
    var s = sort(items, sort_by_dist);  
    var primary = s[0];  
    var secondary_city = nil;  
  
    if (primary.type != "city") {  
        foreach (var item; s) {  
            if (item.dist > primary.dist and item.type == "city") {  
                secondary_city = item;  
                break;  
            }  
        }  
    }  
  
    if (secondary_city != nil) {  
        return sprintf(prefix_compound, primary.name, secondary_city.name, primary.dist);  
    } else {  
        return sprintf(prefix_single, primary.name, primary.dist);  
    }  
};  
  
# ------------------------------------------------------------------------------  
# Main Addon Logic  
# ------------------------------------------------------------------------------  
var main = func(addon) {  
    print("[TourGuide] Initializing...");  
  
    var auto_sec     = get_cfg(addon, "auto-interval-sec", 900.0);  
    var msg_interval = get_cfg(addon, "speech-queue-interval-sec", 5.0);  
    var trigger_key  = get_cfg(addon, "trigger-key-code", 96);  

    var emit_next = func {  
        if (size(msg_queue) == 0) return;  
        var current_msg = msg_queue[0];  
        msg_queue = subvec(msg_queue, 1);  
        setprop("/sim/messages/atc", current_msg);  
        if (size(msg_queue) > 0) {  
            msg_timer.restart(msg_interval);  
        }  
    };  

    msg_timer = maketimer(msg_interval, emit_next);  
    msg_timer.singleShot = 1;  

    var speak_lines = func(lines) {  
        if (lines == nil or size(lines) == 0) return;  
        msg_timer.stop();  
        msg_queue = [];  
        foreach (var l; lines) append(msg_queue, l);  
        emit_next();  
    };  

    var is_scanning = 0; 

    var speak_nearest_poi = func {  
        if (is_scanning) {
            print("[TourGuide] Scan already running, ignoring keypress...");
            return; 
        }
        is_scanning = 1;
        print("[TourGuide] Starting spatial scan...");

        if (auto_timer != nil and auto_sec > 0) {  
            auto_timer.restart(auto_sec);  
        }  
  
        ensure_cache_loaded();  
  
        var ac_lat = getprop("/position/latitude-deg");  
        var ac_lon = getprop("/position/longitude-deg");  
        var ac_hdg = getprop("/orientation/heading-deg");  
        var ac_agl = getprop("/position/altitude-agl-ft");  
  
        if (ac_lat == nil or ac_lon == nil or ac_hdg == nil) {
            is_scanning = 0;
            return;  
        }
        if (ac_agl == nil) ac_agl = 0.0;  
  
        var r_ahead  = get_cfg(addon, "range-ahead-nm", 18.0);  
        var r_aside  = get_cfg(addon, "range-aside-nm", 9.0);  
        var r_behind = get_cfg(addon, "range-behind-nm", 6.0);  
        var a_angle  = get_cfg(addon, "ahead-angle-deg", 45);  
  
        var mult_city    = get_cfg(addon, "mult-city", 2.0);  
        var mult_town    = get_cfg(addon, "mult-town", 1.0);  
        var mult_village = get_cfg(addon, "mult-village", 0.5);  
        var mult_vrp     = get_cfg(addon, "mult-vrp", 1.5);  
  
        var exclude_cfg = get_cfg(addon, "exclude-types", "10,1001");  
        var excluded_map = build_exclusion_map(exclude_cfg);  
  
        var agl_mult = get_cfg(addon, "agl-under-multiplier", 2.0);  
        var r_under  = (ac_agl / 6076.12) * agl_mult;  
  
        var max_base_range = math.max(r_ahead, math.max(r_aside, r_behind));  
        var max_mult = math.max(mult_city, math.max(mult_town, math.max(mult_village, mult_vrp)));  
        var max_search_range = math.max(max_base_range * max_mult, r_under);  
  
        var lat_margin = max_search_range / 60.0;  
        var cos_lat = math.cos(ac_lat * math.pi / 180.0);  
        if (cos_lat < 0.01) cos_lat = 0.01;  
        var lon_margin = lat_margin / cos_lat;  
  
        var ac_pos = geo.Coord.new().set_latlon(ac_lat, ac_lon);  
  
        var under_pois = [];  
        var sectors = { ahead: [], left: [], right: [], behind: [] };  
  
        var i = 0;
        var total_pois = size(all_pois);
	var CHUNK = get_cfg(addon, "chunk-size", 24000);

        # Forward declare the scan function so the timer can reference it
        var scan_chunk = nil; 
        
        # maketimer defaults to real-time (not sim-time)
        var chunk_timer = maketimer(0, func { scan_chunk(); });
        chunk_timer.singleShot = 1;

        scan_chunk = func {
            var err = [];
            
            # call() acts as a try-catch block for Nasal exceptions
            call(func {
                var end_idx = i + CHUNK;
                if (end_idx > total_pois) end_idx = total_pois;

                while (i < end_idx) {
                    var p = all_pois[i];
                    if (p != nil) {
                        var p_lat = poi_lat(p);
                        var p_lon = poi_lon(p);
                        var p_type = poi_type(p);
                        
                        if (p_lat != nil and p_lon != nil) {
                            if (math.abs(p_lat - ac_lat) <= lat_margin and math.abs(p_lon - ac_lon) <= lon_margin) {
                                if (!is_excluded(p_type, excluded_map)) {
                                    var p_pos = geo.Coord.new().set_latlon(p_lat, p_lon);
                                    var dist = ac_pos.distance_to(p_pos) * 0.000539957;

                                    var clean_name = clean_tts_text(poi_name(p));
                                    if (clean_name != "") {
                                        if (r_under > 0 and dist <= r_under) {
                                            append(under_pois, {name: clean_name, dist: dist, type: p_type});
                                        } else {
                                            var t_mult = 1.0;
                                            if (p_type == "city") t_mult = mult_city;
                                            elsif (p_type == "town") t_mult = mult_town;
                                            elsif (p_type == "village") t_mult = mult_village;
                                            elsif (p_type == "visual-reporting-point") t_mult = mult_vrp;

                                            var bearing = ac_pos.course_to(p_pos);
                                            var diff = bearing - ac_hdg;
                                            while (diff > 180) diff -= 360;
                                            while (diff < -180) diff += 360;

                                            if (diff >= -a_angle and diff <= a_angle) {
                                                if (dist <= (r_ahead * t_mult)) append(sectors.ahead, {name: clean_name, dist: dist, diff: diff, type: p_type});
                                            } elsif (diff > a_angle and diff < (180.0 - a_angle)) {
                                                if (dist <= (r_aside * t_mult)) append(sectors.right, {name: clean_name, dist: dist, diff: diff, type: p_type});
                                            } elsif (diff < -a_angle and diff > -(180.0 - a_angle)) {
                                                if (dist <= (r_aside * t_mult)) append(sectors.left, {name: clean_name, dist: dist, diff: diff, type: p_type});
                                            } else {
                                                if (dist <= (r_behind * t_mult)) append(sectors.behind, {name: clean_name, dist: dist, diff: diff, type: p_type});
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    i += 1;
                }
            }, [], nil, err);

            if (size(err) > 0) {
                print("[TourGuide] Scan error aborted loop: " ~ err[0]);
                is_scanning = 0; 
                return;
            }

            if (i < total_pois) {
                # Restart single-shot timer for the next frame
                chunk_timer.restart(0);
            } else {
                is_scanning = 0; 
                print("[TourGuide] Scan finished.");
                var sort_by_dist = func(a, b) { return a.dist - b.dist; };

                if (size(under_pois) > 0) {
                    var s = sort(under_pois, sort_by_dist);
                    speak_lines([sprintf("Directly below: %s, %.1f nm", s[0].name, s[0].dist)]);
                    return;
                }

                var lines = [];

                if (size(sectors.ahead) > 0) append(lines, format_sector_message(sectors.ahead, "Ahead: Approaching %s, %.1f nm", "Ahead: Approaching %s towards %s, %.1f nm"));
                if (size(sectors.left) > 0) append(lines, format_sector_message(sectors.left, "On your left: %s, %.1f nm", "On your left: %s and farther %s, %.1f nm"));
                if (size(sectors.right) > 0) append(lines, format_sector_message(sectors.right, "On your right: %s, %.1f nm", "On your right: %s and farther %s, %.1f nm"));
                
                if (size(sectors.behind) > 0) {
                    var s = sort(sectors.behind, sort_by_dist);
                    append(lines, sprintf("Behind: Just passed %s, %.1f nm", s[0].name, s[0].dist));
                }

                if (size(lines) == 0) {
                    speak_lines(["No landmarks in range"]);
                    return;
                }

                speak_lines(lines);
            }
        };

        scan_chunk();
    };  
  
    globals["speak_nearest_poi"] = speak_nearest_poi;  

    var key_msg = "";
    if (trigger_key != nil and trigger_key > 0) {
        setlistener("/devices/status/keyboard/event", func(n) {  
            if (!n.getValue("pressed")) return;  
            if (n.getValue("key") == trigger_key) speak_nearest_poi();  
        });  
        key_msg = sprintf("[TourGuide] Loaded. Press key code %d to speak landmarks.", trigger_key);
    } else {
        key_msg = "[TourGuide] Loaded. Manual hotkey trigger is disabled.";
    }
    print(key_msg);

    var auto_msg = "";
    if (auto_sec > 0) {  
        auto_timer = maketimer(auto_sec, speak_nearest_poi);  
        auto_timer.simulatedTime = 1;  
        auto_timer.start();  
        auto_msg = sprintf("[TourGuide] Auto-announcements active every %.0f flight seconds.", auto_sec);  
    } else {
        auto_msg = "[TourGuide] Auto-announcements disabled.";
    }
    print(auto_msg);

    var preload_timer = maketimer(1.0, ensure_cache_loaded);  
    preload_timer.singleShot = 1;  
    preload_timer.start();  

    speak_lines([key_msg, auto_msg]);
};
