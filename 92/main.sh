#!/usr/bin/env bash
set -euo pipefail

# Get the directory where this script resides
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load utilities
source "$SCRIPT_DIR/utils.sh"

# Load command handlers
source "$SCRIPT_DIR/commands/filesystem.sh"
source "$SCRIPT_DIR/commands/content.sh"
source "$SCRIPT_DIR/commands/replace.sh"
source "$SCRIPT_DIR/commands/exec.sh"
source "$SCRIPT_DIR/commands/json.sh"

# -------------------------------
# Main execution
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

# State for multiline WRITE/APPEND
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
        MKDIR)    handle_mkdir "$rest" ;;
        CREATE)   handle_create "$rest" ;;
        DELETE)   handle_delete "$rest" ;;
        RMDIR)    handle_rmdir "$rest" ;;
        COPY)     handle_copy "$rest" ;;
        MOVE)     handle_move "$rest" ;;
        WRITE)    handle_write_start "$rest" ;;
        APPEND)   handle_append_start "$rest" ;;
        REPLACE)  handle_replace "$rest" ;;
        EXEC)     handle_exec "$rest" ;;
        JSONINSERT) handle_jsoninsert "$rest" ;;
        END)      handle_end ;;
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