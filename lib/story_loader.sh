#!/usr/bin/env bash
# lib/story_loader.sh - strict loader: return story text only if file exists
# Usage: story=$(load_story "$VEHICLE_TIER" "$passengers" "$bag_class")

load_story() {
  local tier="$1" pax="$2" bag="$3"
  local base
  local candidate

  # search order: repo-local then user-local
  for base in "${SCRIPT_DIR:-.}/stories/en/small" "$HOME/my_github/bingo-flightgear/stories/en/small"; do
    # 1) canonical full pattern: <tier>__pax<pax>__bag<bag>.txt
    candidate="$base/${tier}__pax${pax}__bag${bag}.txt"
    [ -f "$candidate" ] && { cat "$candidate"; return 0; }

    # 2) short pattern you created: pax<pax>__bag<bag>.txt
    candidate="$base/pax${pax}__bag${bag}.txt"
    [ -f "$candidate" ] && { cat "$candidate"; return 0; }

    # 3) tier+bag pattern: <tier>__bag<bag>.txt
    candidate="$base/${tier}__bag${bag}.txt"
    [ -f "$candidate" ] && { cat "$candidate"; return 0; }

    # 4) generic tier file: <tier>.txt
    candidate="$base/${tier}.txt"
    [ -f "$candidate" ] && { cat "$candidate"; return 0; }
  done

  # Nothing found: return empty (no fallback)
  return 0
}

export -f load_story
