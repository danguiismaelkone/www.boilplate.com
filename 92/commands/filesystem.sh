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
    log_info "📁 Created directory: $dir"
}

handle_create() {
    local file="$1"
    if [[ -z "$file" ]]; then
        die "CREATE: missing file argument"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "mkdir -p $(dirname "$file") && touch $file (if missing)"
        return 0
    fi
    if [[ -f "$file" ]]; then
        log_info "📄 File already exists, skipping: $file"
        return 0
    fi
    mkdir -p "$(dirname "$file")" || die "Failed to create parent directory for: $file"
    touch "$file" || die "Failed to create file: $file"
    log_info "📄 Created file: $file"
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
    log_info "🗑 Deleted file: $file"
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
    log_info "🗑 Deleted directory: $dir"
}

handle_copy() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        die "COPY requires two arguments: source destination"
    fi
    local src="${ARGS[0]}"
    local dest="${ARGS[1]}"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "cp -R $src $dest (skip if dest exists)"
        return 0
    fi
    if [[ -e "$dest" ]]; then
        log_info "📋 Destination already exists, skipping copy: $dest"
        return 0
    fi
    cp -R "$src" "$dest" || die "Copy failed: $src → $dest"
    log_info "📋 Copied $src → $dest"
}

handle_move() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        die "MOVE requires two arguments: source destination"
    fi
    local src="${ARGS[0]}"
    local dest="${ARGS[1]}"
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "mv $src $dest"
        return 0
    fi
    mv "$src" "$dest" || die "Move failed: $src → $dest"
    log_info "↪️ Moved $src → $dest"
}