#!/usr/bin/env bash
# lib/config.sh - load flight_tiers.conf into shell variables
# Usage: source "$SCRIPT_DIR/lib/config.sh"

TIERS_CONF="${SCRIPT_DIR:-.}/flight_tiers.conf"

cfg_get() {
  local section="$1" key="$2" file="$3"
  # Use exact match for [section] and clean up whitespaces safely
  awk -v sec="[$section]" -v key="$key" '
    $0 == sec {found=1; next}
    found && /^[[:space:]]*\[/ {exit}
    found && $0 ~ "^[[:space:]]*"key"[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "", $0);
      gsub(/^[ \t]+|[ \t]+$/, "", $0);
      print $0;
      exit
    }
  ' "$file" 2>/dev/null || true
}

  max_baggage="${max_baggage:-$(cfg_get "${VEHICLE_TIER}" "max_baggage" "$TIERS_CONF")}"
  threshold_medium="${threshold_medium:-$(cfg_get "${VEHICLE_TIER}" "threshold_medium" "$TIERS_CONF")}"
  threshold_heavy="${threshold_heavy:-$(cfg_get "${VEHICLE_TIER}" "threshold_heavy" "$TIERS_CONF")}"
  crew="${crew:-$(cfg_get "${VEHICLE_TIER}" "crew" "$TIERS_CONF")}"

export max_baggage threshold_medium threshold_heavy crew
