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

pax_min="${pax_min:-$(cfg_get "${VEHICLE_TIER}" "pax_min" "$TIERS_CONF")}"
pax_range="${pax_range:-$(cfg_get "${VEHICLE_TIER}" "pax_range" "$TIERS_CONF")}"
seats_per_zone="${seats_per_zone:-$(cfg_get "${VEHICLE_TIER}" "seats_per_zone" "$TIERS_CONF")}"
pax1_label="${pax1_label:-$(cfg_get "${VEHICLE_TIER}" "pax1_label" "$TIERS_CONF")}"
pax2_label="${pax2_label:-$(cfg_get "${VEHICLE_TIER}" "pax2_label" "$TIERS_CONF")}"
pax3_label="${pax3_label:-$(cfg_get "${VEHICLE_TIER}" "pax3_label" "$TIERS_CONF")}"
journey_zones="${journey_zones:-$(cfg_get "${VEHICLE_TIER}" "journey_zones" "$TIERS_CONF")}"
journey_cargo_raw="$(cfg_get "${VEHICLE_TIER}" "journey_cargo" "$TIERS_CONF")"

# split "137 177 126" into array
read -r -a journey_cargo <<< "$journey_cargo_raw"

export pax_min pax_range seats_per_zone pax1_label pax2_label pax3_label journey_zones journey_cargo
