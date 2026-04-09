#!/usr/bin/env bash
# Handler for EXEC (run shell command)

handle_exec() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        die "EXEC: missing command"
    fi
    echo "⚡ Running: $cmd"
    # Safer than eval: use bash -c with proper quoting
    bash -c "$cmd" || warn "Command exited with non-zero status"
}