#!/usr/bin/env bash
# lib/story_loader.sh - loader: check project lang/tier folder, fallback to en, always return 0
# Usage: story=$(load_story "$VEHICLE_TIER" "$passengers" "$bag_class")
# Expects LOCALIZATION to be set by caller (flight.sh)

load_story() {
  local tier="$1" pax="$2" bag="$3"
  local lang base candidate rel_dir expected_file

  # Read localization set by flight.sh; if empty, fall back to en
  lang="${LOCALIZATION}"
  [ -n "$lang" ] || lang="en"

  # prefer requested localization; if missing, fall back to en
  base="${SCRIPT_DIR:-.}/stories/${lang}/${tier}"
  if [ ! -d "$base" ]; then
    lang="en"
    base="${SCRIPT_DIR:-.}/stories/${lang}/${tier}"
  fi

  # base and expected_file already set earlier
  rel_dir="stories/${lang}/${tier}"
  expected_file="pax${pax}__bag${bag}.txt"

  # choose candidate according to JOURNEY_MODE, but fall back to pax if journey.txt missing
  if [ "${JOURNEY_MODE:-0}" -eq 1 ]; then
    candidate="${base}/journey.txt"
    expected_file="journey.txt"
    if [ ! -f "$candidate" ]; then
      candidate="${base}/pax${pax}__bag${bag}.txt"
      expected_file="pax${pax}__bag${bag}.txt"
    fi
  else
    candidate="${base}/${expected_file}"
  fi

  # If candidate exists, attempt to extract a non-empty line.
  # If the file has no non-empty lines, treat it as missing so fallback can occur.

  if [ -f "$candidate" ]; then
      if [ "${expected_file}" = "journey.txt" ]; then
          # deterministic: first non-empty line
          awk 'NF{print; exit}' "$candidate" \
              || printf 'ERROR: No non-empty lines in %s\n' "$candidate"
      else
          # random non-empty line
          awk 'BEGIN{srand()} NF{lines[++n]=$0} END{ if(n) print lines[int(rand()*n)+1] }' "$candidate" \
              || printf 'ERROR: No non-empty lines in %s\n' "$candidate"
      fi
  
      return 0   # ← THIS WAS MISSING
  fi

  # Nothing usable found in chosen candidate(s): print single-line error and succeed
  printf 'ERROR: No story file. Expected %s in %s\n' "$expected_file" "$rel_dir"
  return 0
}

export -f load_story
