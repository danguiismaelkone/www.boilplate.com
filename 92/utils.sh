#!/usr/bin/env bash

# ================================
# Logging configuration
# ================================
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_JSON="${LOG_JSON:-false}"

get_level_num() {
    case "$1" in
        ERROR) echo 1 ;;
        WARN)  echo 2 ;;
        INFO)  echo 3 ;;
        DEBUG) echo 4 ;;
        *)     echo 0 ;;
    esac
}

log_message() {
    local level="$1"
    local msg="$2"
    local level_num=$(get_level_num "$level")
    local current_level_num=$(get_level_num "$LOG_LEVEL")

    if [[ $level_num -gt $current_level_num ]]; then
        return 0
    fi

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local formatted="[$timestamp] [$level] $msg"

    if [[ "$LOG_JSON" == "true" ]]; then
        local json_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g')
        formatted="{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$json_msg\"}"
    fi

    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo "$formatted" >&2
    else
        echo "$formatted"
    fi

    if [[ -n "$LOG_FILE" ]]; then
        echo "$formatted" >> "$LOG_FILE"
    fi
}

log_debug() { log_message "DEBUG" "$1"; }
log_info()  { log_message "INFO"  "$1"; }
log_warn()  { log_message "WARN"  "$1"; }
log_error() { log_message "ERROR" "$1"; }

die() {
    log_error "$*"
    exit 1
}

warn() {
    log_warn "$*"
}

dry_run_echo() {
    log_debug "[DRY RUN] $*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."
}

# Portable sed -i (GNU vs BSD)
sed_i() {
    local file="$1"
    local expr="$2"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "sed -i '$expr' $file"
        return 0
    fi
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "$expr" "$file"
    else
        sed -i '' "$expr" "$file"
    fi
}

# Safe argument splitter – no eval, respects single/double quotes
split_args() {
    local input="$1"
    ARGS=()
    local current=""
    local in_quote=false
    local quote_char=""
    local i=0
    local len=${#input}
    while [[ $i -lt $len ]]; do
        char="${input:$i:1}"
        if [[ "$in_quote" == false ]]; then
            if [[ "$char" == "'" || "$char" == '"' ]]; then
                in_quote=true
                quote_char="$char"
                ((i++))
                continue
            elif [[ "$char" == " " || "$char" == $'\t' ]]; then
                if [[ -n "$current" ]]; then
                    ARGS+=("$current")
                    current=""
                fi
                ((i++))
                continue
            fi
        else
            if [[ "$char" == "$quote_char" ]]; then
                in_quote=false
                quote_char=""
                ((i++))
                continue
            fi
        fi
        current+="$char"
        ((i++))
    done
    if [[ -n "$current" ]]; then
        ARGS+=("$current")
    fi
}

# Check file existence (dry‑run aware)
check_file() {
    if [[ ! -f "$1" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_debug "File would be required but does not exist (dry‑run): $1"
            return 0
        else
            die "File not found: $1"
        fi
    fi
}

# ================================
# Idempotency helpers
# ================================
file_content_equals() {
    local file="$1"
    local expected="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local actual
    actual=$(cat "$file")
    [[ "$actual" == "$expected" ]]
}

file_ends_with() {
    local file="$1"
    local suffix="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local content
    content=$(cat "$file")
    [[ "$content" == *"$suffix" ]]
}

# ================================
# Variable handling (for SET and substitution)
# ================================
declare -a VAR_NAMES=()
declare -a VAR_VALUES=()

set_var() {
    local name="$1"
    local value="$2"
    for i in "${!VAR_NAMES[@]}"; do
        if [[ "${VAR_NAMES[$i]}" == "$name" ]]; then
            VAR_VALUES[$i]="$value"
            return 0
        fi
    done
    VAR_NAMES+=("$name")
    VAR_VALUES+=("$value")
}

get_var() {
    local name="$1"
    for i in "${!VAR_NAMES[@]}"; do
        if [[ "${VAR_NAMES[$i]}" == "$name" ]]; then
            echo "${VAR_VALUES[$i]}"
            return 0
        fi
    done
    echo ""
}

# Substitute $VAR and ${VAR} in a string
subst_vars() {
    local input="$1"
    local result="$input"
    for i in "${!VAR_NAMES[@]}"; do
        local name="${VAR_NAMES[$i]}"
        local value="${VAR_VALUES[$i]}"
        # Escape special characters for sed
        local escaped_value=$(printf '%s\n' "$value" | sed 's/[\/&]/\\&/g')
        # Replace ${VAR}
        result=$(echo "$result" | sed "s/\${$name}/$escaped_value/g")
        # Replace $VAR (as a word, not part of a longer word)
        result=$(echo "$result" | sed "s/\\\$$name\b/$escaped_value/g")
    done
    echo "$result"
}