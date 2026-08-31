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
