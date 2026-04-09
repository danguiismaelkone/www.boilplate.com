handle_jsoninsert() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -lt 3 ]]; then
        die "JSONINSERT requires at least three arguments: file key value [json_path]"
    fi
    local file="${ARGS[0]}"
    local key="${ARGS[1]}"
    local value="${ARGS[2]}"
    local json_path="${ARGS[3]:-.scripts}"

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "JSONINSERT $file $key \"$value\" at $json_path"
        return 0
    fi

    check_file "$file"

    # Validate JSON (only in real execution)
    if ! jq empty "$file" 2>/dev/null; then
        die "Invalid JSON in $file"
    fi

    local tmpfile="$TEMP_DIR/json_$$.tmp"
    if ! jq --arg val "$value" "$json_path.$key=\$val" "$file" > "$tmpfile"; then
        rm -f "$tmpfile"
        die "Failed to insert JSON key $key at $json_path"
    fi

    cp -p "$file" "$file.bak" 2>/dev/null || true
    mv "$tmpfile" "$file"
    echo "🔧 Inserted $key = $value in $file (path: $json_path)"
}