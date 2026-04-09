#!/usr/bin/env bash
# Linter functions – validate instruction syntax without execution

LINT_ERRORS=0
LINT_WARNINGS=0
LINT_STATE=""  # tracks WRITE/APPEND for END balancing
LINT_CURRENT_FILE=""

lint_error() {
    echo "❌ Lint error (line $LINT_LINE_NUM): $*" >&2
    ((LINT_ERRORS++))
}

lint_warn() {
    echo "⚠️ Lint warning (line $LINT_LINE_NUM): $*" >&2
    ((LINT_WARNINGS++))
}

# Validate MKDIR
lint_mkdir() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "MKDIR missing directory argument"
        return 1
    fi
    return 0
}

# Validate CREATE
lint_create() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "CREATE missing file argument"
        return 1
    fi
    return 0
}

# Validate DELETE
lint_delete() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "DELETE missing file argument"
        return 1
    fi
    return 0
}

# Validate RMDIR
lint_rmdir() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "RMDIR missing directory argument"
        return 1
    fi
    return 0
}

# Validate COPY
lint_copy() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        lint_error "COPY requires exactly two arguments (source destination)"
        return 1
    fi
    return 0
}

# Validate MOVE
lint_move() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 2 ]]; then
        lint_error "MOVE requires exactly two arguments (source destination)"
        return 1
    fi
    return 0
}

# Validate WRITE start
lint_write_start() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "WRITE missing file argument"
        return 1
    fi
    if [[ -n "$LINT_STATE" ]]; then
        lint_error "WRITE encountered while already inside a WRITE/APPEND block (missing END?)"
        return 1
    fi
    LINT_STATE="WRITE"
    LINT_CURRENT_FILE="$rest"
    return 0
}

# Validate APPEND start
lint_append_start() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "APPEND missing file argument"
        return 1
    fi
    if [[ -n "$LINT_STATE" ]]; then
        lint_error "APPEND encountered while already inside a WRITE/APPEND block (missing END?)"
        return 1
    fi
    LINT_STATE="APPEND"
    LINT_CURRENT_FILE="$rest"
    return 0
}

# Validate END
lint_end() {
    if [[ -z "$LINT_STATE" ]]; then
        lint_error "END without matching WRITE or APPEND"
        return 1
    fi
    LINT_STATE=""
    LINT_CURRENT_FILE=""
    return 0
}

# Validate REPLACE
lint_replace() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -ne 3 ]]; then
        lint_error "REPLACE requires exactly three arguments: file old new"
        return 1
    fi
    return 0
}

# Validate EXEC
lint_exec() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        lint_error "EXEC missing command"
        return 1
    fi
    return 0
}

# Validate JSONINSERT
lint_jsoninsert() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -lt 3 ]]; then
        lint_error "JSONINSERT requires at least three arguments: file key value [json_path]"
        return 1
    fi
    # Optional: check if file exists? Not needed – lint only syntax.
    return 0
}

# Final lint summary (called at end of file)
lint_final_check() {
    if [[ -n "$LINT_STATE" ]]; then
        lint_error "Unclosed WRITE/APPEND block (started for $LINT_CURRENT_FILE) – missing END"
    fi
    if [[ $LINT_ERRORS -eq 0 ]]; then
        echo "✅ Lint passed: $LINT_ERRORS errors, $LINT_WARNINGS warnings"
        return 0
    else
        echo "❌ Lint failed: $LINT_ERRORS errors, $LINT_WARNINGS warnings"
        return 1
    fi
}