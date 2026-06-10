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

  rel_dir="stories/${lang}/${tier}"
  expected_file="pax${pax}__bag${bag}.txt"
  candidate="$base/${expected_file}"


  # pick a random non-empty line from the file (POSIX awk)
  if [ -f "$candidate" ]; then
    # read and print one random non-empty line
    awk 'BEGIN{srand()} NF{lines[++n]=$0} END{ if(n) print lines[int(rand()*n)+1] }' "$candidate"
    return 0
  fi

  # No story file found: print the single-line error as loader output and succeed
  printf 'Context     : ERROR: No story file. Expected %s in %s\n' "$expected_file" "$rel_dir"
  return 0
}

export -f load_story
