#!/usr/bin/env bash
# blueprint_sync.sh - Global Localization & Story Compilation Engine
# Usage: Execute from the repository root directory:
#        ./blueprint_sync.sh clone el small_airplane fr
#        ./blueprint_sync.sh expand fr small_airplane

set -euo pipefail

show_help() {
    echo "Flight Dispatcher Story Blueprint Sync Engine"
    echo "============================================="
    echo "Usage Options:"
    echo "  ./blueprint_sync.sh clone <from_lang> <tier> <to_lang>"
    echo "      Example: ./blueprint_sync.sh clone el small_airplane fr"
    echo "      -> Compiles flat source files and creates a master blueprint inside target directory."
    echo "      -> Aborts if the target directory already exists and contains files."
    echo ""
    echo "  ./blueprint_sync.sh expand <lang> <tier>"
    echo "      Example: ./blueprint_sync.sh expand fr small_airplane"
    echo "      -> Explodes a target blueprint.txt back into flat text modules."
    echo "      -> Aborts if files other than blueprint.txt exist in that directory."
    echo ""
    echo "  ./blueprint_sync.sh -h | --help"
    echo "      -> Show this help information"
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -lt 3 ]; then
    if [ "${1:-}" = "expand" ] && [ $# -eq 3 ]; then
        : # 'expand' requires exactly 3 arguments, continue execution
    else
        show_help
    fi
fi

COMMAND="$1"
STORIES_ROOT="stories"

# ==============================================================================
# ROUTINE: COMPILE FLAT FILES INTO A SINGLE IN-MEMORY/STREAM BLUEPRINT
# ==============================================================================
compile_blueprint_stream() {
    local src_dir="$1"
    local tier_name="$2"

    echo "## =========================================================================="
    echo "## COMPREHENSIVE STORY BLUEPRINT FOR VEHICLE TIER: $tier_name"
    echo "## =========================================================================="
    echo ""

    for pax in {0..3}; do
        for bag in light medium heavy; do
            local flat_file="$src_dir/pax${pax}__bag${bag}.txt"
            echo "[pax${pax}__bag${bag}.txt]"
            if [ -f "$flat_file" ] && [ -s "$flat_file" ]; then
                cat "$flat_file"
            else
                echo "# Add custom narrative variants here (one per line)..."
            fi
            echo ""
        done
    done

    echo "[journey.txt]"
    if [ -f "$src_dir/journey.txt" ] && [ -s "$src_dir/journey.txt" ]; then
        cat "$src_dir/journey.txt"
    else
        echo "# Add sequential route headers here..."
    fi
    echo ""
}

# ==============================================================================
# COMMAND 1: CLONE (Compile from source and prepare translation blueprint)
# ==============================================================================
if [ "$COMMAND" = "clone" ]; then
    if [ $# -ne 4 ]; then show_help; fi
    
    FROM_LANG="$2"
    TIER="$3"
    TO_LANG="$4"

    SRC_DIR="$STORIES_ROOT/$FROM_LANG/$TIER"
    TARGET_DIR="$STORIES_ROOT/$TO_LANG/$TIER"
    TARGET_BLUEPRINT="$TARGET_DIR/blueprint.txt"

    if [ ! -d "$SRC_DIR" ]; then
        echo "❌ ERROR: Source directory '$SRC_DIR' does not exist!"
        exit 1
    fi

    # 🛑 SAFETY GATE: Abort if target folder exists and contains any files
    if [ -d "$TARGET_DIR" ] && [ "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
        echo "❌ SAFETY ABORT: Target directory '$TARGET_DIR' already exists and is not empty!"
        echo "Please clean or remove this directory manually before cloning."
        exit 1
    fi

    echo "🔄 Ingesting assets from '$SRC_DIR' -> Building blueprint for '$TO_LANG'..."
    mkdir -p "$TARGET_DIR"
    
    compile_blueprint_stream "$SRC_DIR" "$TIER" > "$TARGET_BLUEPRINT"

    echo "✅ SUCCESS: Integrated translation blueprint created at: $TARGET_BLUEPRINT"

# ==============================================================================
# COMMAND 2: EXPAND (Explode single translation blueprint into flat modules)
# ==============================================================================
elif [ "$COMMAND" = "expand" ]; then
    LANG_CODE="$2"
    TIER="$3"

    TARGET_DIR="$STORIES_ROOT/$LANG_CODE/$TIER"
    BLUEPRINT_FILE="$TARGET_DIR/blueprint.txt"

    if [ ! -f "$BLUEPRINT_FILE" ]; then
        echo "❌ ERROR: Blueprint file '$BLUEPRINT_FILE' not found!"
        exit 1
    fi

    # 🛑 SAFETY GATE: Verify blueprint.txt is the ONLY file present in the directory
    # Counting entries inside the directory using find
    FILE_COUNT=$(find "$TARGET_DIR" -maxdepth 1 -type f | wc -l)
    DIR_COUNT=$(find "$TARGET_DIR" -maxdepth 1 -type d | wc -l)
    
    # DIR_COUNT will be 1 (the directory itself). FILE_COUNT must be exactly 1 (only blueprint.txt)
    if [ "$FILE_COUNT" -ne 1 ] || [ "$DIR_COUNT" -ne 1 ]; then
        echo "❌ SAFETY ABORT: Ready to expand, but '$TARGET_DIR' contains other files or folders!"
        echo "The target directory must strictly contain ONLY 'blueprint.txt' to protect your data."
        exit 1
    fi

    echo "💥 Exploding blueprint '$BLUEPRINT_FILE' into discrete flat text files..."

    current_target_file=""

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"

        if [[ "$line" =~ ^\[([a-zA-Z0-9_]+\.txt)\]$ ]]; then
            current_target_file="$TARGET_DIR/${BASH_REMATCH[1]}"
            true > "$current_target_file"
            echo "  --> Fragment module generated: $(basename "$current_target_file")"
        elif [ -n "$current_target_file" ]; then
            if [ -n "$line" ] || { [ -f "$current_target_file" ] && [ -s "$current_target_file" ]; }; then
                echo "$line" >> "$current_target_file"
            fi
        fi
    done < "$BLUEPRINT_FILE"

    echo "✅ SUCCESS: All localized file dependencies have been safely expanded into '$TARGET_DIR'!"

else
    show_help
fi
