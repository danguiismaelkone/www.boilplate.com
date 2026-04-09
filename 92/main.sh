#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------
# Initialise variables
# -------------------------------
INSTRUCTION_FILE=""
DRY_RUN=false
LINT_MODE=false
ALLOWLIST_FILE=""
LOG_LEVEL="INFO"
LOG_FILE=""
LOG_JSON=false

# -------------------------------
# Parse arguments
# -------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --lint)
            LINT_MODE=true
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
                echo "Usage: $0 [--dry-run] [--lint] [--allowlist <file>] [--log-level <LEVEL>] [--log-file <file>] [--log-json] <instruction_file>"
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$INSTRUCTION_FILE" ]]; then
    echo "Usage: $0 [--dry-run] [--lint] [--allowlist <file>] [--log-level <LEVEL>] [--log-file <file>] [--log-json] <instruction_file>"
    exit 1
fi

# -------------------------------
# Load utilities (logging, helpers)
# -------------------------------
source "$SCRIPT_DIR/utils.sh"
export LOG_LEVEL LOG_FILE LOG_JSON
export DRY_RUN

# -------------------------------
# Lint mode – only validate syntax
# -------------------------------
if [[ "$LINT_MODE" == true ]]; then
    source "$SCRIPT_DIR/commands/linter.sh"
    LINT_LINE_NUM=0
    LINT_STATE=""
    LINT_CURRENT_FILE=""
    echo "🔍 Lint mode – validating instruction file: $INSTRUCTION_FILE"

    if [[ ! -f "$INSTRUCTION_FILE" ]]; then
        die "Instruction file not found: $INSTRUCTION_FILE"
    fi

    LINE_NUM=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        LINE_NUM=$((LINE_NUM + 1))
        LINT_LINE_NUM=$LINE_NUM

        # Trim
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue

        cmd="${line%% *}"
        rest="${line#* }"

        case "$cmd" in
            MKDIR)      lint_mkdir "$rest" ;;
            CREATE)     lint_create "$rest" ;;
            DELETE)     lint_delete "$rest" ;;
            RMDIR)      lint_rmdir "$rest" ;;
            COPY)       lint_copy "$rest" ;;
            MOVE)       lint_move "$rest" ;;
            WRITE)      lint_write_start "$rest" ;;
            APPEND)     lint_append_start "$rest" ;;
            REPLACE)    lint_replace "$rest" ;;
            EXEC)       lint_exec "$rest" ;;
            JSONINSERT) lint_jsoninsert "$rest" ;;
            SET)        ;;
            RENDER)     ;;
            IF|ELSE|ENDIF) ;;
            END)        lint_end ;;
            *)
                if [[ -n "$LINT_STATE" ]]; then
                    # Inside WRITE/APPEND block – content is valid
                    :
                else
                    lint_error "Unknown command: $cmd"
                fi
                ;;
        esac
    done < "$INSTRUCTION_FILE"

    lint_final_check
    exit $?
fi

# -------------------------------
# Execution mode setup
# -------------------------------
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
source "$SCRIPT_DIR/commands/variables.sh"
source "$SCRIPT_DIR/commands/conditionals.sh"

# Initialise conditional stack
init_conditionals

# Load allowlist if provided
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

# Validate instruction file exists
if [[ ! -f "$INSTRUCTION_FILE" ]]; then
    die "Instruction file not found: $INSTRUCTION_FILE"
fi

if [[ "$DRY_RUN" == true ]]; then
    log_info "DRY RUN MODE – No changes will be made"
else
    log_info "Executing instructions from $INSTRUCTION_FILE"
fi

require_command "jq"

# -------------------------------
# Main execution loop
# -------------------------------
CURRENT_COMMAND=""
CURRENT_FILE=""
BUFFER=""

while IFS= read -r line || [[ -n "$line" ]]; do
    # Trim
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue

    # Extract command and arguments
    cmd="${line%% *}"
    rest="${line#* }"

    # Substitute variables in arguments (except for commands that should not be substituted)
    case "$cmd" in
        SET|END|RENDER|IF|ELSE|ENDIF)
            # No substitution for these
            ;;
        *)
            if [[ -n "$rest" ]]; then
                rest=$(subst_vars "$rest")
            fi
            ;;
    esac

    # Conditional skipping (except for IF/ELSE/ENDIF which must be processed)
    if [[ $SKIP_LEVEL -gt 0 ]]; then
        case "$cmd" in
            IF|ELSE|ENDIF)
                # These commands are always processed to manage the skip state
                ;;
            *)
                log_debug "Skipping command due to false condition: $cmd"
                continue
                ;;
        esac
    fi

    # Execute command
    case "$cmd" in
        MKDIR)      handle_mkdir "$rest" ;;
        CREATE)     handle_create "$rest" ;;
        DELETE)     handle_delete "$rest" ;;
        RMDIR)      handle_rmdir "$rest" ;;
        COPY)       handle_copy "$rest" ;;
        MOVE)       handle_move "$rest" ;;
        WRITE)      handle_write_start "$rest" ;;
        APPEND)     handle_append_start "$rest" ;;
        REPLACE)    handle_replace "$rest" ;;
        EXEC)       handle_exec "$rest" ;;
        JSONINSERT) handle_jsoninsert "$rest" ;;
        SET)        handle_set "$rest" ;;
        RENDER)     handle_render "$rest" ;;
        IF)         handle_if "$rest" ;;
        ELSE)       handle_else ;;
        ENDIF)      handle_endif ;;
        END)        handle_end ;;
        *)
            if [[ -n "$CURRENT_COMMAND" ]]; then
                BUFFER+="$line"$'\n'
            else
                log_warn "Unknown command: $cmd (ignored)"
            fi
            ;;
    esac
done < "$INSTRUCTION_FILE"

# -------------------------------
# Finalise
# -------------------------------
if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry run completed – No actual changes were made"
else
    log_info "Done executing instructions!"
fi