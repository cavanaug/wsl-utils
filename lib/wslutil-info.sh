# lib/wslutil-info.sh — helpers for wslutil-info (safe to source from tests)

wslutil_info_norm_bool() {
    local v="${1,,}"
    case "$v" in
    true | yes | 1) echo true ;;
    false | no | 0) echo false ;;
    *) echo "$1" ;;
    esac
}

wslutil_info_always_show() {
    local kind="$1" section="$2" key="$3"
    case "$kind:$section:$key" in
    wslconfig:wsl2:memory | wslconfig:wsl2:processors | wslconfig:wsl2:swap | \
        wslconfig:wsl2:swapFile | wslconfig:wsl2:kernel | wslconfig:wsl2:kernelModules | \
        wslconfig:wsl2:kernelCommandLine) return 0 ;;
    wslconf:network:hostname | wslconf:user:default | wslconf:boot:command | \
        wslconf:boot:systemd) return 0 ;;
    *) return 1 ;;
    esac
}

# stdout: documented default or formula string. Return 1 if key is unknown.
wslutil_info_documented_default() {
    local kind="$1" section="$2" key="$3"
    case "$kind:$section:$key" in
    wslconfig:wsl2:localhostForwarding) echo true ;;
    wslconfig:wsl2:safeMode) echo false ;;
    wslconfig:wsl2:guiApplications) echo true ;;
    wslconfig:wsl2:debugConsole) echo false ;;
    wslconfig:wsl2:maxCrashDumpCount) echo 10 ;;
    wslconfig:wsl2:nestedVirtualization) echo true ;;
    wslconfig:wsl2:vmIdleTimeout) echo 60000 ;;
    wslconfig:wsl2:dnsProxy) echo true ;;
    wslconfig:wsl2:networkingMode) echo nat ;;
    wslconfig:wsl2:firewall) echo true ;;
    wslconfig:wsl2:dnsTunneling) echo true ;;
    wslconfig:wsl2:autoProxy) echo true ;;
    wslconfig:wsl2:defaultVhdSize) echo 1099511627776 ;;
    wslconfig:wsl2:memory) echo "50% of host RAM" ;;
    wslconfig:wsl2:processors) echo "host logical CPUs" ;;
    wslconfig:wsl2:swap) echo "25% of memory, rounded up to nearest GB" ;;
    wslconfig:wsl2:swapFile) echo '%Temp%\swap.vhdx' ;;
    wslconfig:wsl2:kernel) echo "Microsoft inbox kernel" ;;
    wslconfig:wsl2:kernelModules) echo "inbox modules VHD" ;;
    wslconfig:wsl2:kernelCommandLine) echo "(none)" ;;
    wslconfig:experimental:autoMemoryReclaim) echo dropCache ;;
    wslconfig:experimental:sparseVhd) echo false ;;
    wslconfig:experimental:bestEffortDnsParsing) echo false ;;
    wslconfig:experimental:dnsTunnelingIpAddress) echo 10.255.255.254 ;;
    wslconfig:experimental:initialAutoProxyTimeout) echo 1000 ;;
    wslconfig:experimental:hostAddressLoopback) echo false ;;
    wslconf:automount:enabled) echo true ;;
    wslconf:automount:mountFsTab) echo true ;;
    wslconf:automount:root) echo /mnt/ ;;
    wslconf:network:generateHosts) echo true ;;
    wslconf:network:generateResolvConf) echo true ;;
    wslconf:interop:enabled) echo true ;;
    wslconf:interop:appendWindowsPath) echo true ;;
    wslconf:boot:protectBinfmt) echo true ;;
    wslconf:gpu:enabled) echo true ;;
    wslconf:time:useWindowsTimezone) echo true ;;
    wslconf:network:hostname) echo "Windows hostname" ;;
    wslconf:user:default) echo "distro default user" ;;
    wslconf:boot:command) echo "(none)" ;;
    wslconf:boot:systemd) echo "distro default" ;;
    *) return 1 ;;
    esac
}

# 0 = omit (equals default), 1 = keep
wslutil_info_should_omit() {
    local kind="$1" section="$2" key="$3" value="$4"
    if wslutil_info_always_show "$kind" "$section" "$key"; then
        return 1
    fi
    local def
    if ! def="$(wslutil_info_documented_default "$kind" "$section" "$key")"; then
        return 1
    fi
    local nv nd
    nv="$(wslutil_info_norm_bool "$value")"
    nd="$(wslutil_info_norm_bool "$def")"
    if [[ "$key" == "networkingMode" ]]; then
        [[ "${nv,,}" == "${nd,,}" ]] && return 0
        return 1
    fi
    if [[ "$key" == "defaultVhdSize" ]]; then
        [[ "$nv" == "$nd" || "${nv^^}" == "1TB" ]] && return 0
        return 1
    fi
    [[ "$nv" == "$nd" ]] && return 0
    return 1
}

wslutil_info_cmd_wslinfo() { echo "${WSLUTIL_INFO_WSLINFO:-wslinfo}"; }
wslutil_info_cmd_wsl() { echo "${WSLUTIL_INFO_WSL:-wsl.exe}"; }
wslutil_info_cmd_win_utf8() {
    if [[ -n "${WSLUTIL_INFO_WIN_UTF8:-}" ]]; then
        echo "$WSLUTIL_INFO_WIN_UTF8"
        return
    fi
    local b="${_wsu_bin:-}"
    if [[ -n "$b" && -x "$b/win-utf8" ]]; then
        echo "$b/win-utf8"
    else
        echo "win-utf8"
    fi
}

wslutil_info_collect_versions() {
    INFO_VER_WSL=""
    INFO_VER_WSL_EXE=""
    INFO_VER_KERNEL=""
    INFO_VER_WSLG=""
    INFO_VER_MSRDC=""
    INFO_VER_D3D=""
    INFO_VER_DXCORE=""
    INFO_VER_WINDOWS=""
    local wi ws u8
    wi="$(wslutil_info_cmd_wslinfo)"
    ws="$(wslutil_info_cmd_wsl)"
    u8="$(wslutil_info_cmd_win_utf8)"
    if command -v "$wi" >/dev/null 2>&1 || [[ -x "$wi" ]]; then
        INFO_VER_WSL="$("$wi" --version 2>/dev/null | tr -d '\r' || true)"
    fi
    local ver
    if ver="$("$ws" --version 2>/dev/null | "$u8" 2>/dev/null || true)"; then
        INFO_VER_WSL_EXE="$(printf '%s\n' "$ver" | awk -F': ' '/^WSL version:/ {print $2; exit}')"
        INFO_VER_KERNEL="$(printf '%s\n' "$ver" | awk -F': ' '/^Kernel version:/ {print $2; exit}')"
        INFO_VER_WSLG="$(printf '%s\n' "$ver" | awk -F': ' '/^WSLg version:/ {print $2; exit}')"
        INFO_VER_MSRDC="$(printf '%s\n' "$ver" | awk -F': ' '/^MSRDC version:/ {print $2; exit}')"
        INFO_VER_D3D="$(printf '%s\n' "$ver" | awk -F': ' '/^Direct3D version:/ {print $2; exit}')"
        INFO_VER_DXCORE="$(printf '%s\n' "$ver" | awk -F': ' '/^DXCore version:/ {print $2; exit}')"
        INFO_VER_WINDOWS="$(printf '%s\n' "$ver" | awk -F': ' '/^Windows version:/ {print $2; exit}')"
    fi
}

wslutil_info_collect_runtime() {
    INFO_RT_NET=""
    INFO_RT_VMID=""
    INFO_RT_MSAL=""
    local wi
    wi="$(wslutil_info_cmd_wslinfo)"
    if ! command -v "$wi" >/dev/null 2>&1 && [[ ! -x "$wi" ]]; then
        return 0
    fi
    INFO_RT_NET="$("$wi" --networking-mode 2>/dev/null | tr -d '\r' || true)"
    INFO_RT_VMID="$("$wi" --vm-id 2>/dev/null | tr -d '\r' || true)"
    INFO_RT_MSAL="$("$wi" --msal-proxy-path 2>/dev/null | tr -d '\r' || true)"
}

wslutil_info_or_unavail() {
    if [[ -n "${1:-}" ]]; then
        printf '%s' "$1"
    else
        printf 'unavailable'
    fi
}

wslutil_info_print_human_host_versions() {
    printf '== Host ==\n'
    printf 'Versions\n'
    printf '  WSL:       %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WSL:-}")"
    if [[ -n "${INFO_VER_WSL:-}" && -n "${INFO_VER_WSL_EXE:-}" && "${INFO_VER_WSL}" != "${INFO_VER_WSL_EXE}" ]]; then
        printf '  WSL (exe): %s  (mismatch)\n' "$INFO_VER_WSL_EXE"
    fi
    printf '  Kernel:    %s\n' "$(wslutil_info_or_unavail "${INFO_VER_KERNEL:-}")"
    printf '  WSLg:      %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WSLG:-}")"
    printf '  MSRDC:     %s\n' "$(wslutil_info_or_unavail "${INFO_VER_MSRDC:-}")"
    printf '  Direct3D:  %s\n' "$(wslutil_info_or_unavail "${INFO_VER_D3D:-}")"
    printf '  DXCore:    %s\n' "$(wslutil_info_or_unavail "${INFO_VER_DXCORE:-}")"
    printf '  Windows:   %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WINDOWS:-}")"
}

wslutil_info_print_human_runtime() {
    printf 'Runtime\n'
    printf '  networkingMode:  %s\n' "$(wslutil_info_or_unavail "${INFO_RT_NET:-}")"
    printf '  configured:      %s\n' "${INFO_RT_NET_CFG:-unset (default nat)}"
    printf '  vmId:            %s\n' "$(wslutil_info_or_unavail "${INFO_RT_VMID:-}")"
    printf '  msalProxyPath:   %s\n' "$(wslutil_info_or_unavail "${INFO_RT_MSAL:-}")"
}

wslutil_info_filter_ini_file() {
    local kind="$1" path="$2"
    [[ -f "$path" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    local section key value def
    while IFS= read -r section; do
        [[ -n "$section" ]] || continue
        while IFS= read -r key; do
            [[ -n "$key" ]] || continue
            value="$(crudini --get "$path" "$section" "$key" 2>/dev/null || true)"
            if wslutil_info_should_omit "$kind" "$section" "$key" "$value"; then
                continue
            fi
            def="$(wslutil_info_documented_default "$kind" "$section" "$key" 2>/dev/null || echo "")"
            printf '%s\t%s\t%s\t%s\n' "$section" "$key" "$value" "$def"
        done < <(crudini --get "$path" "$section" 2>/dev/null || true)
    done < <(crudini --get "$path" 2>/dev/null || true)
}

wslutil_info_filter_wslgconfig() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    local key value
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        value="$(crudini --get "$path" "system-distro-env" "$key" 2>/dev/null || true)"
        printf 'system-distro-env\t%s\t%s\n' "$key" "$value"
    done < <(crudini --get "$path" "system-distro-env" 2>/dev/null || true)
}

wslutil_info_print_human_ini_block() {
    local title="$1" winpath="$2" wslpath="$3" lines="${4:-}" unavail_reason="${5:-}"
    local exists="${6:-0}"
    printf '%s\n' "$title"
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ "$exists" != 1 ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if [[ -n "$unavail_reason" ]]; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    if [[ -z "$lines" ]]; then
        printf '  (all defaults)\n'
        return 0
    fi
    local lastsec="" section key value def
    while IFS=$'\t' read -r section key value def; do
        if [[ "$section" != "$lastsec" ]]; then
            printf '  [%s]\n' "$section"
            lastsec="$section"
        fi
        if [[ -n "$def" ]]; then
            printf '    %s = %s  (default: %s)\n' "$key" "$value" "$def"
        else
            printf '    %s = %s\n' "$key" "$value"
        fi
    done <<<"$lines"
}

wslutil_info_print_human_wslg() {
    local winpath="$1" wslpath="$2" lines="${3:-}" unavail_reason="${4:-}"
    local exists="${5:-0}"
    printf '.wslgconfig\n'
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ "$exists" != 1 ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if [[ -n "$unavail_reason" ]]; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    if [[ -z "$lines" ]]; then
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  [system-distro-env]\n'
    local _s key value
    while IFS=$'\t' read -r _s key value; do
        printf '    %s = %s\n' "$key" "$value"
    done <<<"$lines"
}

wslutil_info_parse_distro_list() {
    awk '
        BEGIN { IGNORECASE=1 }
        NR==1 && /NAME/ { next }
        {
            def="no"
            if ($1=="*") { def="yes"; $1="" ; sub(/^ +/, "") }
            name=$1; state=$(NF-1); ver=$NF
            print name "\t" state "\t" ver "\t" def
        }'
}

INFO_DISTRO_ROWS=()
INFO_DISTRO_LIST_OK=0

wslutil_info_collect_distro_list() {
    INFO_DISTRO_ROWS=()
    INFO_DISTRO_LIST_OK=0
    local ws u8 raw
    ws="$(wslutil_info_cmd_wsl)"
    u8="$(wslutil_info_cmd_win_utf8)"
    if ! raw="$("$ws" -l -v 2>/dev/null | "$u8" 2>/dev/null)"; then
        return 0
    fi
    [[ -n "$raw" ]] || return 0
    mapfile -t INFO_DISTRO_ROWS < <(printf '%s\n' "$raw" | wslutil_info_parse_distro_list)
    [[ ${#INFO_DISTRO_ROWS[@]} -gt 0 ]] || return 0
    INFO_DISTRO_LIST_OK=1
}

wslutil_info_list_distros() {
    local ws u8 raw
    ws="$(wslutil_info_cmd_wsl)"
    u8="$(wslutil_info_cmd_win_utf8)"
    raw="$("$ws" -l -v 2>/dev/null | "$u8" 2>/dev/null || true)"
    printf '%s\n' "$raw" | wslutil_info_parse_distro_list
}

wslutil_info_lxss_lookup() {
    local want="$1" line n b v u
    if [[ -n "${WSLUTIL_INFO_LXSS:-}" && -f "$WSLUTIL_INFO_LXSS" ]]; then
        while IFS=$'\t' read -r n b v u; do
            if [[ "$n" == "$want" ]]; then
                b="${b#\\\\?\\}"
                printf '%s\t%s\t%s\n' "$b" "$v" "$u"
                return 0
            fi
        done <"$WSLUTIL_INFO_LXSS"
        return 1
    fi
    local ps out
    ps="$(command -v powershell.exe 2>/dev/null || true)"
    [[ -n "$ps" ]] || return 1
    out="$("$ps" -NoProfile -Command "Get-ChildItem HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Lxss | ForEach-Object { \$n = \$_.GetValue('DistributionName'); if (\$n) { \$n + [char]9 + \$_.GetValue('BasePath') + [char]9 + \$_.GetValue('Version') + [char]9 + \$_.GetValue('DefaultUid') } }" 2>/dev/null | "$(wslutil_info_cmd_win_utf8)" || true)"
    while IFS=$'\t' read -r n b v u; do
        if [[ "$n" == "$want" ]]; then
            b="${b#\\\\?\\}"
            printf '%s\t%s\t%s\n' "$b" "$v" "$u"
            return 0
        fi
    done <<<"$out"
    return 1
}

wslutil_info_resolve_distro() {
    local want="${1:-${WSL_DISTRO_NAME:-}}"
    [[ -n "$want" ]] || return 1
    if [[ ${#INFO_DISTRO_ROWS[@]} -eq 0 && INFO_DISTRO_LIST_OK -eq 0 ]]; then
        wslutil_info_collect_distro_list
    fi
    local row dname
    for row in "${INFO_DISTRO_ROWS[@]}"; do
        IFS=$'\t' read -r dname _rest <<<"$row"
        if [[ "$dname" == "$want" ]]; then
            printf '%s\n' "$row"
            return 0
        fi
    done
    return 1
}

wslutil_info_collect_host_config() {
    INFO_WSLCONFIG_WIN=""
    INFO_WSLCONFIG_WSL=""
    INFO_WSLCONFIG_EXISTS=0
    INFO_WSLCONFIG_LINES=""
    INFO_WSLCONFIG_UNAVAIL_REASON=""
    INFO_WSLGCONFIG_WIN=""
    INFO_WSLGCONFIG_WSL=""
    INFO_WSLGCONFIG_EXISTS=0
    INFO_WSLG_LINES=""
    INFO_WSLG_UNAVAIL_REASON=""
    if [[ -n "${WIN_USERPROFILE:-}" ]]; then
        INFO_WSLCONFIG_WSL="$WIN_USERPROFILE/.wslconfig"
        INFO_WSLGCONFIG_WSL="$WIN_USERPROFILE/.wslgconfig"
        INFO_WSLCONFIG_WIN="$(wslpath -w "$INFO_WSLCONFIG_WSL" 2>/dev/null || echo "$INFO_WSLCONFIG_WSL")"
        INFO_WSLGCONFIG_WIN="$(wslpath -w "$INFO_WSLGCONFIG_WSL" 2>/dev/null || echo "$INFO_WSLGCONFIG_WSL")"
    fi
    if [[ -e "${INFO_WSLCONFIG_WSL:-}" ]]; then
        INFO_WSLCONFIG_EXISTS=1
        if command -v crudini >/dev/null 2>&1; then
            INFO_WSLCONFIG_LINES="$(wslutil_info_filter_ini_file wslconfig "$INFO_WSLCONFIG_WSL")"
        else
            INFO_WSLCONFIG_UNAVAIL_REASON="need crudini"
        fi
    fi
    if [[ -e "${INFO_WSLGCONFIG_WSL:-}" ]]; then
        INFO_WSLGCONFIG_EXISTS=1
        if command -v crudini >/dev/null 2>&1; then
            INFO_WSLG_LINES="$(wslutil_info_filter_wslgconfig "$INFO_WSLGCONFIG_WSL")"
        else
            INFO_WSLG_UNAVAIL_REASON="need crudini"
        fi
    fi
}

wslutil_info_collect_distro_fields() {
    local name="$1" state="$2" ver="$3" def="$4"
    INFO_DISTRO_NAME="$name"
    INFO_DISTRO_STATE="$state"
    INFO_DISTRO_VER="$ver"
    INFO_DISTRO_DEFAULT=0
    [[ "$def" == "yes" ]] && INFO_DISTRO_DEFAULT=1
    INFO_DISTRO_CURRENT=0
    [[ "$name" == "${WSL_DISTRO_NAME:-}" ]] && INFO_DISTRO_CURRENT=1
    INFO_DISTRO_VHD_WIN=""
    INFO_DISTRO_VHD_WSL=""
    INFO_DISTRO_UID=""
    local base uid lxver lx
    if lx="$(wslutil_info_lxss_lookup "$name")"; then
        IFS=$'\t' read -r base lxver uid <<<"$lx"
        if [[ -n "$base" ]]; then
            INFO_DISTRO_VHD_WIN="${base}\\ext4.vhdx"
            INFO_DISTRO_VHD_WSL="$(wslpath -u "$INFO_DISTRO_VHD_WIN" 2>/dev/null || true)"
        fi
        INFO_DISTRO_UID="$uid"
    fi
    INFO_WSLCONF_AVAILABLE=0
    INFO_WSLCONF_EXISTS=0
    INFO_WSLCONF_PATH=""
    INFO_WSLCONF_LINES=""
    INFO_WSLCONF_REASON="unavailable"
    INFO_WSLCONF_UNAVAIL_REASON=""
    if [[ "$name" == "${WSL_DISTRO_NAME:-}" ]]; then
        INFO_WSLCONF_PATH="/etc/wsl.conf"
        INFO_WSLCONF_AVAILABLE=1
        if [[ -e "$INFO_WSLCONF_PATH" ]]; then
            INFO_WSLCONF_EXISTS=1
            if command -v crudini >/dev/null 2>&1; then
                INFO_WSLCONF_LINES="$(wslutil_info_filter_ini_file wslconf "$INFO_WSLCONF_PATH")"
            else
                INFO_WSLCONF_UNAVAIL_REASON="need crudini"
            fi
        fi
    elif [[ "${state,,}" == "running" ]]; then
        INFO_WSLCONF_PATH="$(wslpath -u "\\\\wsl.localhost\\${name}\\etc\\wsl.conf" 2>/dev/null || true)"
        if [[ -n "$INFO_WSLCONF_PATH" && -r "$INFO_WSLCONF_PATH" ]]; then
            INFO_WSLCONF_AVAILABLE=1
            INFO_WSLCONF_EXISTS=1
            if command -v crudini >/dev/null 2>&1; then
                INFO_WSLCONF_LINES="$(wslutil_info_filter_ini_file wslconf "$INFO_WSLCONF_PATH")"
            else
                INFO_WSLCONF_UNAVAIL_REASON="need crudini"
            fi
        else
            INFO_WSLCONF_REASON="unreadable"
        fi
    else
        INFO_WSLCONF_REASON="distro not running"
    fi
}

wslutil_info_yq_str() {
    if [[ -n "${1:-}" ]]; then
        printf '%s' "$1"
    else
        printf 'null'
    fi
}

wslutil_info_emit_json() {
    local tmp section key value def _s
    tmp="$(mktemp)"
    export _YQ_WSL _YQ_WSL_EXE _YQ_KERNEL _YQ_WSLG _YQ_MSRDC _YQ_D3D _YQ_DXCORE _YQ_WIN
    export _YQ_NET _YQ_NET_CFG _YQ_VMID _YQ_MSAL
    _YQ_WSL="$(wslutil_info_yq_str "${INFO_VER_WSL:-}")"
    _YQ_WSL_EXE="$(wslutil_info_yq_str "${INFO_VER_WSL_EXE:-}")"
    _YQ_KERNEL="$(wslutil_info_yq_str "${INFO_VER_KERNEL:-}")"
    _YQ_WSLG="$(wslutil_info_yq_str "${INFO_VER_WSLG:-}")"
    _YQ_MSRDC="$(wslutil_info_yq_str "${INFO_VER_MSRDC:-}")"
    _YQ_D3D="$(wslutil_info_yq_str "${INFO_VER_D3D:-}")"
    _YQ_DXCORE="$(wslutil_info_yq_str "${INFO_VER_DXCORE:-}")"
    _YQ_WIN="$(wslutil_info_yq_str "${INFO_VER_WINDOWS:-}")"
    _YQ_NET="$(wslutil_info_yq_str "${INFO_RT_NET:-}")"
    _YQ_NET_CFG="$(wslutil_info_yq_str "${INFO_RT_NET_CFG:-}")"
    _YQ_VMID="$(wslutil_info_yq_str "${INFO_RT_VMID:-}")"
    _YQ_MSAL="$(wslutil_info_yq_str "${INFO_RT_MSAL:-}")"
    local mismatch=false
    if [[ -n "${INFO_VER_WSL:-}" && -n "${INFO_VER_WSL_EXE:-}" && "${INFO_VER_WSL}" != "${INFO_VER_WSL_EXE}" ]]; then
        mismatch=true
    fi
    yq eval -n \
        '.host.versions.wsl = (strenv(_YQ_WSL) | select(. != "null") // null) |
        .host.versions.wslExe = (strenv(_YQ_WSL_EXE) | select(. != "null") // null) |
        .host.versions.mismatch = '"$mismatch"' |
        .host.versions.kernel = (strenv(_YQ_KERNEL) | select(. != "null") // null) |
        .host.versions.wslg = (strenv(_YQ_WSLG) | select(. != "null") // null) |
        .host.versions.msrdc = (strenv(_YQ_MSRDC) | select(. != "null") // null) |
        .host.versions.direct3d = (strenv(_YQ_D3D) | select(. != "null") // null) |
        .host.versions.dxcore = (strenv(_YQ_DXCORE) | select(. != "null") // null) |
        .host.versions.windows = (strenv(_YQ_WIN) | select(. != "null") // null) |
        .host.runtime.networkingMode = (strenv(_YQ_NET) | select(. != "null") // null) |
        .host.runtime.configuredNetworkingMode = (strenv(_YQ_NET_CFG) | select(. != "null") // null) |
        .host.runtime.vmId = (strenv(_YQ_VMID) | select(. != "null") // null) |
        .host.runtime.msalProxyPath = (strenv(_YQ_MSAL) | select(. != "null") // null) |
        .host.wslconfig = {"windowsPath": null, "wslPath": null, "exists": false, "sections": {}} |
        .host.wslgconfig = {"windowsPath": null, "wslPath": null, "exists": false, "sections": {}} |
        .distro = {"name": null}' >"$tmp"

    export _YQ_WP _YQ_LP _YQ_EX
    _YQ_WP="$(wslutil_info_yq_str "${INFO_WSLCONFIG_WIN:-}")"
    _YQ_LP="$(wslutil_info_yq_str "${INFO_WSLCONFIG_WSL:-}")"
    _YQ_EX="$( [[ "${INFO_WSLCONFIG_EXISTS:-0}" == 1 ]] && echo true || echo false )"
    yq eval -i \
        '.host.wslconfig.windowsPath = (strenv(_YQ_WP) | select(. != "null") // null) |
         .host.wslconfig.wslPath = (strenv(_YQ_LP) | select(. != "null") // null) |
         .host.wslconfig.exists = (strenv(_YQ_EX) == "true")' "$tmp"

    if [[ -n "${INFO_WSLCONFIG_UNAVAIL_REASON:-}" ]]; then
        export _YQ_R
        _YQ_R="$INFO_WSLCONFIG_UNAVAIL_REASON"
        yq eval -i \
            '.host.wslconfig.unavailable = true |
             .host.wslconfig.reason = strenv(_YQ_R)' "$tmp"
    fi

    while IFS=$'\t' read -r section key value def; do
        [[ -n "${section:-}" ]] || continue
        export _YQ_S="$section" _YQ_K="$key" _YQ_V="$value" _YQ_D="$def"
        yq eval -i \
            '.host.wslconfig.sections[strenv(_YQ_S)][strenv(_YQ_K)] = {"value": strenv(_YQ_V), "default": strenv(_YQ_D)}' "$tmp"
    done <<<"${INFO_WSLCONFIG_LINES:-}"

    _YQ_WP="$(wslutil_info_yq_str "${INFO_WSLGCONFIG_WIN:-}")"
    _YQ_LP="$(wslutil_info_yq_str "${INFO_WSLGCONFIG_WSL:-}")"
    _YQ_EX="$( [[ "${INFO_WSLGCONFIG_EXISTS:-0}" == 1 ]] && echo true || echo false )"
    yq eval -i \
        '.host.wslgconfig.windowsPath = (strenv(_YQ_WP) | select(. != "null") // null) |
         .host.wslgconfig.wslPath = (strenv(_YQ_LP) | select(. != "null") // null) |
         .host.wslgconfig.exists = (strenv(_YQ_EX) == "true")' "$tmp"

    if [[ -n "${INFO_WSLG_UNAVAIL_REASON:-}" ]]; then
        export _YQ_R
        _YQ_R="$INFO_WSLG_UNAVAIL_REASON"
        yq eval -i \
            '.host.wslgconfig.unavailable = true |
             .host.wslgconfig.reason = strenv(_YQ_R)' "$tmp"
    fi

    while IFS=$'\t' read -r _s key value; do
        [[ -n "${key:-}" ]] || continue
        export _YQ_K="$key" _YQ_V="$value"
        yq eval -i \
            '.host.wslgconfig.sections["system-distro-env"][strenv(_YQ_K)] = strenv(_YQ_V)' "$tmp"
    done <<<"${INFO_WSLG_LINES:-}"

    if [[ "${INFO_DISTRO_AVAILABLE:-}" == 0 ]]; then
        export _YQ_R
        _YQ_R="${INFO_DISTRO_REASON:-unavailable}"
        yq eval -i \
            '.distro.available = false |
             .distro.reason = strenv(_YQ_R) |
             .distro.wslconf = {"available": false, "reason": strenv(_YQ_R)}' "$tmp"
    elif [[ "${INFO_DISTRO_AVAILABLE:-}" == 1 ]]; then
        export _YQ_N _YQ_ST _YQ_VHDW _YQ_VHDL _YQ_CUR _YQ_DEFL _YQ_VER _YQ_UID
        _YQ_N="$(wslutil_info_yq_str "${INFO_DISTRO_NAME:-}")"
        _YQ_ST="$(wslutil_info_yq_str "${INFO_DISTRO_STATE:-}")"
        _YQ_VHDW="$(wslutil_info_yq_str "${INFO_DISTRO_VHD_WIN:-}")"
        _YQ_VHDL="$(wslutil_info_yq_str "${INFO_DISTRO_VHD_WSL:-}")"
        _YQ_CUR="$( [[ "${INFO_DISTRO_CURRENT:-0}" == 1 ]] && echo true || echo false )"
        _YQ_DEFL="$( [[ "${INFO_DISTRO_DEFAULT:-0}" == 1 ]] && echo true || echo false )"
        if [[ -n "${INFO_DISTRO_VER:-}" ]]; then
            _YQ_VER="${INFO_DISTRO_VER}"
        else
            _YQ_VER="null"
        fi
        if [[ -n "${INFO_DISTRO_UID:-}" ]]; then
            _YQ_UID="${INFO_DISTRO_UID}"
        else
            _YQ_UID="null"
        fi
        yq eval -i \
            '.distro.available = true |
             .distro.name = (strenv(_YQ_N) | select(. != "null") // null) |
             .distro.current = (strenv(_YQ_CUR) == "true") |
             .distro.default = (strenv(_YQ_DEFL) == "true") |
             .distro.state = (strenv(_YQ_ST) | select(. != "null") // null) |
             .distro.wslVersion = (strenv(_YQ_VER) | select(. != "null") | tonumber) // null |
             .distro.vhd.windowsPath = (strenv(_YQ_VHDW) | select(. != "null") // null) |
             .distro.vhd.wslPath = (strenv(_YQ_VHDL) | select(. != "null") // null) |
             .distro.defaultUid = (strenv(_YQ_UID) | select(. != "null") | tonumber) // null' "$tmp"

        if [[ "${INFO_WSLCONF_AVAILABLE:-0}" == 1 ]]; then
            export _YQ_P _YQ_EX
            _YQ_P="${INFO_WSLCONF_PATH:-}"
            _YQ_EX="$( [[ "${INFO_WSLCONF_EXISTS:-0}" == 1 ]] && echo true || echo false )"
            yq eval -i \
                '.distro.wslconf = {"available": true, "path": strenv(_YQ_P), "exists": (strenv(_YQ_EX) == "true"), "sections": {}}' "$tmp"
            if [[ -n "${INFO_WSLCONF_UNAVAIL_REASON:-}" ]]; then
                export _YQ_R
                _YQ_R="$INFO_WSLCONF_UNAVAIL_REASON"
                yq eval -i \
                    '.distro.wslconf.unavailable = true |
                     .distro.wslconf.reason = strenv(_YQ_R)' "$tmp"
            fi
            while IFS=$'\t' read -r section key value def; do
                [[ -n "${section:-}" ]] || continue
                export _YQ_S="$section" _YQ_K="$key" _YQ_V="$value" _YQ_D="$def"
                yq eval -i \
                    '.distro.wslconf.sections[strenv(_YQ_S)][strenv(_YQ_K)] = {"value": strenv(_YQ_V), "default": strenv(_YQ_D)}' "$tmp"
            done <<<"${INFO_WSLCONF_LINES:-}"
        else
            export _YQ_R
            _YQ_R="${INFO_WSLCONF_REASON:-unavailable}"
            yq eval -i \
                '.distro.wslconf = {"available": false, "reason": strenv(_YQ_R)}' "$tmp"
        fi
    fi

    yq eval -o json '.' "$tmp"
    rm -f "$tmp"
}

wslutil_info_print_human_distro() {
    local cur="" def="no"
    [[ "${INFO_DISTRO_CURRENT:-0}" == 1 ]] && cur=" (current)"
    [[ "${INFO_DISTRO_DEFAULT:-0}" == 1 ]] && def="yes"
    printf '== Distro: %s%s ==\n' "${INFO_DISTRO_NAME}" "$cur"
    printf '  state:      %s\n' "${INFO_DISTRO_STATE}"
    printf '  wsl:        %s\n' "${INFO_DISTRO_VER}"
    printf '  default:    %s\n' "$def"
    printf '  vhd:        %s\n' "$(wslutil_info_or_unavail "${INFO_DISTRO_VHD_WIN:-}")"
    if [[ -n "${INFO_DISTRO_VHD_WSL:-}" ]]; then
        printf '  vhd (wsl):  %s\n' "${INFO_DISTRO_VHD_WSL}"
    else
        printf '  vhd (wsl):  unavailable\n'
    fi
    printf '  defaultUid: %s\n' "$(wslutil_info_or_unavail "${INFO_DISTRO_UID:-}")"

    if [[ "${INFO_WSLCONF_AVAILABLE:-0}" != 1 ]]; then
        printf '  wsl.conf:   unavailable (%s)\n' "${INFO_WSLCONF_REASON:-unavailable}"
        return 0
    fi
    wslutil_info_print_human_ini_block "wsl.conf" "${INFO_WSLCONF_PATH}" "${INFO_WSLCONF_PATH}" \
        "${INFO_WSLCONF_LINES:-}" "${INFO_WSLCONF_UNAVAIL_REASON:-}" "${INFO_WSLCONF_EXISTS:-0}"
}
