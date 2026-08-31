#!/usr/bin/env bash
# wslutil-list helpers — sourced by bin/wslutil-list and BATS. Not wslutil-info.

wslutil_list_parse_distro_list() {
    awk '
        BEGIN { IGNORECASE=1 }
        NR==1 && /NAME/ { next }
        NF==0 { next }
        {
            def="no"
            if ($1=="*") { def="yes"; $1=""; sub(/^ +/, "") }
            if (NF<2) next
            ver=$NF
            state=$(NF-1)
            name=$1
            for (i=2; i<=NF-2; i++) name=name " " $i
            gsub(/\r/, "", name)
            gsub(/\r/, "", state)
            gsub(/\r/, "", ver)
            print name "\t" state "\t" ver "\t" def
        }'
}

wslutil_list_pretty_name() {
    local f="$1" line val
    [[ -f "$f" ]] || return 1
    line="$(grep -E '^PRETTY_NAME=' "$f" | tail -n1)" || return 1
    [[ -n "$line" ]] || return 1
    val="${line#PRETTY_NAME=}"
    val="${val%$'\r'}"
    if [[ "$val" == \"*\" ]]; then
        val="${val#\"}"
        val="${val%\"}"
    elif [[ "$val" == \'*\' ]]; then
        val="${val#\'}"
        val="${val%\'}"
    fi
    [[ -n "$val" ]] || return 1
    printf '%s\n' "$val"
}

wslutil_list_trim() {
    local s="$1"
    s="${s//$'\r'/}"
    s="${s//$'\n'/}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

wslutil_list_format_hostname() {
    local live configured
    live="$(wslutil_list_trim "${1:-}")"
    configured="$(wslutil_list_trim "${2:-}")"
    if [[ -z "$live" ]]; then
        printf '%s\n' "-"
        return 0
    fi
    if [[ -n "$configured" && "$configured" != "$live" ]]; then
        printf '%s (%s)\n' "$live" "$configured"
    else
        printf '%s\n' "$live"
    fi
}

wslutil_list_hostname_configured_value() {
    local live configured
    live="$(wslutil_list_trim "${1:-}")"
    configured="$(wslutil_list_trim "${2:-}")"
    if [[ -n "$configured" && "$configured" != "$live" ]]; then
        printf '%s\n' "$configured"
    fi
}
