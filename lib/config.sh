#!/usr/bin/env bash
# lib/config.sh - load flight_tiers.conf into shell variables
# Usage: source "$SCRIPT_DIR/lib/config.sh"

TIERS_CONF="${SCRIPT_DIR:-.}/flight_tiers.conf"
DEFAULT_MAX=121
DEFAULT_MED=40
DEFAULT_HEAVY=80

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

# Only run if not already set
if [ -f "$TIERS_CONF" ]; then
  max_baggage="${max_baggage:-$(cfg_get "${VEHICLE_TIER}" "max_baggage" "$TIERS_CONF")}"
  threshold_medium="${threshold_medium:-$(cfg_get "${VEHICLE_TIER}" "threshold_medium" "$TIERS_CONF")}"
  threshold_heavy="${threshold_heavy:-$(cfg_get "${VEHICLE_TIER}" "threshold_heavy" "$TIERS_CONF")}"
fi

max_baggage="${max_baggage:-$DEFAULT_MAX}"
threshold_medium="${threshold_medium:-$DEFAULT_MED}"
threshold_heavy="${threshold_heavy:-$DEFAULT_HEAVY}"

# Basic validation
re='^[0-9]+$'
if ! [[ "$max_baggage" =~ $re ]] || [ "$max_baggage" -le 1 ]; then
  max_baggage=$DEFAULT_MAX
fi
if ! [[ "$threshold_medium" =~ $re ]]; then threshold_medium=$DEFAULT_MED; fi
if ! [[ "$threshold_heavy" =~ $re ]]; then threshold_heavy=$DEFAULT_HEAVY; fi
if [ "$threshold_medium" -ge "$threshold_heavy" ]; then
  threshold_medium=$(( threshold_heavy / 2 ))
fi

export max_baggage threshold_medium threshold_heavy
#!/usr/bin/env bash
# lib/config.sh - load flight_tiers.conf into shell variables
# Usage: source "$SCRIPT_DIR/lib/config.sh"

TIERS_CONF="${SCRIPT_DIR:-.}/flight_tiers.conf"
DEFAULT_MAX=121
DEFAULT_MED=40
DEFAULT_HEAVY=80

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

# Only run if not already set
if [ -f "$TIERS_CONF" ]; then
  max_baggage="${max_baggage:-$(cfg_get "${VEHICLE_TIER}" "max_baggage" "$TIERS_CONF")}"
  threshold_medium="${threshold_medium:-$(cfg_get "${VEHICLE_TIER}" "threshold_medium" "$TIERS_CONF")}"
  threshold_heavy="${threshold_heavy:-$(cfg_get "${VEHICLE_TIER}" "threshold_heavy" "$TIERS_CONF")}"
fi

max_baggage="${max_baggage:-$DEFAULT_MAX}"
threshold_medium="${threshold_medium:-$DEFAULT_MED}"
threshold_heavy="${threshold_heavy:-$DEFAULT_HEAVY}"

# Basic validation
re='^[0-9]+$'
if ! [[ "$max_baggage" =~ $re ]] || [ "$max_baggage" -le 1 ]; then
  max_baggage=$DEFAULT_MAX
fi
if ! [[ "$threshold_medium" =~ $re ]]; then threshold_medium=$DEFAULT_MED; fi
if ! [[ "$threshold_heavy" =~ $re ]]; then threshold_heavy=$DEFAULT_HEAVY; fi
if [ "$threshold_medium" -ge "$threshold_heavy" ]; then
  threshold_medium=$(( threshold_heavy / 2 ))
fi

export max_baggage threshold_medium threshold_heavy
