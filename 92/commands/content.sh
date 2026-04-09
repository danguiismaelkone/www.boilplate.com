#!/usr/bin/env bash
# Handlers for WRITE, APPEND, END (multiline content)

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
        if [[ -f "$CURRENT_FILE" ]]; then
            if file_content_equals "$CURRENT_FILE" "$BUFFER"; then
                log_info "✍️ Content unchanged, skipping write: $CURRENT_FILE"
                CURRENT_COMMAND=""
                CURRENT_FILE=""
                BUFFER=""
                return 0
            fi
        fi
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_echo "write $CURRENT_FILE (content follows)"
            CURRENT_COMMAND=""
            CURRENT_FILE=""
            BUFFER=""
            return 0
        fi
        printf "%s" "$BUFFER" > "$CURRENT_FILE" || die "Failed to write to $CURRENT_FILE"
        log_info "✍️ Wrote file: $CURRENT_FILE"
    elif [[ "$CURRENT_COMMAND" == "APPEND" ]]; then
        mkdir -p "$(dirname "$CURRENT_FILE")"
        if [[ -f "$CURRENT_FILE" ]]; then
            if file_ends_with "$CURRENT_FILE" "$BUFFER"; then
                log_info "➕ Content already present at end, skipping append: $CURRENT_FILE"
                CURRENT_COMMAND=""
                CURRENT_FILE=""
                BUFFER=""
                return 0
            fi
        fi
        if [[ "$DRY_RUN" == true ]]; then
            dry_run_echo "append $CURRENT_FILE (content follows)"
            CURRENT_COMMAND=""
            CURRENT_FILE=""
            BUFFER=""
            return 0
        fi
        printf "%s" "$BUFFER" >> "$CURRENT_FILE" || die "Failed to append to $CURRENT_FILE"
        log_info "➕ Appended file: $CURRENT_FILE"
    fi
    CURRENT_COMMAND=""
    CURRENT_FILE=""
    BUFFER=""
}