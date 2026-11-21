# -*- coding: utf-8 -*-
"""
Contour-Flight: Terrain-Aware Theta* Route Planner for Little Navmap & FlightGear
Uses pure Python GLOBE binary elevation reader with in-memory caching.
Processes fully saved flight plan drafts in-place and synchronizes both formats.
"""

import warnings
warnings.filterwarnings("ignore", message="Valid PROJ data directory not found")

import math
import heapq
import json
import os
import re
import sys
import csv
import io
import sqlite3
import urllib.request
from pyproj import Geod
from global_reader import PythonGlobeReader

# Initialize Geod for precise geodesic distance calculations (WGS84)
GEOD = Geod(ellps="WGS84")

# Global GLOBE grid dimensions (30 arc-seconds = 0.5 nm latitude per row)
GRID_COLUMNS = 43200
GRID_ROWS = 21600
M_TO_FT = 3.28084


def lonlat_to_rowcol(lon, lat):
    """Converts geographic longitude/latitude to GLOBE global grid row and column."""
    col = int(GRID_COLUMNS * (lon + 180.0) / 360.0)
    row = int(GRID_ROWS * (90.0 - lat) / 180.0)
    return row % GRID_ROWS, col % GRID_COLUMNS


def rowcol_to_lonlat(row, col):
    """Converts GLOBE global grid row and column center back to geographic lon/lat."""
    lon = ((col + 0.5) / GRID_COLUMNS) * 360.0 - 180.0
    lat = 90.0 - ((row + 0.5) / GRID_ROWS) * 180.0
    return lon, lat


def compute_distance(p1, p2):
    """Computes great-circle distance in meters between two (lon, lat) points."""
    _, _, dist = GEOD.inv(p1[0], p1[1], p2[0], p2[1])
    return dist


def get_supercover_line_cells(r0, c0, r1, c1):
    """
    Supercover Bresenham line algorithm: returns EVERY grid cell the line segment
    touches, including orthogonal neighbors on diagonal steps so rays cannot
    tunnel through narrow ridges.
    """
    cells = [(r0, c0)]
    dx = abs(c1 - c0)
    dy = abs(r1 - r0)
    sx = 1 if c0 < c1 else -1
    sy = 1 if r0 < r1 else -1

    x, y = c0, r0
    err = dx - dy

    while x != c1 or y != r1:
        prev_x, prev_y = x, y
        e2 = 2 * err
        stepped_x = False
        stepped_y = False

        if e2 > -dy:
            err -= dy
            x += sx
            stepped_x = True
        if e2 < dx:
            err += dx
            y += sy
            stepped_y = True

        # On a diagonal step, include both orthogonal bridge cells
        if stepped_x and stepped_y:
            cells.append((prev_y, x))
            cells.append((y, prev_x))

        cells.append((y, x))

    return cells


def is_line_clear(r0, c0, r1, c1, allowed_proxy):
    """Checks if a supercover line of sight between two grid cells is clear."""
    for rc in get_supercover_line_cells(r0, c0, r1, c1):
        if not allowed_proxy[rc]:
            return False
    return True


def build_buffer_offsets(horizontal_buffer_nm, ref_lat):
    """Precomputes (dr, dc) grid offsets within horizontal_buffer_nm at ref_lat."""
    if horizontal_buffer_nm <= 0:
        return [(0, 0)]

    # 1 GLOBE row = 0.5 nm; 1 GLOBE col = 0.5 * cos(lat) nm
    nm_per_row = 0.5
    nm_per_col = max(0.05, 0.5 * math.cos(math.radians(ref_lat)))

    max_dr = int(math.ceil(horizontal_buffer_nm / nm_per_row))
    max_dc = int(math.ceil(horizontal_buffer_nm / nm_per_col))

    offsets = []
    for dr in range(-max_dr, max_dr + 1):
        for dc in range(-max_dc, max_dc + 1):
            dist_nm = math.hypot(dr * nm_per_row, dc * nm_per_col)
            if dist_nm <= horizontal_buffer_nm:
                offsets.append((dr, dc))
    return offsets


def theta_star(start_rc, goal_rc, allowed_proxy, grid_step=1, max_iters=150000):
    """Any-angle Theta* pathfinding algorithm on the GLOBE grid."""
    start_r, start_c = start_rc
    goal_r, goal_c = goal_rc

    open_set = []
    heapq.heappush(open_set, (0.0, start_r, start_c))

    g_score = {start_rc: 0.0}
    parent = {start_rc: start_rc}
    closed_set = set()

    lon_g, lat_g = rowcol_to_lonlat(*goal_rc)

    iters = 0
    while open_set and iters < max_iters:
        iters += 1
        _, curr_r, curr_c = heapq.heappop(open_set)
        curr_rc = (curr_r, curr_c)

        if curr_rc == goal_rc:
            path = []
            node = goal_rc
            while node != start_rc:
                path.append(node)
                node = parent[node]
            path.append(start_rc)
            path.reverse()
            return path

        if curr_rc in closed_set:
            continue
        closed_set.add(curr_rc)

        # Generate neighbor candidates at configured grid_step
        neighbors = []
        for dr in (-grid_step, 0, grid_step):
            for dc in (-grid_step, 0, grid_step):
                if dr == 0 and dc == 0:
                    continue
                neighbors.append((curr_r + dr, curr_c + dc))

        # Snap directly to goal_rc if within one step
        if abs(curr_r - goal_r) <= grid_step and abs(curr_c - goal_c) <= grid_step:
            if goal_rc not in neighbors:
                neighbors.append(goal_rc)

        p_rc = parent[curr_rc]
        lon_p, lat_p = rowcol_to_lonlat(*p_rc)
        lon_c, lat_c = rowcol_to_lonlat(*curr_rc)

        for neighbor_rc in neighbors:
            if neighbor_rc in closed_set or not allowed_proxy[neighbor_rc]:
                continue

            lon_n, lat_n = rowcol_to_lonlat(*neighbor_rc)

            if is_line_clear(p_rc[0], p_rc[1], neighbor_rc[0], neighbor_rc[1], allowed_proxy):
                # Path 2: direct line-of-sight from parent
                tentative_g = g_score[p_rc] + compute_distance((lon_p, lat_p), (lon_n, lat_n))
                candidate_parent = p_rc
            else:
                # Path 1: step from current node
                tentative_g = g_score[curr_rc] + compute_distance((lon_c, lat_c), (lon_n, lat_n))
                candidate_parent = curr_rc

            if tentative_g < g_score.get(neighbor_rc, float("inf")):
                g_score[neighbor_rc] = tentative_g
                parent[neighbor_rc] = candidate_parent
                h = compute_distance((lon_n, lat_n), (lon_g, lat_g))
                heapq.heappush(open_set, (tentative_g + h, neighbor_rc[0], neighbor_rc[1]))

    raise RuntimeError(f"Theta* failed to find a valid path within {max_iters} iterations.")

def get_terminal_min_alt(reader, coord, horizontal_buffer_nm, clearance):
    """Scans the horizontal buffer around an airport to find its local terrain peak."""
    lon, lat = coord
    center_rc = lonlat_to_rowcol(lon, lat)
    offsets = build_buffer_offsets(horizontal_buffer_nm, lat)

    max_elev_ft = 0.0
    for dr, dc in offsets:
        rc = (center_rc[0] + dr, center_rc[1] + dc)
        lon_c, lat_c = rowcol_to_lonlat(rc[0], rc[1])
        elev_m = reader.get_elevation(lon_c, lat_c)
        if elev_m is not None and elev_m > 0:
            elev_ft = elev_m * M_TO_FT
            if elev_ft > max_elev_ft:
                max_elev_ft = elev_ft
    return max_elev_ft + clearance

def plan(globe_data_dir, A, B, cruise_altitude, clearance, horizontal_buffer_nm=1.0, grid_step=1, max_iters=150000):
    """Plans a terrain-aware route between A and B using feet and nautical miles."""
    reader = PythonGlobeReader(globe_data_dir)

    start_rc = lonlat_to_rowcol(A[0], A[1])
    goal_rc = lonlat_to_rowcol(B[0], B[1])

    mid_lat = 0.5 * (A[1] + B[1])
    buffer_offsets = build_buffer_offsets(horizontal_buffer_nm, mid_lat)

    # Initialize caches here before any proxy or terminal checks use them
    cell_elev_cache = {}
    passable_cache = {start_rc: True, goal_rc: True}

    def get_cell_elev_ft(rc):
        if rc not in cell_elev_cache:
            lon, lat = rowcol_to_lonlat(rc[0], rc[1])
            elev_m = reader.get_elevation(lon, lat)
            if elev_m is None or elev_m == reader.ELEVATION_INVALID:
                cell_elev_cache[rc] = None
            elif elev_m == reader.ELEVATION_OCEAN or elev_m <= -500:
                cell_elev_cache[rc] = 0.0
            else:
                cell_elev_cache[rc] = elev_m * M_TO_FT
        return cell_elev_cache[rc]

    # Evaluate absolute minimum altitude required for departure & destination buffers
    dep_min_alt = get_terminal_min_alt(reader, A, horizontal_buffer_nm, clearance)
    dest_min_alt = get_terminal_min_alt(reader, B, horizontal_buffer_nm, clearance)
    required_floor = max(dep_min_alt, dest_min_alt)

    # Auto-override and round up to the nearest 100 ft if cruise altitude is too low
    if cruise_altitude < required_floor:
        override_alt = math.ceil(required_floor / 100.0) * 100.0
        print(f"\n\033[3m[DISPATCH NOTICE] Cruise altitude ({cruise_altitude:.0f} ft) is below the terminal buffer floor ({required_floor:.0f} ft).\033[0m")
        print(f"\033[3m --> Automatically adjusting cruise altitude to safe minimum: {override_alt:.0f} ft\033[0m <--\n")
        cruise_altitude = override_alt

    class AllowedProxy:
        def __getitem__(self, rc):
            if rc in passable_cache:
                return passable_cache[rc]

            r, c = rc
            for dr, dc in buffer_offsets:
                elev_ft = get_cell_elev_ft((r + dr, c + dc))
                if elev_ft is None or (elev_ft + clearance) >= cruise_altitude:
                    passable_cache[rc] = False
                    return False

            passable_cache[rc] = True
            return True

    allowed_proxy = AllowedProxy()

    grid_path = theta_star(start_rc, goal_rc, allowed_proxy, grid_step=grid_step, max_iters=max_iters)

    # Preserve exact departure/destination coordinates at endpoints
    coords = [A] + [rowcol_to_lonlat(r, c) for r, c in grid_path[1:-1]] + [B]
    return coords, cruise_altitude  # Return updated cruise altitude so exporter uses the new value!

def route_details(route_coords):
    """Prints flight legs information."""
    total_dist = 0.0
    for i in range(len(route_coords) - 1):
        p1 = route_coords[i]
        p2 = route_coords[i + 1]
        az1, _, dist = GEOD.inv(p1[0], p1[1], p2[0], p2[1])
        heading = (az1 + 360) % 360
        total_dist += dist / 1000.0
        print(f"Leg {i + 1}: Heading {heading:.1f}°, Distance {dist / 1000.0:.2f} km ({dist / 1852.0:.1f} nm)")
    print(f"Total Route Distance: {total_dist:.2f} km ({total_dist / 1.852:.1f} nm)")

_GLOBAL_AIRPORTS_CACHE = {}


def _lookup_lnm_sqlite(db_path, ident):
    expanded = os.path.expanduser(db_path)
    if not os.path.exists(expanded):
        raise FileNotFoundError(f"LNM SQLite database not found: {expanded}")

    conn = sqlite3.connect(expanded)
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT lonx, laty FROM airport WHERE UPPER(ident) = UPPER(?) LIMIT 1",
            (ident.strip(),),
        )
        row = cur.fetchone()
    finally:
        conn.close()

    if not row or row[0] is None or row[1] is None:
        raise ValueError(f"Airport '{ident}' not found in LNM database: {expanded}")
    return (float(row[0]), float(row[1]))


def _lookup_global_csv(db_url, ident):
    if db_url not in _GLOBAL_AIRPORTS_CACHE:
        with urllib.request.urlopen(db_url, timeout=15) as resp:
            text = resp.read().decode("utf-8")

        airports = {}
        reader = csv.DictReader(io.StringIO(text))
        for row in reader:
            lon = row.get("longitude_deg")
            lat = row.get("latitude_deg")
            if not lon or not lat:
                continue
            coord = (float(lon), float(lat))
            for field in ("ident", "gps_code", "iata_code"):
                code = (row.get(field) or "").strip().upper()
                if code and code not in airports:
                    airports[code] = coord
        _GLOBAL_AIRPORTS_CACHE[db_url] = airports

    target = ident.strip().upper()
    coord = _GLOBAL_AIRPORTS_CACHE[db_url].get(target)
    if coord is None:
        raise ValueError(f"Airport '{ident}' not found in global CSV: {db_url}")
    return coord

def resolve_airport_coord(ident, config):
    config = config or {}
    raw_lnm_db = config.get("LNM_DB")
    db_url = (config.get("DB_URL") or "").strip()

    lnm_error = None
    if raw_lnm_db and str(raw_lnm_db).strip():
        expanded_db = os.path.expanduser(os.path.expandvars(str(raw_lnm_db).strip()))
        if os.path.exists(expanded_db):
            try:
                return _lookup_lnm_sqlite(expanded_db, ident)
            except ValueError as exc:
                lnm_error = exc

    if db_url:
        try:
            return _lookup_global_csv(db_url, ident)
        except Exception as exc:
            raise RuntimeError(
                f"Could not resolve '{ident}' from LNM_DB and DB_URL lookup failed "
                f"(check your internet connection): {exc}"
            ) from exc

    if lnm_error is not None:
        raise lnm_error

    raise RuntimeError(
        f"Could not resolve '{ident}': LNM_DB is not available and DB_URL is not configured "
        f"(or there are internet problems)."
    )

def parse_saved_lnmpln(filepath, config=None):
    """Extracts cruise alt, departure, and destination coords/idents from a saved lnmpln file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    alt_match = re.search(r"<CruisingAlt>(.*?)</CruisingAlt>", content)
    cruising_alt = float(alt_match.group(1)) if alt_match and alt_match.group(1).strip() else None

    ident_matches = re.findall(r"<Ident>(.*?)</Ident>", content)
    dep_ident = ident_matches[0].strip() if ident_matches else "DEP"
    dest_ident = ident_matches[-1].strip() if ident_matches else "DEST"

    pos_matches = re.findall(r'<Pos\s+[^>]*[Ll]on="([^"]+)"\s+[^>]*[Ll]at="([^"]+)"', content)
    if not pos_matches:
        pos_matches = re.findall(r'<Pos\s+[^>]*[Ll]at="([^"]+)"\s+[^>]*[Ll]on="([^"]+)"', content)
        if pos_matches:
            pos_matches = [(m[1], m[0]) for m in pos_matches]

    if len(pos_matches) >= 2:
        start_coord = (float(pos_matches[0][0]), float(pos_matches[0][1]))
        goal_coord = (float(pos_matches[-1][0]), float(pos_matches[-1][1]))
    elif config is not None:
        start_coord = resolve_airport_coord(dep_ident, config)
        goal_coord = resolve_airport_coord(dest_ident, config)
    else:
        raise ValueError("Saved lnmpln must contain at least departure and destination positions.")

    return cruising_alt, dep_ident, dest_ident, start_coord, goal_coord

def parse_saved_fgfp(filepath, config=None):
    """Extracts cruise alt, departure, and destination coords/idents from a saved fgfp file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    dep_match = re.search(r"<departure>\s*<airport[^>]*>([^<]+)</airport>\s*</departure>", content)
    dest_match = re.search(r"<destination>\s*<airport[^>]*>([^<]+)</airport>\s*</destination>", content)

    dep_ident = dep_match.group(1).strip() if dep_match else "DEP"
    dest_ident = dest_match.group(1).strip() if dest_match else "DEST"

    cruise_match = re.search(r'<cruise>\s*<altitude-ft[^>]*>([\d\.]+)</altitude-ft>', content)
    if not cruise_match:
        cruise_match = re.search(r'<altitude-ft[^>]*>([\d\.]+)</altitude-ft>', content)

    cruising_alt = float(cruise_match.group(1)) if cruise_match else None

    lons = re.findall(r'<lon type="double">([\d\.-]+)</lon>', content)
    lats = re.findall(r'<lat type="double">([\d\.-]+)</lat>', content)

    if len(lons) >= 2 and len(lats) >= 2:
        start_coord = (float(lons[0]), float(lats[0]))
        goal_coord = (float(lons[-1]), float(lats[-1]))
        return cruising_alt, dep_ident, dest_ident, start_coord, goal_coord

    if config is not None:
        start_coord = resolve_airport_coord(dep_ident, config)
        goal_coord = resolve_airport_coord(dest_ident, config)
        return cruising_alt, dep_ident, dest_ident, start_coord, goal_coord

    raise ValueError("Saved fgfp must contain at least departure and destination coordinates.")

def update_lnmpln_file(filepath, full_route_coords, cruising_alt, dep_ident, dest_ident, start_coord, goal_coord):
    """Updates the saved Little Navmap file in-place with contour waypoints while preserving comments."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    if "<CruisingAlt>" in content:
        content = re.sub(r"<CruisingAlt>.*?</CruisingAlt>", f"<CruisingAlt>{int(cruising_alt)}</CruisingAlt>", content)
        content = re.sub(r"<CruisingAltF>.*?</CruisingAltF>", f"<CruisingAltF>{cruising_alt:.8f}</CruisingAltF>", content)
    else:
        # If cruising alt header tags are missing, inject them inside <Header>
        cruising_block = f"      <CruisingAlt>{int(cruising_alt)}</CruisingAlt>\n      <CruisingAltF>{cruising_alt:.8f}</CruisingAltF>\n"
        content = re.sub(r"(<Header>)", f"\\1\n{cruising_block}", content)

    new_waypoints_lines = ["  <Waypoints>"]
    new_waypoints_lines.append(
        f"      <Waypoint>\n"
        f"        <Name>Departure</Name>\n"
        f"        <Ident>{dep_ident}</Ident>\n"
        f"        <Type>AIRPORT</Type>\n"
        f'        <Pos Lon="{start_coord[0]:.6f}" Lat="{start_coord[1]:.6f}" Alt="0.00"/>\n'
        f"      </Waypoint>"
    )
    for idx, (lon, lat) in enumerate(full_route_coords[1:-1]):
        new_waypoints_lines.append(
            f"      <Waypoint>\n"
            f"        <Name>THETA_CORRIDOR_{idx + 1}</Name>\n"
            f"        <Ident>T{idx + 1:02d}</Ident>\n"
            f"        <Type>USER</Type>\n"
            f'        <Pos Lon="{lon:.6f}" Lat="{lat:.6f}" Alt="{cruising_alt:.2f}"/>\n'
            f"      </Waypoint>"
        )
    new_waypoints_lines.append(
        f"      <Waypoint>\n"
        f"        <Name>Destination</Name>\n"
        f"        <Ident>{dest_ident}</Ident>\n"
        f"        <Type>AIRPORT</Type>\n"
        f'        <Pos Lon="{goal_coord[0]:.6f}" Lat="{goal_coord[1]:.6f}" Alt="0.00"/>\n'
        f"      </Waypoint>"
    )
    new_waypoints_lines.append("  </Waypoints>")

    new_waypoints_block = "\n".join(new_waypoints_lines)
    content = re.sub(r"<Waypoints>.*?</Waypoints>", new_waypoints_block, content, flags=re.DOTALL)

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

def update_fgfp_file(filepath, full_route_coords, cruising_alt, dep_ident, dest_ident, start_coord, goal_coord):
    """Updates the saved FlightGear FGFP file in-place, preserving remarks and metadata."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    cruise_block = (
        f"  <cruise>\n"
        f'    <altitude-ft type="int">{int(cruising_alt)}</altitude-ft>\n'
        f'    <knots type="int">100</knots>\n'
        f"  </cruise>"
    )
    if "<cruise>" in content:
        content = re.sub(r"<cruise>.*?</cruise>", cruise_block, content, flags=re.DOTALL)
    else:
        content = re.sub(r"(<destination>.*?</destination>)", r"\1\n" + cruise_block, content, flags=re.DOTALL)

    wp_xmls = [
        f'    <wp>\n      <type type="string">navaid</type>\n'
        f'      <departure type="bool">true</departure>\n'
        f'      <ident type="string">{dep_ident}</ident>\n'
        f'      <lon type="double">{start_coord[0]:.8f}</lon>\n'
        f'      <lat type="double">{start_coord[1]:.8f}</lat>\n    </wp>'
    ]
    for idx, (lon, lat) in enumerate(full_route_coords[1:-1]):
        wp_xmls.append(
            f'    <wp n="{idx + 1}">\n      <type type="string">basic</type>\n'
            f'      <alt-restrict type="string">at</alt-restrict>\n'
            f'      <altitude-ft type="double">{cruising_alt}</altitude-ft>\n'
            f'      <ident type="string">T{idx + 1:02d}</ident>\n'
            f'      <lon type="double">{lon:.8f}</lon>\n'
            f'      <lat type="double">{lat:.8f}</lat>\n    </wp>'
        )
    wp_xmls.append(
        f'    <wp n="{len(full_route_coords) - 1}">\n'
        f'      <type type="string">navaid</type>\n'
        f'      <approach type="bool">true</approach>\n'
        f'      <ident type="string">{dest_ident}</ident>\n'
        f'      <lon type="double">{goal_coord[0]:.8f}</lon>\n'
        f'      <lat type="double">{goal_coord[1]:.8f}</lat>\n    </wp>'
    )

    new_route_block = "  <route>\n" + "\n".join(wp_xmls) + "\n  </route>"
    if "<route>" in content:
        content = re.sub(r"<route>.*?</route>", new_route_block, content, flags=re.DOTALL)
    else:
        content = content.strip() + "\n" + new_route_block + "\n"

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

def parse_cli_args(argv):
    """Parses optional altitude (float) and plan file path in any order, plus --file/-f."""
    cli_cruise_alt = None
    plan_path = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg.startswith("--file="):
            plan_path = arg.split("=", 1)[1].strip()
        elif arg in ("--file", "-f"):
            if i + 1 >= len(argv):
                raise ValueError(f"Missing path value after {arg}.")
            i += 1
            plan_path = argv[i].strip()
        else:
            # Try numeric cruise altitude first
            try:
                val = float(arg)
                if math.isnan(val) or math.isinf(val):
                    raise ValueError("Altitude must be a finite number.")
                if cli_cruise_alt is not None:
                    raise ValueError(f"Duplicate cruise altitude argument: '{arg}'.")
                cli_cruise_alt = val
            except ValueError:
                if plan_path is not None:
                    raise ValueError(f"Unexpected or duplicate argument: '{arg}'.")
                plan_path = arg
        i += 1

    return plan_path, cli_cruise_alt

if __name__ == "__main__":
    raw_argv = sys.argv[1:]
    if "-h" in raw_argv or "--help" in raw_argv:
        print("Usage: contour_route.py [ALT_FT] [PATH/TO/PLAN.{lnmpln,fgfp}] [--file=PATH] [--step=N] [--max-iters=N]")
        print("Options:")
        print("  -h, --help          Show this help message and exit.")
        print("  --step, --grid-step Override grid_step from config.json (integer >= 1; higher = faster, coarser).")
        print("  --max-iters         Override max_iters from config.json (integer >= 1; higher = slower, full grid resolution).")
        sys.exit(0)

    script_dir = os.path.dirname(os.path.abspath(__file__))
    config_file = os.path.join(script_dir, "config.json")
    if os.path.exists(config_file):
        with open(config_file, "r", encoding="utf-8") as f:
            config = json.load(f)
    else:
        config = {
            "globe_data_dir": "GLOBE Elevation Data/all10",
            "clearance": 300,
            "horizontal_buffer_nm": 1.0,
            "grid_step": 1,
            "max_iters": 150000,
        }

    globe_dir = os.path.expanduser(config["globe_data_dir"])
    clearance = float(config.get("clearance", 300))
    horizontal_buffer_nm = float(config.get("horizontal_buffer_nm", 1.0))

    raw_default_alt = config.get("default_cruise_alt_ft")
    default_cruise_alt_ft = float(raw_default_alt) if raw_default_alt is not None else None

    def _parse_pos_int_token(val_str, flag_name):
        try:
            # Reject floats like "1.5" or strings like "10nm"
            parsed = int(val_str)
            if str(parsed) != val_str.strip() or parsed < 1:
                raise ValueError()
            return parsed
        except ValueError:
            raise ValueError(f"{flag_name} must be an integer >= 1, got '{val_str}'.")

    cli_grid_step = None
    cli_max_iters = None
    filtered_argv = []
    i = 0
    try:
        while i < len(raw_argv):
            tok = raw_argv[i]
            if tok == "--step" or tok == "--grid-step":
                if i + 1 >= len(raw_argv):
                    raise ValueError(f"{tok} requires an integer value.")
                cli_grid_step = _parse_pos_int_token(raw_argv[i + 1], tok)
                i += 2
            elif tok.startswith("--step=") or tok.startswith("--grid-step="):
                flag_name, val_str = tok.split("=", 1)
                cli_grid_step = _parse_pos_int_token(val_str, flag_name)
                i += 1
            elif tok == "--max-iters":
                if i + 1 >= len(raw_argv):
                    raise ValueError("--max-iters requires an integer value.")
                cli_max_iters = _parse_pos_int_token(raw_argv[i + 1], "--max-iters")
                i += 2
            elif tok.startswith("--max-iters="):
                _, val_str = tok.split("=", 1)
                cli_max_iters = _parse_pos_int_token(val_str, "--max-iters")
                i += 1
            else:
                filtered_argv.append(tok)
                i += 1

        raw_plan_arg, cli_cruise_alt = parse_cli_args(filtered_argv)
    except ValueError as e:
        print(f"\n[CLI ERROR] {e}")
        print("Usage: contour_route.py [ALT_FT] [PATH/TO/PLAN.{lnmpln,fgfp}] (or --file=PATH) [--step=N] [--max-iters=N]")
        sys.exit(1)

    grid_step = cli_grid_step if cli_grid_step is not None else int(config.get("grid_step", 1))
    max_iters = cli_max_iters if cli_max_iters is not None else int(config.get("max_iters", 150000))

    if grid_step < 1:
        raise ValueError(f"grid_step in config.json must be an integer >= 1, got {grid_step}.")
    if max_iters < 1:
        raise ValueError(f"max_iters in config.json must be an integer >= 1, got {max_iters}.")

    custom_plan_mode = raw_plan_arg is not None

    if custom_plan_mode:
        expanded_plan = os.path.abspath(os.path.expanduser(os.path.expandvars(raw_plan_arg)))
        ext = os.path.splitext(expanded_plan)[1].lower()
        if ext not in (".lnmpln", ".fgfp"):
            print(f"\n[CLI ERROR] Unsupported flight plan extension '{ext or '(none)'}'. Expected .lnmpln or .fgfp.")
            sys.exit(1)
        if not os.path.exists(expanded_plan):
            raise FileNotFoundError(f"Flight plan file not found: {expanded_plan}")

        stem, _ = os.path.splitext(expanded_plan)
        target_lnmpln = f"{stem}.lnmpln"
        target_fgfp = f"{stem}.fgfp"

        print("\n\033[3m[WARNING] External plan mode: ONLY departure and destination endpoints are preserved;\033[0m")
        print("\033[3m          any intermediate waypoints/legs will be replaced by the contour corridor.\033[0m\n")

        if ext == ".lnmpln":
            print(f"Reading flight plan from LNM source: {expanded_plan}...")
            file_cruise_alt, ident_a, ident_b, start_coord, goal_coord = parse_saved_lnmpln(expanded_plan, config)
        else:
            print(f"Reading flight plan from FlightGear source: {expanded_plan}...")
            file_cruise_alt, ident_a, ident_b, start_coord, goal_coord = parse_saved_fgfp(expanded_plan, config)
    else:
        raw_db_dir = config.get("DB_DIR") or "~/.cache/flight_dispatch"
        briefing_dir = os.path.expanduser(os.path.expandvars(str(raw_db_dir).strip()))

        target_lnmpln = os.path.join(briefing_dir, "briefing.lnmpln")
        target_fgfp = os.path.join(briefing_dir, "briefing.fgfp")

        # 1. Read input from whichever saved briefing format is available
        if os.path.exists(target_lnmpln):
            print(f"Reading flight plan from LNM source: {target_lnmpln}...")
            file_cruise_alt, ident_a, ident_b, start_coord, goal_coord = parse_saved_lnmpln(target_lnmpln, config)
        elif os.path.exists(target_fgfp):
            print(f"Reading flight plan from FlightGear source: {target_fgfp}...")
            file_cruise_alt, ident_a, ident_b, start_coord, goal_coord = parse_saved_fgfp(target_fgfp, config)
        else:
            raise FileNotFoundError(
                f"No flight plan found at {target_lnmpln} or {target_fgfp}."
            )

    # Priority: CLI override > briefing/plan file altitude > config.json default_cruise_alt_ft
    if cli_cruise_alt is not None:
        cruise_alt = cli_cruise_alt
    elif file_cruise_alt is not None:
        cruise_alt = file_cruise_alt
    elif default_cruise_alt_ft is not None:
        cruise_alt = default_cruise_alt_ft
    else:
        raise ValueError("No cruise altitude in CLI, flight plan file, or config.json ('default_cruise_alt_ft').")

    # 2. Compute Theta* terrain-aware path
    print(
        f"Computing Theta* route from {ident_a} {start_coord} to {ident_b} {goal_coord} "
        f"at {cruise_alt:.0f} ft\n"
        f"(Vertical clearance: {clearance:.0f} ft, "
        f"Horizontal buffer: {horizontal_buffer_nm} nm, Grid step: {grid_step})..."
    )

    try:
        route_coords, cruise_alt = plan(
            globe_data_dir=globe_dir,
            A=start_coord,
            B=goal_coord,
            cruise_altitude=cruise_alt,
            clearance=clearance,
            horizontal_buffer_nm=horizontal_buffer_nm,
            grid_step=grid_step,
            max_iters=max_iters,
        )
    except RuntimeError as e:
        print(
            f"\n[DISPATCH ERROR] Pathfinding failed: {e}\n"
            "Tip: Increase integer step (--step, faster / less accurate) or "
            "max_iters (--max-iters, slower / lossless grid resolution at step=1)."
        )
        sys.exit(1)

    print(f"Route calculated successfully with {len(route_coords)} waypoints.")
    route_details(route_coords)

    # 3. Unconditionally export/update BOTH formats in-place
    if not os.path.exists(target_lnmpln):
        base_lnm = (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<LittleNavmap xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
            'xsi:noNamespaceSchemaLocation="https://www.littlenavmap.org/schema/lnmpln.xsd">\n'
            "  <Flightplan>\n    <Header>\n"
            f"      <CruisingAlt>{int(cruise_alt)}</CruisingAlt>\n"
            f"      <CruisingAltF>{cruise_alt:.8f}</CruisingAltF>\n"
            "      <Comment>Generated with Contour-Flight Router</Comment>\n"
            "    </Header>\n    <Waypoints>\n    </Waypoints>\n  </Flightplan>\n"
            "</LittleNavmap>"
        )
        with open(target_lnmpln, "w", encoding="utf-8") as f:
            f.write(base_lnm)

    update_lnmpln_file(
        filepath=target_lnmpln,
        full_route_coords=route_coords,
        cruising_alt=cruise_alt,
        dep_ident=ident_a,
        dest_ident=ident_b,
        start_coord=start_coord,
        goal_coord=goal_coord,
    )
    print(f"-> Synchronized Little Navmap format: {target_lnmpln}")

    if not os.path.exists(target_fgfp):
        base_fgfp = (
            '<?xml version="1.0"?>\n<PropertyList>\n'
            '  <version type="int">2</version>\n'
            '  <is-route type="bool">true</is-route>\n'
            '  <flight-rules type="string">V</flight-rules>\n'
            '  <flight-type type="string">X</flight-type>\n'
            f'  <departure>\n    <airport type="string">{ident_a}</airport>\n  </departure>\n'
            f'  <destination>\n    <airport type="string">{ident_b}</airport>\n  </destination>\n'
            "  <route>\n  </route>\n</PropertyList>"
        )
        with open(target_fgfp, "w", encoding="utf-8") as f:
            f.write(base_fgfp)

    update_fgfp_file(
        filepath=target_fgfp,
        full_route_coords=route_coords,
        cruising_alt=cruise_alt,
        dep_ident=ident_a,
        dest_ident=ident_b,
        start_coord=start_coord,
        goal_coord=goal_coord,
    )
    print(f"-> Synchronized FlightGear format: {target_fgfp}")
