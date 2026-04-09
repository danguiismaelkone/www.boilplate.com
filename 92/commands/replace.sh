#!/usr/bin/env bash
# Handler for REPLACE (sed in-place substitution)

handle_replace() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 3 ]]; then
        die "REPLACE requires three arguments: file old new"
    fi
    local file="${ARGS[0]}"
    local old="${ARGS[1]}"
    local new="${ARGS[2]}"
    check_file "$file"
    # Escape special characters for sed
    local old_escaped=$(printf '%s\n' "$old" | sed 's/[\/&]/\\&/g')
    local new_escaped=$(printf '%s\n' "$new" | sed 's/[\/&]/\\&/g')
    sed_i "$file" "s/$old_escaped/$new_escaped/g" || die "Failed to replace in $file"
    echo "🔁 Replaced in $file: $old → $new"
}