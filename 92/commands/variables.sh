#!/usr/bin/env bash
# Handlers for SET and RENDER

handle_set() {
    local rest="$1"
    if [[ -z "$rest" ]]; then
        die "SET: missing assignment"
    fi
    # Parse NAME=VALUE
    local name="${rest%%=*}"
    local value="${rest#*=}"
    if [[ -z "$name" || -z "$value" ]]; then
        die "SET: invalid format (expected NAME=VALUE): $rest"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "SET $name=\"$value\""
        return 0
    fi
    set_var "$name" "$value"
    log_debug "Set variable: $name=\"$value\""
}

handle_render() {
    local rest="$1"
    split_args "$rest"
    if [[ ${#ARGS[@]} -lt 2 ]]; then
        die "RENDER requires at least two arguments: template output [--vars file]"
    fi
    local template="${ARGS[0]}"
    local output="${ARGS[1]}"
    local vars_file=""

    # Check for --vars option
    for i in "${!ARGS[@]}"; do
        if [[ "${ARGS[$i]}" == "--vars" && $((i+1)) -lt ${#ARGS[@]} ]]; then
            vars_file="${ARGS[$((i+1))]}"
            break
        fi
    done

    if [[ "$DRY_RUN" == true ]]; then
        dry_run_echo "RENDER $template -> $output (vars from ${vars_file:-current environment})"
        return 0
    fi

    if [[ ! -f "$template" ]]; then
        die "Template file not found: $template"
    fi

    # Load variables from file if provided
    if [[ -n "$vars_file" ]]; then
        if [[ ! -f "$vars_file" ]]; then
            die "Vars file not found: $vars_file"
        fi
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue
            local name="${line%%=*}"
            local value="${line#*=}"
            set_var "$name" "$value"
        done < "$vars_file"
    fi

    # Render using envsubst if available, else sed
    local tmpfile="$TEMP_DIR/render_$$.tmp"
    cp "$template" "$tmpfile"

    # Replace {{VAR}} and $VAR with values
    for i in "${!VAR_NAMES[@]}"; do
        local name="${VAR_NAMES[$i]}"
        local value="${VAR_VALUES[$i]}"
        local escaped_value=$(printf '%s\n' "$value" | sed 's/[\/&]/\\&/g')
        sed_i "$tmpfile" "s/{{$name}}/$escaped_value/g"
        sed_i "$tmpfile" "s/\\\$$name\b/$escaped_value/g"
    done

    mkdir -p "$(dirname "$output")"
    mv "$tmpfile" "$output"
    log_info "🎨 Rendered $template -> $output"
}