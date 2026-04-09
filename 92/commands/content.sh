#!/usr/bin/env bash
# Handlers for multiline content (WRITE, APPEND, END)
# These functions modify global variables CURRENT_COMMAND, CURRENT_FILE, BUFFER

handle_write_start() {
    local file="$1"
    if [[ -z "$file" ]]; then
        die "WRITE: missing file argument"
    fi
    CURRENT_COMMAND="WRITE"
    CURRENT_FILE="$file"
    BUFFER=""
}

handle_append_start() {
    local file="$1"
    if [[ -z "$file" ]]; then
        die "APPEND: missing file argument"
    fi
    CURRENT_COMMAND="APPEND"
    CURRENT_FILE="$file"
    BUFFER=""
}

handle_end() {
    if [[ "$CURRENT_COMMAND" == "WRITE" ]]; then
        mkdir -p "$(dirname "$CURRENT_FILE")"
        printf "%s" "$BUFFER" > "$CURRENT_FILE" || die "Failed to write to $CURRENT_FILE"
        echo "✍️ Wrote file: $CURRENT_FILE"
    elif [[ "$CURRENT_COMMAND" == "APPEND" ]]; then
        mkdir -p "$(dirname "$CURRENT_FILE")"
        printf "%s" "$BUFFER" >> "$CURRENT_FILE" || die "Failed to append to $CURRENT_FILE"
        echo "➕ Appended file: $CURRENT_FILE"
    fi
    CURRENT_COMMAND=""
    CURRENT_FILE=""
    BUFFER=""
}