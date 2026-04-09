#!/usr/bin/env bash
# Handlers for MKDIR, CREATE, DELETE, RMDIR, COPY, MOVE

handle_mkdir() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        die "MKDIR: missing directory argument"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "mkdir -p $dir"
        return 0
    fi
    mkdir -p "$dir" || die "Failed to create directory: $dir"
    echo "📁 Created directory: $dir"
}

handle_create() {
    local file="$1"
    if [[ -z "$file" ]]; then
        die "CREATE: missing file argument"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "mkdir -p $(dirname "$file")"
        dry_run_echo "touch $file"
        return 0
    fi
    mkdir -p "$(dirname "$file")"
    touch "$file" || die "Failed to create file: $file"
    echo "📄 Created file: $file"
}

handle_delete() {
    local file="$1"
    if [[ -z "$file" ]]; then
        die "DELETE: missing file argument"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "rm -f $file"
        return 0
    fi
    rm -f "$file" || die "Failed to delete file: $file"
    echo "🗑 Deleted file: $file"
}

handle_rmdir() {
    local dir="$1"
    if [[ -z "$dir" ]]; then
        die "RMDIR: missing directory argument"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "rm -rf $dir"
        return 0
    fi
    rm -rf "$dir" || die "Failed to delete directory: $dir"
    echo "🗑 Deleted directory: $dir"
}

handle_copy() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        die "COPY requires two arguments: source destination"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "cp -R ${ARGS[0]} ${ARGS[1]}"
        return 0
    fi
    cp -R "${ARGS[0]}" "${ARGS[1]}" || die "Copy failed"
    echo "📋 Copied ${ARGS[0]} → ${ARGS[1]}"
}

handle_move() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        die "MOVE requires two arguments: source destination"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "mv ${ARGS[0]} ${ARGS[1]}"
        return 0
    fi
    mv "${ARGS[0]}" "${ARGS[1]}" || die "Move failed"
    echo "↪️ Moved ${ARGS[0]} → ${ARGS[1]}"
}