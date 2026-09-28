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
# Accepts both type names ("visual-reporting-point") and numeric poi.dat codes ("1000")  
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
  
    # Look for a farther major landmark (City) in the same sector  
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

    # Configurable Speech Queue Handler (FIFO)  
    var speak_lines = func(lines) {  
        if (size(lines) == 0) return;  
  
        msg_queue = lines;  
  
        var emit_next = func {  
            if (size(msg_queue) == 0) return;  
  
            var current_msg = msg_queue[0];  
            msg_queue = subvec(msg_queue, 1);  
  
            setprop("/sim/messages/atc", current_msg);  
  
            if (size(msg_queue) > 0) {  
                msg_timer.restart(msg_interval);  
            }  
        };  
  
        if (msg_timer == nil) {  
            msg_timer = maketimer(msg_interval, emit_next);  
            msg_timer.singleShot = 1;  
        } else {  
            msg_timer.stop();  
        }  
  
        emit_next();  
    };  
  
    var speak_nearest_poi = func {  
        if (auto_timer != nil and auto_sec > 0) {  
            auto_timer.restart(auto_sec);  
        }  
  
        ensure_cache_loaded();  
  
        var ac_lat = getprop("/position/latitude-deg");  
        var ac_lon = getprop("/position/longitude-deg");  
        var ac_hdg = getprop("/orientation/heading-deg");  
        var ac_agl = getprop("/position/altitude-agl-ft");  
  
        if (ac_lat == nil or ac_lon == nil or ac_hdg == nil) return;  
        if (ac_agl == nil) ac_agl = 0.0;  
  
        # Sector Base Limits (NM)  
        var r_ahead  = get_cfg(addon, "range-ahead-nm", 18.0);  
        var r_aside  = get_cfg(addon, "range-aside-nm", 9.0);  
        var r_behind = get_cfg(addon, "range-behind-nm", 6.0);  
        var a_angle  = get_cfg(addon, "ahead-angle-deg", 45);  
  
        # Type Multipliers  
        var mult_city    = get_cfg(addon, "mult-city", 2.0);  
        var mult_town    = get_cfg(addon, "mult-town", 1.0);  
        var mult_village = get_cfg(addon, "mult-village", 0.5);  
        var mult_vrp     = get_cfg(addon, "mult-vrp", 1.5);  
  
        # Configurable Exclude List  
        var exclude_cfg = get_cfg(addon, "exclude-types", "10,1001");  
        var excluded_map = build_exclusion_map(exclude_cfg);  
  
        # Overhead / Directly Below Radius Calculation  
        var agl_mult = get_cfg(addon, "agl-under-multiplier", 2.0);  
        var r_under  = (ac_agl / 6076.12) * agl_mult;  
  
        # Dynamic Bounding-Box Margin  
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
  
        foreach (var p; all_pois) {  
            var p_lat = poi_lat(p);  
            var p_lon = poi_lon(p);  
            var p_type = poi_type(p);  
            if (p_lat == nil or p_lon == nil) continue;  
  
            # 1. Microsecond Bounding-Box Filter  
            if (math.abs(p_lat - ac_lat) > lat_margin) continue;  
            if (math.abs(p_lon - ac_lon) > lon_margin) continue;  
  
            # 2. Configurable Type Exclusion Filter  
            if (is_excluded(p_type, excluded_map)) continue;  
  
            # 3. Distance Calculation  
            var p_pos = geo.Coord.new().set_latlon(p_lat, p_lon);  
            var dist = ac_pos.distance_to(p_pos) * 0.000539957; # meters -> NM  
  
            # 4. Text Sanitization  
            var clean_name = clean_tts_text(poi_name(p));  
            if (clean_name == "") continue;  
  
            # 5. Check "Directly Below" Zone First  
            if (r_under > 0 and dist <= r_under) {  
                append(under_pois, {name: clean_name, dist: dist, type: p_type});  
                continue;  
            }  
  
            # 6. Resolve Type Multipliers  
            var t_mult = 1.0;  
            if (p_type == "city") t_mult = mult_city;  
            elsif (p_type == "town") t_mult = mult_town;  
            elsif (p_type == "village") t_mult = mult_village;  
            elsif (p_type == "visual-reporting-point") t_mult = mult_vrp;  
  
            # 7. Relative Bearing Calculation  
            var bearing = ac_pos.course_to(p_pos);  
            var diff = bearing - ac_hdg;  
            while (diff > 180) diff -= 360;  
            while (diff < -180) diff += 360;  
  
            # Sector Assignment with Scaled Limits  
            if (diff >= -a_angle and diff <= a_angle) {  
                if (dist <= (r_ahead * t_mult)) {  
                    append(sectors.ahead, {name: clean_name, dist: dist, diff: diff, type: p_type});  
                }  
            } elsif (diff > a_angle and diff < (180.0 - a_angle)) {  
                if (dist <= (r_aside * t_mult)) {  
                    append(sectors.right, {name: clean_name, dist: dist, diff: diff, type: p_type});  
                }  
            } elsif (diff < -a_angle and diff > -(180.0 - a_angle)) {  
                if (dist <= (r_aside * t_mult)) {  
                    append(sectors.left, {name: clean_name, dist: dist, diff: diff, type: p_type});  
                }  
            } else {  
                if (dist <= (r_behind * t_mult)) {  
                    append(sectors.behind, {name: clean_name, dist: dist, diff: diff, type: p_type});  
                }  
            }  
        }  
  
        var sort_by_dist = func(a, b) { return a.dist - b.dist; };  
  
        # Prioritize "Directly Below" (Single Closest Only)  
        if (size(under_pois) > 0) {  
            var s = sort(under_pois, sort_by_dist);  
            speak_lines([sprintf("Directly below: %s, %.1f nm", s[0].name, s[0].dist)]);  
            return;  
        }  
  
        var lines = [];  
  
        if (size(sectors.ahead) > 0) {  
            append(lines, format_sector_message(  
                sectors.ahead,  
                "Ahead: Approaching %s, %.1f nm",  
                "Ahead: Approaching %s towards %s, %.1f nm"));  
        }  
  
        if (size(sectors.left) > 0) {  
            append(lines, format_sector_message(  
                sectors.left,  
                "On your left: %s, %.1f nm",  
                "On your left: %s and farther %s, %.1f nm"));  
        }  
  
        if (size(sectors.right) > 0) {  
            append(lines, format_sector_message(  
                sectors.right,  
                "On your right: %s, %.1f nm",  
                "On your right: %s and farther %s, %.1f nm"));  
        }  
  
        if (size(sectors.behind) > 0) {  
            var s = sort(sectors.behind, sort_by_dist);  
            append(lines, sprintf("Behind: Just passed %s, %.1f nm", s[0].name, s[0].dist));  
        }  
  
        if (size(lines) == 0) {  
            speak_lines(["No landmarks in range"]);  
            return;  
        }  
  
        speak_lines(lines);  
    };  
  
    globals["speak_nearest_poi"] = speak_nearest_poi;  
  
    # Dynamic trigger key binding  
    setlistener("/devices/status/keyboard/event", func(n) {  
        if (!n.getValue("pressed")) return;  
        if (n.getValue("key") == trigger_key) speak_nearest_poi();  
    });  
  
    var preload_timer = maketimer(1.0, ensure_cache_loaded);  
    preload_timer.singleShot = 1;  
    preload_timer.start();  
  
    if (auto_sec > 0) {  
        auto_timer = maketimer(auto_sec, speak_nearest_poi);  
        auto_timer.simulatedTime = 1;   # sim/flight time; set before start()  
        auto_timer.start();  
        print(sprintf("[TourGuide] Auto-announcements active every %.0f flight seconds.", auto_sec));  
    }  
  
    print(sprintf("[TourGuide] Loaded. Press key code %d to speak landmarks.", trigger_key));  
};
