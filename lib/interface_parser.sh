#!/usr/bin/env bash
# lib/interface_loader.sh - Centralized UI Asset Parser

load_interface_assets() {
    local interface_file="$1"
    [ ! -f "$interface_file" ] && return 1

    while IFS='=' read -r key value || [ -n "$key" ]; do
        # 1. Skip comments and empty lines
        case "$key" in
            ''|\#*) continue ;;
        esac

        # 2. Remove UTF-8 BOM
        case "$key" in
            $'\xEF\xBB\xBF'*) key="${key#$'\xEF\xBB\xBF'}" ;;
        esac

        # 3. Clean key
        clean_key=""
        i=1
        while [ $i -le ${#key} ]; do
            c=$(printf '%s' "$key" | cut -c $i)
            case "$c" in
                [A-Za-z0-9_]) clean_key="$clean_key$c" ;;
            esac
            i=$((i+1))
        done
        [ -z "$clean_key" ] && continue

        # 4. Clean value (quotes)
        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
        esac

        # 5. Final assignment
        printf -v "$clean_key" "%s" "$value"
    done < "$interface_file"

    unset key value clean_key i c interface_file
}
