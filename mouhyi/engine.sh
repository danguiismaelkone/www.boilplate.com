#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Helper functions
# -------------------------------

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
# Usage: split_args "$args_string" -> sets $args_array
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

# -------------------------------
# Main script
# -------------------------------

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <instruction_file>"
    exit 1
fi

INSTRUCTION_FILE="$1"

if [[ ! -f "$INSTRUCTION_FILE" ]]; then
    die "Instruction file not found: $INSTRUCTION_FILE"
fi

echo "🚀 Executing instructions from $INSTRUCTION_FILE"

CURRENT_COMMAND=""
CURRENT_FILE=""
BUFFER=""

# Ensure required external tools are available
require_command "jq"

while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue

    # Extract command (first word) and the rest of the line
    cmd="${line%% *}"
    rest="${line#* }"

    case "$cmd" in
        MKDIR)
            if [[ -z "$rest" ]]; then
                die "MKDIR: missing directory argument"
            fi
            mkdir -p "$rest" || die "Failed to create directory: $rest"
            echo "📁 Created directory: $rest"
            ;;

        CREATE)
            if [[ -z "$rest" ]]; then
                die "CREATE: missing file argument"
            fi
            mkdir -p "$(dirname "$rest")"
            touch "$rest" || die "Failed to create file: $rest"
            echo "📄 Created file: $rest"
            ;;

        DELETE)
            if [[ -z "$rest" ]]; then
                die "DELETE: missing file argument"
            fi
            rm -f "$rest" || die "Failed to delete file: $rest"
            echo "🗑 Deleted file: $rest"
            ;;

        RMDIR)
            if [[ -z "$rest" ]]; then
                die "RMDIR: missing directory argument"
            fi
            rm -rf "$rest" || die "Failed to delete directory: $rest"
            echo "🗑 Deleted directory: $rest"
            ;;

        COPY)
            # COPY source destination
            split_args "$rest"
            if [[ ${#ARGS[@]} -ne 2 ]]; then
                die "COPY requires two arguments: source destination"
            fi
            cp -R "${ARGS[0]}" "${ARGS[1]}" || die "Copy failed"
            echo "📋 Copied ${ARGS[0]} → ${ARGS[1]}"
            ;;

        MOVE)
            # MOVE source destination
            split_args "$rest"
            if [[ ${#ARGS[@]} -ne 2 ]]; then
                die "MOVE requires two arguments: source destination"
            fi
            mv "${ARGS[0]}" "${ARGS[1]}" || die "Move failed"
            echo "↪️ Moved ${ARGS[0]} → ${ARGS[1]}"
            ;;

        WRITE)
            if [[ -z "$rest" ]]; then
                die "WRITE: missing file argument"
            fi
            CURRENT_COMMAND="WRITE"
            CURRENT_FILE="$rest"
            BUFFER=""
            ;;

        APPEND)
            if [[ -z "$rest" ]]; then
                die "APPEND: missing file argument"
            fi
            CURRENT_COMMAND="APPEND"
            CURRENT_FILE="$rest"
            BUFFER=""
            ;;

        REPLACE)
            # REPLACE file old new  (old/new can contain spaces if quoted)
            split_args "$rest"
            if [[ ${#ARGS[@]} -ne 3 ]]; then
                die "REPLACE requires three arguments: file old new"
            fi
            file="${ARGS[0]}"
            old="${ARGS[1]}"
            new="${ARGS[2]}"
            check_file "$file"
            # Escape special characters for sed
            old_escaped=$(printf '%s\n' "$old" | sed 's/[\/&]/\\&/g')
            new_escaped=$(printf '%s\n' "$new" | sed 's/[\/&]/\\&/g')
            sed_i "$file" "s/$old_escaped/$new_escaped/g" || die "Failed to replace in $file"
            echo "🔁 Replaced in $file: $old → $new"
            ;;

        EXEC)
            if [[ -z "$rest" ]]; then
                die "EXEC: missing command"
            fi
            echo "⚡ Running: $rest"
            # Safer than eval: use bash -c with proper quoting
            bash -c "$rest" || warn "Command exited with non-zero status"
            ;;

        JSONINSERT)
            # JSONINSERT file key value [path]
            # path is optional (default: .scripts)
            split_args "$rest"
            if [[ ${#ARGS[@]} -lt 3 ]]; then
                die "JSONINSERT requires at least three arguments: file key value [json_path]"
            fi
            file="${ARGS[0]}"
            key="${ARGS[1]}"
            value="${ARGS[2]}"
            json_path="${ARGS[3]:-.scripts}"
            check_file "$file"
            # Validate JSON
            if ! jq empty "$file" 2>/dev/null; then
                die "Invalid JSON in $file"
            fi
            tmpfile=$(mktemp)
            if ! jq --arg val "$value" "$json_path.$key=\$val" "$file" > "$tmpfile"; then
                rm -f "$tmpfile"
                die "Failed to insert JSON key $key at $json_path"
            fi
            # Preserve permissions
            cp -p "$file" "$file.bak" 2>/dev/null || true
            mv "$tmpfile" "$file"
            echo "🔧 Inserted $key = $value in $file (path: $json_path)"
            ;;

        END)
            if [[ "$CURRENT_COMMAND" == "WRITE" ]]; then
                # Ensure parent directory exists
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
            ;;

        *)
            # Capture multiline content for WRITE/APPEND
            if [[ -n "$CURRENT_COMMAND" ]]; then
                BUFFER+="$line"$'\n'
            else
                warn "Unknown command: $cmd (ignored)"
            fi
            ;;
    esac
done < "$INSTRUCTION_FILE"

echo "✅ Done executing instructions!"