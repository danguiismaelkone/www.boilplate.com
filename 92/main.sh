#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTRUCTION_FILE=""
DRY_RUN=false
ALLOWLIST_FILE=""
LOG_LEVEL="INFO"
LOG_FILE=""
LOG_JSON=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --allowlist)
            ALLOWLIST_FILE="$2"
            shift 2
            ;;
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        --log-json)
            LOG_JSON=true
            shift
            ;;
        *)
            if [[ -z "$INSTRUCTION_FILE" ]]; then
                INSTRUCTION_FILE="$1"
                shift
            else
                echo "Usage: $0 [options] <instruction_file>"
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$INSTRUCTION_FILE" ]]; then
    echo "Usage: $0 [--dry-run] [--allowlist <file>] [--log-level <LEVEL>] [--log-file <file>] [--log-json] <instruction_file>"
    exit 1
fi

# Load utilities (defines log functions)
source "$SCRIPT_DIR/utils.sh"

# Export logging configuration
export LOG_LEVEL LOG_FILE LOG_JSON
export DRY_RUN

# Temporary directory and trap (log_debug now available)
export TEMP_DIR=""
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        log_debug "Cleaned up temporary files"
    fi
}
trap cleanup EXIT INT TERM

TEMP_DIR=$(mktemp -d -t instruction-executor-XXXXXX)
export TEMP_DIR

# Load command handlers
source "$SCRIPT_DIR/commands/filesystem.sh"
source "$SCRIPT_DIR/commands/content.sh"
source "$SCRIPT_DIR/commands/replace.sh"
source "$SCRIPT_DIR/commands/exec.sh"
source "$SCRIPT_DIR/commands/json.sh"

# Load allowlist
if [[ -n "$ALLOWLIST_FILE" ]]; then
    if [[ -f "$ALLOWLIST_FILE" ]]; then
        ALLOWLIST=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue
            ALLOWLIST+=("$line")
        done < "$ALLOWLIST_FILE"
        export ALLOWLIST
        export EXEC_ALLOWLIST_ENABLED=true
    else
        die "Allowlist file not found: $ALLOWLIST_FILE"
    fi
else
    export EXEC_ALLOWLIST_ENABLED=false
fi

export EXEC_TIMEOUT="${EXEC_TIMEOUT:-30}"

# Main execution
if [[ ! -f "$INSTRUCTION_FILE" ]]; then
    die "Instruction file not found: $INSTRUCTION_FILE"
fi

if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN MODE – No changes will be made"
else
    log_info "Executing instructions from $INSTRUCTION_FILE"
fi

CURRENT_COMMAND=""
CURRENT_FILE=""
BUFFER=""

require_command "jq"

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue

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
            if [[ -n "$CURRENT_COMMAND" ]]; then
                BUFFER+="$line"$'\n'
            else
                log_warn "Unknown command: $cmd (ignored)"
            fi
            ;;
    esac
done < "$INSTRUCTION_FILE"

if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry run completed – No actual changes were made"
else
    log_info "Done executing instructions!"
fi