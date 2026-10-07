# ==============================================================================  
# FlightGear ATC TourGuide Addon - Main Script (8-Sector Version with Priority)
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
  
# Helper: Basic Whitespace Trimmer
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
  
# Returns 1 if this POI type is excluded  
var is_excluded = func(p_type, excluded_map) {  
    if (p_type == nil) return 0;  
    if (contains(excluded_map, "" ~ p_type)) return 1;  
    if (contains(TYPE_CODES, p_type)) {  
        var code = "" ~ TYPE_CODES[p_type];  
        if (contains(excluded_map, code)) return 1;  
    }  
    return 0;  
};  

# Standalone Helper: VRP Fallback Filter
# If suppress_vrp is enabled and ANY non-1000 landmark exists in the sector, drop VRPs
var filter_vrp_fallback = func(items, suppress_vrp) {
    if (items == nil or size(items) == 0) return [];
    if (!suppress_vrp) return items;

    var non_vrp = [];
    foreach (var item; items) {
        if (item.type != "visual-reporting-point" and item.type != 1000 and item.type != "1000") {
            append(non_vrp, item);
        }
    }

    # If any non-VRP landmark exists in this sector, return ONLY non-VRP items.
    # Otherwise, fall back to returning all original items (VRPs).
    return (size(non_vrp) > 0) ? non_vrp : items;
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
        return sprintf(prefix_compound, primary.name, primary.dist, secondary_city.name, secondary_city.dist);  
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
  
        var r_ahead  = get_cfg(addon, "range-ahead-nm", 16.0);  
        var r_aside  = get_cfg(addon, "range-aside-nm", 8.0);  
        var r_behind = get_cfg(addon, "range-behind-nm", 4.0);  
        
        # Sector half-angle (alpha) clamped to [0.0, 45.0]
        var raw_angle = get_cfg(addon, "sector-half-angle-deg", get_cfg(addon, "ahead-angle-deg", 22.5));
        var a_angle   = math.abs(raw_angle);
        if (a_angle > 45.0) a_angle = 45.0;
        if (a_angle < 0.0)  a_angle = 0.0;

        # Dynamic angle boundaries for 8 sectors
        var right_inner = 90.0 - a_angle;
        var right_outer = 90.0 + a_angle;
        var back_inner  = 180.0 - a_angle;
  
	var mult_city    = get_cfg(addon, "mult-city", 1.0);  
	var mult_town    = get_cfg(addon, "mult-town", 0.7);  
	var mult_village = get_cfg(addon, "mult-village", 0.35);  
	var mult_vrp     = get_cfg(addon, "mult-vrp", 1.3);
        var suppress_vrp = get_cfg(addon, "suppress-vrp-fallback", get_cfg(addon, "isolate-vrp-fallback", 0));

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
        var sectors = { 
            ahead: [], front_right: [], right: [], back_right: [],
            behind: [], back_left: [], left: [], front_left: []
        };  
  
        var i = 0;
        var total_pois = size(all_pois);
        var CHUNK = get_cfg(addon, "chunk-size", 24000);

        # Forward declare the scan function so the timer can reference it
        var scan_chunk = nil; 
        
        # maketimer defaults to real-time (not sim-time)
        var chunk_timer = maketimer(0, func { scan_chunk(); });
        chunk_timer.singleShot = 1;

        # --- Spatial Scanning Chunk Function ---
        scan_chunk = func {
            var start_i = i;
            var end_i = start_i + CHUNK;
            if (end_i > total_pois) end_i = total_pois;

            for (; i < end_i; i += 1) {
                var p = all_pois[i];
                var p_lt = poi_lat(p);
                var p_ln = poi_lon(p);
                if (math.abs(p_lt - ac_lat) > lat_margin) continue;
                if (math.abs(p_ln - ac_lon) > lon_margin) continue;

                var p_tp = poi_type(p);
                if (is_excluded(p_tp, excluded_map)) continue;

                var target = geo.Coord.new().set_latlon(p_lt, p_ln);
                var dist = ac_pos.distance_to(target) * 0.000539957; # meters to NM
                
                var mult = 1.0;
                if (p_tp == "city") mult = mult_city;
                elsif (p_tp == "town") mult = mult_town;
                elsif (p_tp == "village") mult = mult_village;
                elsif (p_tp == "visual-reporting-point") mult = mult_vrp;

                if (dist <= r_under) {
                    append(under_pois, { name: clean_tts_text(poi_name(p)), dist: dist, type: p_tp });
                    continue;
                }

                var brg = ac_pos.course_to(target);
                var diff = brg - ac_hdg;
                while (diff > 180.0) diff -= 360.0;
                while (diff < -180.0) diff += 360.0;

                var max_r = r_aside;
                if (diff >= -a_angle and diff <= a_angle) max_r = r_ahead;
                elsif (diff >= back_inner or diff <= -back_inner) max_r = r_behind;
                
                if (dist > (max_r * mult)) continue;

                var cleaned_name = clean_tts_text(poi_name(p));
                if (cleaned_name == "") continue;
                var item = { name: cleaned_name, dist: dist, type: p_tp };

                if (diff >= -a_angle and diff <= a_angle) {
                    append(sectors.ahead, item);
                } elsif (diff > a_angle and diff < right_inner) {
                    append(sectors.front_right, item);
                } elsif (diff >= right_inner and diff <= right_outer) {
                    append(sectors.right, item);
                } elsif (diff > right_outer and diff < back_inner) {
                    append(sectors.back_right, item);
                } elsif (diff >= back_inner or diff <= -back_inner) {
                    append(sectors.behind, item);
                } elsif (diff > -back_inner and diff < -right_outer) {
                    append(sectors.back_left, item);
                } elsif (diff >= -right_outer and diff <= -right_inner) {
                    append(sectors.left, item);
                } else {
                    append(sectors.front_left, item);
                }
            }

            if (i < total_pois) {
                # Restart single-shot timer for the next frame
                chunk_timer.restart(0);
            } else {
                # --- SCAN COMPLETE: Priority Filter & Announcement Generator ---
                var sort_by_dist = func(a, b) { return a.dist - b.dist; };

                var under_active       = filter_vrp_fallback(under_pois, suppress_vrp);
                var ahead_active       = filter_vrp_fallback(sectors.ahead, suppress_vrp);
                var front_right_active = filter_vrp_fallback(sectors.front_right, suppress_vrp);
                var right_active       = filter_vrp_fallback(sectors.right, suppress_vrp);
                var back_right_active  = filter_vrp_fallback(sectors.back_right, suppress_vrp);
                var behind_active      = filter_vrp_fallback(sectors.behind, suppress_vrp);
                var back_left_active   = filter_vrp_fallback(sectors.back_left, suppress_vrp);
                var left_active        = filter_vrp_fallback(sectors.left, suppress_vrp);
                var front_left_active  = filter_vrp_fallback(sectors.front_left, suppress_vrp);

                var max_dir_lines = get_cfg(addon, "max-directional-lines", 4);
                var lines = [];

                # 1. Reserved Overhead Slot (+1 Line)
                # Directly Below: Strictly single nearest landmark
                if (size(under_active) > 0) {
                    var s = sort(under_active, sort_by_dist);
                    append(lines, sprintf("Directly below: %s, %.1f nm", s[0].name, s[0].dist));
                }

                # 2. Sector Definitions
                var dir_candidates = [];
                var sector_defs = [
                    { key: "ahead",       items: ahead_active,       single: "Ahead: Approaching %s, %.1f nm",                         compound: "Ahead: Approaching %s (%.1f nm) towards %s (%.1f nm)" },
                    { key: "front_right", items: front_right_active, single: "Off your front right: %s, %.1f nm",                  compound: "Off your front right: %s (%.1f nm) and farther %s (%.1f nm)" },
                    { key: "right",       items: right_active,       single: "On your right: %s, %.1f nm",                         compound: "On your right: %s (%.1f nm) and farther %s (%.1f nm)" },
                    { key: "back_right",  items: back_right_active,  single: "Off your back right: %s, %.1f nm",                   compound: "Off your back right: %s (%.1f nm) and farther %s (%.1f nm)" },
                    { key: "behind",      items: behind_active,      single: "Behind: Just passed %s, %.1f nm",                        compound: "Behind: Just passed %s (%.1f nm) towards %s (%.1f nm)" },
                    { key: "back_left",   items: back_left_active,   single: "Off your back left: %s, %.1f nm",                    compound: "Off your back left: %s (%.1f nm) and farther %s (%.1f nm)" },
                    { key: "left",        items: left_active,        single: "On your left: %s, %.1f nm",                          compound: "On your left: %s (%.1f nm) and farther %s (%.1f nm)" },
                    { key: "front_left",  items: front_left_active,  single: "Off your front left: %s, %.1f nm",                   compound: "Off your front left: %s (%.1f nm) and farther %s (%.1f nm)" }
                ];

                # 3. Collect Active Sectors and Nearest Distance
                foreach (var sdef; sector_defs) {
                    if (size(sdef.items) > 0) {
                        var sorted_items = sort(sdef.items, sort_by_dist);
                        append(dir_candidates, {
                            sdef: sdef,
                            min_dist: sorted_items[0].dist
                        });
                    }
                }

                # 4. Sort Sectors by Nearest Landmark
                var sort_sectors_by_dist = func(a, b) { return a.min_dist - b.min_dist; };
                dir_candidates = sort(dir_candidates, sort_sectors_by_dist);

                # 5. Cap Directional Sectors to Max Limit
                var count = size(dir_candidates);
                if (count > max_dir_lines) count = max_dir_lines;

                for (var idx = 0; idx < count; idx += 1) {
                    var candidate = dir_candidates[idx];
                    append(lines, format_sector_message(candidate.sdef.items, candidate.sdef.single, candidate.sdef.compound));
                }

                is_scanning = 0; # Unlock scanning state

                # 6. Dispatch Speech
                if (size(lines) == 0) {
                    speak_lines(["No landmarks in range"]);
                    return;
                }

                speak_lines(lines);
            }
        };

        # Trigger first chunk
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
