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
    local title="$1" winpath="$2" wslpath="$3" kind="$4" path="$5"
    printf '%s\n' "$title"
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ ! -e "$path" ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if ! command -v crudini >/dev/null 2>&1; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    local lines
    lines="$(wslutil_info_filter_ini_file "$kind" "$path")"
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
    local winpath="$1" wslpath="$2" path="$3"
    printf '.wslgconfig\n'
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ ! -e "$path" ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if ! command -v crudini >/dev/null 2>&1; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    local lines
    lines="$(wslutil_info_filter_wslgconfig "$path")"
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
