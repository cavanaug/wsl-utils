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

LIST_ROWS=()
LIST_WANT_LOCATION=0
LIST_WANT_JSON=0

wslutil_list_cmd_wsl() { echo "${WSLUTIL_LIST_WSL:-wsl.exe}"; }
wslutil_list_cmd_win_utf8() {
    if [[ -n "${WSLUTIL_LIST_WIN_UTF8:-}" ]]; then
        echo "$WSLUTIL_LIST_WIN_UTF8"
        return
    fi
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "$here/../bin/win-utf8" ]]; then
        echo "$here/../bin/win-utf8"
    else
        echo "win-utf8"
    fi
}
wslutil_list_cmd_wslpath() { echo "${WSLUTIL_LIST_WSLPATH:-wslpath}"; }
wslutil_list_cmd_powershell() { echo "${WSLUTIL_LIST_POWERSHELL:-powershell.exe}"; }

wslutil_list_resolve_file() {
    local name="$1" rel="$2"
    if [[ -n "${WSLUTIL_LIST_FILE_ROOT:-}" ]]; then
        printf '%s\n' "${WSLUTIL_LIST_FILE_ROOT}/${name}/${rel}"
        return 0
    fi
    if [[ -n "${WSL_DISTRO_NAME:-}" && "$name" == "$WSL_DISTRO_NAME" ]]; then
        printf '/%s\n' "$rel"
        return 0
    fi
    local wp unc wslp
    wp="$(wslutil_list_cmd_wslpath)"
    unc="\\\\wsl.localhost\\${name}\\${rel//\//\\}"
    wslp="$("$wp" -u "$unc" 2>/dev/null || true)"
    if [[ -n "$wslp" && -e "$wslp" ]]; then
        printf '%s\n' "$wslp"
        return 0
    fi
    printf '/mnt/wsl.localhost/%s/%s\n' "$name" "$rel"
}

wslutil_list_read_line() {
    local f="$1" line
    [[ -f "$f" && -r "$f" ]] || return 0
    IFS= read -r line <"$f" || true
    wslutil_list_trim "$line"
    printf '\n'
}

wslutil_list_wslconf_hostname() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    crudini --get "$f" network hostname 2>/dev/null || true
}

wslutil_list_lxss_map() {
    # Task 4 fills this. Default: no output.
    if [[ -n "${WSLUTIL_LIST_LXSS:-}" && -f "$WSLUTIL_LIST_LXSS" ]]; then
        cat "$WSLUTIL_LIST_LXSS"
        return 0
    fi
    return 0
}

wslutil_list_collect() {
    LIST_ROWS=()
    local ws u8 raw line name state ver def typ host hconf loc
    ws="$(wslutil_list_cmd_wsl)"
    u8="$(wslutil_list_cmd_win_utf8)"
    if ! raw="$("$ws" -l -v 2>/dev/null | "$u8" 2>/dev/null)"; then
        echo "wslutil-list: failed to list distros" >&2
        return 1
    fi
    local parsed
    parsed="$(printf '%s\n' "$raw" | wslutil_list_parse_distro_list)"
    if [[ -z "$parsed" ]]; then
        echo "wslutil-list: no distros found" >&2
        return 1
    fi
    declare -A lxss=()
    if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
        while IFS=$'\t' read -r n b; do
            [[ -n "$n" ]] || continue
            b="${b#\\\\?\\}"
            lxss["$n"]="$b"
        done < <(wslutil_list_lxss_map)
    fi
    while IFS=$'\t' read -r name state ver def; do
        [[ -n "$name" ]] || continue
        typ=""
        host=""
        hconf=""
        loc=""
        if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
            loc="${lxss[$name]:-}"
        fi
        if [[ "$state" == "Running" ]]; then
            typ="$(wslutil_list_pretty_name "$(wslutil_list_resolve_file "$name" etc/os-release)" 2>/dev/null || true)"
            host="$(wslutil_list_read_line "$(wslutil_list_resolve_file "$name" proc/sys/kernel/hostname)")"
            hconf="$(wslutil_list_wslconf_hostname "$(wslutil_list_resolve_file "$name" etc/wsl.conf)")"
            hconf="$(wslutil_list_hostname_configured_value "$host" "$hconf")"
        fi
        LIST_ROWS+=("${name}"$'\t'"${state}"$'\t'"${ver}"$'\t'"${def}"$'\t'"${typ}"$'\t'"${host}"$'\t'"${hconf}"$'\t'"${loc}")
    done <<<"$parsed"
    [[ ${#LIST_ROWS[@]} -gt 0 ]] || {
        echo "wslutil-list: no distros found" >&2
        return 1
    }
}

wslutil_list_dash() {
    if [[ -n "$1" ]]; then printf '%s' "$1"; else printf '%s' "-"; fi
}

wslutil_list_print_human() {
    local row name state ver def typ host hconf loc star
    local -a stars names states vers types hosts locs
    local w_name=4 w_state=5 w_ver=3 w_type=4 w_host=8 w_loc=8
    stars=(); names=(); states=(); vers=(); types=(); hosts=(); locs=()
    for row in "${LIST_ROWS[@]}"; do
        IFS=$'\t' read -r name state ver def typ host hconf loc <<<"$row"
        star=" "
        [[ "$def" == "yes" ]] && star="*"
        [[ "$ver" =~ ^[12]$ ]] || ver="-"
        typ="$(wslutil_list_dash "$typ")"
        if [[ -n "$host" ]]; then
            host="$(wslutil_list_format_hostname "$host" "$hconf")"
        else
            host="-"
        fi
        loc="$(wslutil_list_dash "$loc")"
        stars+=("$star")
        names+=("$name")
        states+=("$state")
        vers+=("$ver")
        types+=("$typ")
        hosts+=("$host")
        locs+=("$loc")
        (( ${#name} > w_name )) && w_name=${#name}
        (( ${#state} > w_state )) && w_state=${#state}
        (( ${#ver} > w_ver )) && w_ver=${#ver}
        (( ${#typ} > w_type )) && w_type=${#typ}
        (( ${#host} > w_host )) && w_host=${#host}
        (( ${#loc} > w_loc )) && w_loc=${#loc}
    done
    if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
        printf '%s %-*s  %-*s  %-*s  %-*s  %-*s  %s\n' " " "$w_name" "NAME" "$w_state" "STATE" "$w_ver" "WSL" "$w_type" "TYPE" "$w_host" "HOSTNAME" "LOCATION"
        local i
        for i in "${!names[@]}"; do
            printf '%s %-*s  %-*s  %-*s  %-*s  %-*s  %s\n' "${stars[$i]}" "$w_name" "${names[$i]}" "$w_state" "${states[$i]}" "$w_ver" "${vers[$i]}" "$w_type" "${types[$i]}" "$w_host" "${hosts[$i]}" "${locs[$i]}"
        done
    else
        printf '%s %-*s  %-*s  %-*s  %-*s  %s\n' " " "$w_name" "NAME" "$w_state" "STATE" "$w_ver" "WSL" "$w_type" "TYPE" "HOSTNAME"
        local i
        for i in "${!names[@]}"; do
            printf '%s %-*s  %-*s  %-*s  %-*s  %s\n' "${stars[$i]}" "$w_name" "${names[$i]}" "$w_state" "${states[$i]}" "$w_ver" "${vers[$i]}" "$w_type" "${types[$i]}" "${hosts[$i]}"
        done
    fi
}

wslutil_list_print_json() {
    local tmp row name state ver def typ host hconf loc
    tmp="$(mktemp)"
    yq eval -n '[]' >"$tmp"
    for row in "${LIST_ROWS[@]}"; do
        IFS=$'\t' read -r name state ver def typ host hconf loc <<<"$row"
        export _ln="$name" _ls="$state" _lv="$ver" _ld="$def" _lt="$typ" _lh="$host" _lc="$hconf" _ll="$loc"
        if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
            yq eval -i '. += [{
                "name": strenv(_ln),
                "default": (strenv(_ld) == "yes"),
                "state": strenv(_ls),
                "wslVersion": (strenv(_lv) | select(. == "1" or . == "2") | tonumber // null),
                "type": (strenv(_lt) | select(length > 0) // null),
                "hostname": (strenv(_lh) | select(length > 0) // null),
                "hostnameConfigured": (strenv(_lc) | select(length > 0) // null),
                "location": (strenv(_ll) | select(length > 0) // null)
            }]' "$tmp"
        else
            yq eval -i '. += [{
                "name": strenv(_ln),
                "default": (strenv(_ld) == "yes"),
                "state": strenv(_ls),
                "wslVersion": (strenv(_lv) | select(. == "1" or . == "2") | tonumber // null),
                "type": (strenv(_lt) | select(length > 0) // null),
                "hostname": (strenv(_lh) | select(length > 0) // null),
                "hostnameConfigured": (strenv(_lc) | select(length > 0) // null)
            }]' "$tmp"
        fi
    done
    yq eval -o json "$tmp"
    rm -f "$tmp"
}
