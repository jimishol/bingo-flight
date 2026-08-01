#!/usr/bin/env python3
import sys
import os
import re
import gzip

# ==============================================================================
# CONFIGURATION
# ==============================================================================

SOURCE_AIRAC_FILE = "nav_AIRAC.dat"
OUTPUT_DIR = "/mnt/data/games/Flightgear/NavData_Override/NavData/nav"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "nav.dat")

FG_ROOT = os.environ.get("FG_ROOT", "/usr/share/flightgear")
SYSTEM_APT_GZ = os.path.join(FG_ROOT, "Airports", "apt.dat.gz")
FG_HOME = os.environ.get("FG_HOME", os.path.expanduser("~/.fgfs"))

# Row codes for ILS (4), GS (6), and DME-ILS (12)
ILS_ROW_CODES = {"4", "6", "12"}


def open_system_gz(path):
    if os.path.exists(path):
        return gzip.open(path, 'rt', encoding='latin1', errors='ignore')
    uncompressed = path.replace(".gz", "")
    if os.path.exists(uncompressed):
        return open(uncompressed, 'r', encoding='latin1', errors='ignore')
    return None


def build_stock_runway_map():
    """Builds a map of { 'ICAO': ['10', '28', ...] } from stock apt.dat"""
    f = open_system_gz(SYSTEM_APT_GZ)
    if not f:
        print(f"Error: Could not open stock apt.dat at '{SYSTEM_APT_GZ}'!")
        sys.exit(1)

    stock_runways = {}
    current_icao = None

    with f:
        for line in f:
            tokens = line.strip().split()
            if not tokens:
                continue

            code = tokens[0]
            if code in ('1', '16', '17') and len(tokens) >= 5:
                current_icao = tokens[4]
                if current_icao not in stock_runways:
                    stock_runways[current_icao] = set()

            # FIX: In apt.dat row 100, reciprocal runway identifier is at index 17
            elif code == '100' and current_icao and len(tokens) >= 18:
                stock_runways[current_icao].add(tokens[8])
                stock_runways[current_icao].add(tokens[17])

    print(f"Loaded stock runway definitions for {len(stock_runways)} airports.")
    return stock_runways


def get_rwy_num(rwy_str):
    """Extracts integer heading from runway string ('28C' -> 28, '09L' -> 9)."""
    m = re.match(r'^0*(\d{1,2})[LRCrc]?$', rwy_str)
    return int(m.group(1)) if m else None


def find_best_stock_runway(airac_rwy, stock_set):
    """
    Finds the best runway in stock_set for airac_rwy:
    1. Exact match ('28' == '28')
    2. Suffix strip match ('28C' -> '28')
    3. Nearest heading match within +/- 2 numbers ('27' -> '28', '27R' -> '28L')
    """
    if airac_rwy in stock_set:
        return airac_rwy

    # 1. Strip suffix (e.g., '28C' -> '28', '28L' -> '28')
    stripped = re.sub(r'[LRCrc]$', '', airac_rwy)
    if stripped in stock_set:
        return stripped
        
    # Handle single digit zeroes (e.g. '9' vs '09') safely
    if stripped.zfill(2) in stock_set:
        return stripped.zfill(2)

    airac_num = get_rwy_num(airac_rwy)
    if airac_num is None:
        return None

    # 2. Search for closest numerical match in stock_set
    best_candidate = None
    min_diff = 999

    for stock_rwy in stock_set:
        stock_num = get_rwy_num(stock_rwy)
        if stock_num is not None:
            # Handle magnetic variation crossover (e.g. 36 vs 01)
            diff = abs(airac_num - stock_num)
            if diff > 18:
                diff = 36 - diff

            # Only match if headings are within 2 numbers (~20 degrees)
            if diff <= 2 and diff < min_diff:
                min_diff = diff
                best_candidate = stock_rwy

    return best_candidate


def replace_token_in_line(line, target_idx, new_value):
    """
    FIX: Replaces the nth non-whitespace token in a string 
    while preserving all original formatting and whitespaces.
    """
    parts = re.split(r'(\s+)', line)
    token_count = 0
    for i, part in enumerate(parts):
        if not part.isspace() and part != '':
            if token_count == target_idx:
                parts[i] = new_value
                break
            token_count += 1
    return "".join(parts)


def patch_airac_ils():
    stock_runways = build_stock_runway_map()

    abs_source = os.path.abspath(SOURCE_AIRAC_FILE)
    abs_output = os.path.abspath(OUTPUT_FILE)

    if not os.path.exists(abs_source):
        print(f"Error: Source AIRAC file '{abs_source}' not found!")
        sys.exit(1)

    print(f"\nReading AIRAC: {abs_source}")
    print(f"Writing output to: {abs_output}\n")

    patched_lines = []
    modified_count = 0

    with open(abs_source, 'r', encoding='latin1', errors='ignore') as f:
        for line in f:
            tokens = line.strip().split()
            if not tokens or tokens[0] not in ILS_ROW_CODES:
                patched_lines.append(line)
                continue

            # Look for airport ICAO token in the row
            icao = None
            icao_idx = -1
            for idx, token in enumerate(tokens):
                if token in stock_runways:
                    icao = token
                    icao_idx = idx
                    break

            if icao and icao_idx != -1:
                stock_set = stock_runways[icao]

                # Inspect tokens following ICAO to find the runway identifier
                for target_idx in range(icao_idx + 1, len(tokens)):
                    candidate_rwy = tokens[target_idx]
                    
                    # Check if token looks like a runway identifier (e.g. 28C, 09L, 27)
                    if re.match(r'^\d{1,2}[LRCrc]?$', candidate_rwy):
                        best_match = find_best_stock_runway(candidate_rwy, stock_set)

                        if best_match and best_match != candidate_rwy:
                            print(f"  Fixing {icao}: '{candidate_rwy}' -> '{best_match}'")
                            # Swap out the token gracefully without crushing whitespace
                            line = replace_token_in_line(line, target_idx, best_match)
                            modified_count += 1
                        break  # Found and processed the runway token

            patched_lines.append(line)

    # Save to final override path
    os.makedirs(os.path.dirname(abs_output), exist_ok=True)
    with open(abs_output, 'w', encoding='latin1') as out:
        out.writelines(patched_lines)

    print("\n--- Summary ---")
    print(f"Successfully modified {modified_count} runway records.")
    print(f"Saved directly to: {abs_output}")
    

if __name__ == "__main__":
    patch_airac_ils()
