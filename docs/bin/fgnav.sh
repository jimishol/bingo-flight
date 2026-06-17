#!/bin/bash
# fgnav.sh - Companion Suite Orchestration Script

# 1. Spawn FGconnect server in the background
cd "$HOME/path/to/fgconnect" || exit 1
python3 gui_tk.py &
sleep 1

# Optional: Window manager rules (e.g., Hyprland workspace pinning)
# hyprctl dispatch movetoworkspacesilent special:magic

# 2. Open Little Navmap in the foreground (blocking execution thread)
cd "$HOME/path/to/littlenavmap_folder" || exit 1
./littlenavmap "$HOME/.cache/flight_dispatch/briefing.lnmpln"

# 3. Clean up telemetry hooks automatically upon map exit
pkill -f gui_tk.py
