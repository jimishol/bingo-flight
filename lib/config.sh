#!/usr/bin/env bash
# lib/config.sh - load flight_tiers.conf using strict native interface parser rules
# Usage: source "$SCRIPT_DIR/lib/config.sh"

TIERS_CONF="${SCRIPT_DIR:-.}/flight_tiers.conf"

if [ -z "$VEHICLE_TIER" ]; then
    echo "ERROR: VEHICLE_TIER is not set. Cannot parse profile rules." >&2
    (return 0 2>/dev/null) && return 1 || exit 1
fi

if [ ! -f "$TIERS_CONF" ]; then
    echo "ERROR: Configuration file not found at: $TIERS_CONF" >&2
    (return 0 2>/dev/null) && return 1 || exit 1
fi

# ==============================================================================
# OPTIMIZED NATIVE INI PARSER - STRICT KEY SANITIZATION & SPACE CONSTANCY
# ==============================================================================
_active_section=""

while IFS='=' read -r key value || [ -n "$key" ]; do
    # 1. Παράκαμψη κενών γραμμών και σχολίων στην αρχή
    case "$key" in
        ''|\#*) continue ;;
    esac

    # 2. Ασφαλής αφαίρεση inline σχολίων και Windows Carriage Returns (\r)
    key="${key%%#*}"
    value="${value%%#*}"
    key="${key%$'\r'}"
    value="${value%$'\r'}"

    # 3. ABSOLUTE KEY SANITIZATION: Το μυστικό όπλο!
    # Φιλτράρει ΟΛΑ τα αόρατα κενά, NBSPs και σκουπίδια. Κρατάει ΜΟΝΟ
    # γράμματα, νούμερα, underscores και αγκύλες [ ].
    clean_key=""
    for (( i=0; i<${#key}; i++ )); do
        c="${key:$i:1}"
        case "$c" in
            [A-Za-z0-9_\[\]]) clean_key="$clean_key$c" ;;
        esac
    done
    key="$clean_key"

    # Αν το key άδειασε εντελώς, πάμε στην επόμενη γραμμή
    [ -z "$key" ] && continue

    # 4. Ανίχνευση INI Section (π.χ. [medium_airplane])
    case "$key" in
        \[*\])
            _active_section="${key#\[}"
            _active_section="${_active_section%\]}"
            continue
            ;;
    esac

    # 5. Επεξεργασία δεδομένων ΜΟΝΟ αν είμαστε στο σωστό VEHICLE_TIER
    if [ "$_active_section" = "$VEHICLE_TIER" ]; then

        # 6. Καθαρισμός standard κενών (leading/trailing trim) από το value
        value="${value#"${value%%[! \t]*}"}"
        value="${value%"${value##*[! \t]}"}"

        # 7. Αφαίρεση εξωτερικών διπλών εισαγωγικών με προστασία εσωτερικών spaces
        case "$value" in
            \"*\")
                value="${value#\"}"
                value="${value%\"}"
                ;;
        esac

        # 8. Έλεγχος εγκυρότητας μεταβλητής (Σε 1 γραμμή για αποφυγή line-continuation bugs)
        case "$key" in
            max_baggage|threshold_medium|threshold_heavy|crew|pax_min|pax_range|seats_per_zone|pax1_label|pax2_label|pax3_label|journey_zones|journey_cargo)
                printf -v "$key" "%s" "$value"
                ;;
        esac
    fi
done < "$TIERS_CONF"

# Μετατροπή του "137 177 126" σε array για τα journey legs
read -r -a journey_cargo <<< "${journey_cargo:-}"

# Εξαγωγή των μεταβλητών στο session του flight.sh
export max_baggage threshold_medium threshold_heavy crew
export pax_min pax_range seats_per_zone pax1_label pax2_label pax3_label journey_zones journey_cargo
