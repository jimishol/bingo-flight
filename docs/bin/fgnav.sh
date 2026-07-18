#!/bin/bash
# fgnav.sh - Companion Suite Orchestration Script

# 1. Spawn FGconnect server in the background (Standalone headless mode)
cd "$HOME/games/git/fgconnect" || exit 1
# Using -s starts the telemetry hooks automatically without a GUI
python3 fgconnect.py -s &
sleep 1

# 2. Open Little Navmap in the foreground (blocking execution thread)
cd "$HOME/games/flightgear-navigation_tools/LittleNavmap-linux-ubuntu-24.04-3.0.18" || exit 1
./littlenavmap "$HOME/.cache/flight_dispatch/briefing.lnmpln"

# 3. Clean up telemetry hooks automatically upon map exit
# Kill the headless background script instead of a GUI window instance
pkill -f "fgconnect.py -s"
