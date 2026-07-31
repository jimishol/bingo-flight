#!/usr/bin/env python3
import requests
import gzip
import re
import os
import sys

BASE = "https://tgftp.nws.noaa.gov/data/observations/metar/cycles/"
ICAO_RE = re.compile(r"^[A-Z]{4}", re.MULTILINE)

# CONFIG: minimum number of cycles an airport must appear in (1–24)
FILTER_COUNT = 12   # 1 = current behavior, higher = more stable lists

# CONFIG: number of ICAO codes to display per row in terminal output
COLS_PER_LINE = 8

# CONFIG: FlightGear METAR capability file
FG_METAR_PATH = "/usr/share/flightgear/Airports/metar.dat.gz"

# CONFIG: Logging
LOG_ENABLED = False
LOG_FILE = "metar_update.log"

# NOTE:
# On openSUSE the correct group is usually "users".
# If your system uses a different primary group, you must adjust it manually.
# The script only checks read/write access, not the group name.


def log(msg):
    """Print to console and optionally append to log file."""
    print(msg)
    if LOG_ENABLED:
        try:
            with open(LOG_FILE, "a") as lf:
                lf.write(msg + "\n")
        except Exception as e:
            print(f"WARNING: Failed to write log file: {e}")


def log_icao_grid(label, icaos, prefix="+ ", cols=COLS_PER_LINE):
    """Format a list of ICAOs into rows with multiple items per line."""
    if not icaos:
        return
    log(f"\n{label}:")
    for i in range(0, len(icaos), cols):
        chunk = icaos[i : i + cols]
        log(f"  {prefix}" + "  ".join(chunk))


def fetch_cycle(hour):
    url = f"{BASE}{hour:02d}Z.TXT"
    log(f"Fetching {url} ...")
    try:
        return requests.get(url, timeout=10).text
    except Exception as e:
        log(f"Failed to fetch {url}: {e}")
        return ""


def extract_icaos(text):
    return ICAO_RE.findall(text)


def load_fg_metar():
    """Load ICAOs from FG's metar.dat.gz."""
    if not os.path.exists(FG_METAR_PATH):
        return None

    old_icaos = set()
    try:
        with gzip.open(FG_METAR_PATH, "rb") as gz:
            for line in gz:
                line = line.decode("utf-8").strip()
                if line and not line.startswith("#"):
                    old_icaos.add(line)
        return old_icaos
    except Exception as e:
        log(f"ERROR: Failed to read FG METAR file: {e}")
        return None


def show_help():
    """Print help instructions and usage examples."""
    help_text = f"""
FlightGear METAR Capabilities Updater

Usage:
  python3 {os.path.basename(sys.argv[0])} [OPTION | PREFIX]

Arguments:
  (No arguments)    Fetch cycles, show diff, and prompt [y/N] before updating.
  <PREFIX>          2-letter ICAO prefix (e.g., LG, eg). Auto-accepts the 
                    update ONLY if changes match the prefix. Otherwise skips update.
  -y, --yes         Auto-accept and replace metar.dat.gz on any detected changes.
  -h, --help        Display this help message and exit.

Examples:
  python3 {os.path.basename(sys.argv[0])}
  python3 {os.path.basename(sys.argv[0])} LG && fgfs --launcher
  python3 {os.path.basename(sys.argv[0])} -y && fgfs --launcher
"""
    print(help_text.strip() + "\n")
    sys.exit(0)


def parse_args():
    """Check for help, -y, or strictly a 2-letter ICAO prefix filter (e.g. 'LG', 'EG')."""
    prefix_filter = None
    auto_yes = False

    for arg in sys.argv[1:]:
        if arg in ("-h", "--help"):
            show_help()
        elif arg in ("-y", "--yes"):
            auto_yes = True
        elif len(arg) == 2 and arg.isalpha():
            prefix_filter = arg.upper()

    return prefix_filter, auto_yes


def main():

    # Parse CLI flags (Help, 2-letter prefix filter, or auto-yes)
    prefix_filter, auto_yes = parse_args()

    log(f"Checking FlightGear METAR file at:\n  {FG_METAR_PATH}\n")

    # Check existence
    if not os.path.exists(FG_METAR_PATH):
        log("ERROR: FlightGear METAR file not found.")
        log("Fix by installing FlightGear or correcting FG_METAR_PATH.")
        log("Aborting.\n")
        return

    # Check read permission
    if not os.access(FG_METAR_PATH, os.R_OK):
        log("ERROR: Cannot read FlightGear METAR file.")
        log("Fix with:")
        log(f"  sudo chmod 644 {FG_METAR_PATH}")
        log("Aborting.\n")
        return

    # Check write permission
    if not os.access(FG_METAR_PATH, os.W_OK):
        log("ERROR: Cannot write/replace FlightGear METAR file.")
        log("Fix with:")
        log(f"  sudo chown {os.getlogin()}:users {FG_METAR_PATH}")
        log(f"  sudo chmod 644 {FG_METAR_PATH}")
        log("")
        log("NOTE: If your system does not use 'users' as your primary group,")
        log("      you must replace 'users' with your correct group manually.")
        log("Aborting.\n")
        return

    log("FlightGear METAR file found and accessible.\n")

    # Load previous ICAO list from FG
    old_icaos = load_fg_metar()
    if old_icaos is None:
        log("ERROR: Could not load previous FG METAR file.")
        log("Aborting.\n")
        return

    # Count ICAO occurrences across all 24 cycles
    counts = {}

    for hour in range(24):
        text = fetch_cycle(hour)

        # HARD ABORT if any cycle fails
        if not text.strip():
            log("\nERROR: Failed to fetch one or more METAR cycle files.")
            log("Internet connection failed or NOAA TGFTP unreachable.")
            log("Aborting without updating FG METAR file.\n")
            return

        icaos = extract_icaos(text)
        for icao in icaos:
            counts[icao] = counts.get(icao, 0) + 1

    # Apply FILTER_COUNT threshold
    filtered_icaos = sorted([icao for icao, n in counts.items() if n >= FILTER_COUNT])
    new_icaos = set(filtered_icaos)

    # Report differences
    added = sorted(new_icaos - old_icaos)
    removed = sorted(old_icaos - new_icaos)

    log("\nMETAR capability changes since last FG version:")
    log(f"  Added:   {len(added)}")
    log(f"  Removed: {len(removed)}")

    # Grouped grid output
    log_icao_grid("Stations added", added, prefix="+ ")
    log_icao_grid("Stations removed", removed, prefix="- ")

    log("")

    # Header WITHOUT date (stable diff)
    header = (
        "# List of airports known to have METAR data available\n"
        "# Generated by generate_metar_dat.py\n"
        "# Source: NOAA TGFTP METAR cycles\n"
        "# https://tgftp.nws.noaa.gov/data/observations/metar/cycles/\n"
    )

    # If no changes, exit early
    if len(added) == 0 and len(removed) == 0:
        log("No changes detected. FlightGear METAR file is already up to date.\n")
        return

    # Determine whether to replace FG file
    if auto_yes:
        log("Auto-accepting replacement (-y flag).\n")
    elif prefix_filter:
        matching = [icao for icao in (added + removed) if icao.startswith(prefix_filter)]
        if matching:
            log(f"Auto-accepting update: Changes detected for prefix '{prefix_filter}' ({len(matching)} match(es)).\n")
        else:
            log(f"No changes matched prefix '{prefix_filter}'. Skipping replacement.\n")
            return
    else:
        # Ask user before replacing FG file (Original Behavior)
        answer = input("Do you want to replace FlightGear's metar.dat.gz? [y/N]: ").strip().lower()
        if answer != "y":
            log("User declined replacement. Exiting.\n")
            return

    # Write new metar.dat.gz directly into FG_ROOT
    try:
        with gzip.open(FG_METAR_PATH, "wb") as gz:
            gz.write(header.encode("utf-8"))
            for icao in filtered_icaos:
                gz.write((icao + "\n").encode("utf-8"))
    except Exception as e:
        log(f"ERROR: Failed to write FG METAR file: {e}")
        log("Aborting.\n")
        return

    log(f"Updated FG metar.dat.gz with {len(filtered_icaos)} airports "
        f"(FILTER_COUNT = {FILTER_COUNT}).\n")


if __name__ == "__main__":
    main()
