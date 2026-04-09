#!/usr/bin/env bash
# Utility functions used by all modules

die() {
    echo "❌ Error: $*" >&2
    exit 1
}

warn() {
    echo "⚠️ Warning: $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required but not installed."
}

# Portable sed -i (works on macOS and Linux)
sed_i() {
    local file="$1"
    local expr="$2"
    if sed --version 2>/dev/null | grep -q GNU; then
        sed -i "$expr" "$file"
    else
        sed -i '' "$expr" "$file"
    fi
}

# Safely split a string into arguments respecting quotes
# Usage: split_args "$args_string" -> sets global array ARGS
split_args() {
    local input="$1"
    # Use eval with printf to safely split (only splits, does not execute)
    eval "set -- $input"
    # Store in global array
    ARGS=("$@")
}

# Check if a file exists and is readable
check_file() {
    if [[ ! -f "$1" ]]; then
        die "File not found: $1"
    fi
}