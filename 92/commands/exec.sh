#!/usr/bin/env bash

# Check once if timeout is available (GNU coreutils on Linux, or brew install coreutils on macOS)
if command -v timeout &>/dev/null; then
    HAS_TIMEOUT=true
else
    HAS_TIMEOUT=false
    # Only warn once, not for every EXEC
    warn "timeout command not found - running EXEC commands without timeout protection"
fi

handle_exec() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        die "EXEC: missing command"
    fi

    # Allowlist check
    if [[ "$EXEC_ALLOWLIST_ENABLED" == true ]]; then
        local allowed=false
        for pattern in "${ALLOWLIST[@]}"; do
            if [[ "$cmd" == $pattern ]]; then
                allowed=true
                break
            fi
        done
        if [[ "$allowed" == false ]]; then
            die "EXEC command not allowed by allowlist: $cmd"
        fi
    fi

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "EXEC: $cmd (timeout ${EXEC_TIMEOUT}s)"
        return 0
    fi

    echo "⚡ Running: $cmd"

    if [[ "$HAS_TIMEOUT" == true ]]; then
        # Run with timeout protection
        if ! timeout "$EXEC_TIMEOUT" bash -c "$cmd"; then
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                die "Command timed out after ${EXEC_TIMEOUT} seconds: $cmd"
            else
                warn "Command exited with non-zero status ($exit_code): $cmd"
            fi
        fi
    else
        # Run without timeout (fallback for macOS)
        if ! bash -c "$cmd"; then
            warn "Command exited with non-zero status: $cmd"
        fi
    fi
}