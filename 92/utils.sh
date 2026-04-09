#!/usr/bin/env bash

die() {
    echo "❌ Error: $*" >&2
    exit 1
}

warn() {
    echo "⚠️ Warning: $*" >&2
}

dry_run_echo() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "🔍 [DRY RUN] $*"
    fi
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
            warn "File would be required but does not exist (dry‑run): $1"
            return 0
        else
            die "File not found: $1"
        fi
    fi
}