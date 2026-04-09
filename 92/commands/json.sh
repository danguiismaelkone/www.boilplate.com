#!/usr/bin/env bash
# Handler for JSONINSERT (jq insertion)

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
    check_file "$file"

    # Validate JSON
    if ! jq empty "$file" 2>/dev/null; then
        die "Invalid JSON in $file"
    fi

    local tmpfile
    tmpfile=$(mktemp)
    if ! jq --arg val "$value" "$json_path.$key=\$val" "$file" > "$tmpfile"; then
        rm -f "$tmpfile"
        die "Failed to insert JSON key $key at $json_path"
    fi

    # Preserve permissions (backup then replace)
    cp -p "$file" "$file.bak" 2>/dev/null || true
    mv "$tmpfile" "$file"
    echo "🔧 Inserted $key = $value in $file (path: $json_path)"
}