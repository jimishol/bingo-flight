#!/bin/bash

# Start FGconnect in background
cd ~/games/git/fgconnect || exit 1
python3 gui_tk.py &
sleep 1
hyprctl dispatch movetoworkspacesilent special:magic

# Start Little Navmap in foreground (blocking)
cd ~/games/flightgear-navigation_tools/LittleNavmap-linux-ubuntu-24.04-3.0.18 || exit 1
./littlenavmap

# When Little Navmap closes, kill FGconnect
pkill -f gui_tk.py
