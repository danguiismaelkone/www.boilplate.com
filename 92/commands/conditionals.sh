#!/usr/bin/env bash
# Handlers for IF, ELSE, ENDIF – portable to Bash 3

init_conditionals() {
    COND_STACK=""        # string of 't' and 'f' representing condition results
    COND_DEPTH=0
    SKIP_LEVEL=0
}

handle_if() {
    local rest="$1"
    local result=false

    # Parse IF condition
    if [[ "$rest" =~ ^EXISTS[[:space:]]+(.+)$ ]]; then
        local path="${BASH_REMATCH[1]}"
        if [[ -e "$path" ]]; then
            result=true
            log_debug "IF EXISTS $path → true"
        else
            log_debug "IF EXISTS $path → false"
        fi
    elif [[ "$rest" =~ ^NOT[[:space:]]+EXISTS[[:space:]]+(.+)$ ]]; then
        local path="${BASH_REMATCH[1]}"
        if [[ ! -e "$path" ]]; then
            result=true
            log_debug "IF NOT EXISTS $path → true"
        else
            log_debug "IF NOT EXISTS $path → false"
        fi
    elif [[ "$rest" =~ ^EQUALS[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local expected="${BASH_REMATCH[2]}"
        local actual=$(get_var "$var_name")
        if [[ "$actual" == "$expected" ]]; then
            result=true
            log_debug "IF EQUALS $var_name \"$expected\" → true (actual: \"$actual\")"
        else
            log_debug "IF EQUALS $var_name \"$expected\" → false (actual: \"$actual\")"
        fi
    elif [[ "$rest" =~ ^NOT[[:space:]]+EQUALS[[:space:]]+([^[:space:]]+)[[:space:]]+(.+)$ ]]; then
        local var_name="${BASH_REMATCH[1]}"
        local expected="${BASH_REMATCH[2]}"
        local actual=$(get_var "$var_name")
        if [[ "$actual" != "$expected" ]]; then
            result=true
            log_debug "IF NOT EQUALS $var_name \"$expected\" → true (actual: \"$actual\")"
        else
            log_debug "IF NOT EQUALS $var_name \"$expected\" → false (actual: \"$actual\")"
        fi
    elif [[ "$rest" =~ ^SUCCESS[[:space:]]+(.+)$ ]]; then
        local cmd="${BASH_REMATCH[1]}"
        log_debug "Running SUCCESS check: $cmd"
        if bash -c "$cmd" >/dev/null 2>&1; then
            result=true
            log_debug "IF SUCCESS → true"
        else
            log_debug "IF SUCCESS → false"
        fi
    else
        die "Invalid IF syntax: $rest"
    fi

    # Push result onto stack ('t' or 'f')
    local result_char='f'
    if [[ "$result" == true ]]; then
        result_char='t'
    fi
    COND_STACK="${COND_STACK}${result_char}"
    COND_DEPTH=$((COND_DEPTH + 1))

    if [[ "$result_char" == 'f' ]]; then
        SKIP_LEVEL=$((SKIP_LEVEL + 1))
        log_debug "Condition false, skipping inner commands (skip_level=$SKIP_LEVEL)"
    fi
}

handle_else() {
    if [[ $COND_DEPTH -eq 0 ]]; then
        die "ELSE without matching IF"
    fi

    local last_char="${COND_STACK: -1}"   # last character of string
    if [[ "$last_char" == 't' ]]; then
        # IF was true -> now skip the ELSE block
        SKIP_LEVEL=$((SKIP_LEVEL + 1))
        log_debug "ELSE: IF was true, now skipping ELSE block (skip_level=$SKIP_LEVEL)"
    else
        # IF was false -> we were skipping, now execute ELSE block
        if [[ $SKIP_LEVEL -gt 0 ]]; then
            SKIP_LEVEL=$((SKIP_LEVEL - 1))
            log_debug "ELSE: IF was false, now executing ELSE block (skip_level=$SKIP_LEVEL)"
        fi
    fi
}

handle_endif() {
    if [[ $COND_DEPTH -eq 0 ]]; then
        die "ENDIF without matching IF"
    fi

    local last_char="${COND_STACK: -1}"
    # Pop last character
    COND_STACK="${COND_STACK%?}"
    COND_DEPTH=$((COND_DEPTH - 1))

    if [[ "$last_char" == 'f' ]]; then
        if [[ $SKIP_LEVEL -gt 0 ]]; then
            SKIP_LEVEL=$((SKIP_LEVEL - 1))
            log_debug "ENDIF: false condition closed, resume execution (skip_level=$SKIP_LEVEL)"
        fi
    fi
}