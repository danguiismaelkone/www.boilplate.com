#!/usr/bin/env bash

# Logging configuration (set by main.sh)
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_JSON="${LOG_JSON:-false}"

# Portable log level comparison (no associative array)
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
        # Simple JSON escaping (jq not required for basic messages)
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

split_args() {
    local input="$1"
    eval "set -- $input"
    ARGS=("$@")
}

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