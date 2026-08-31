#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../bin/wslutil-info"
}

teardown() {
    cleanup_test_env
}

@test "omit guiApplications=true (default)" {
    run wslutil_info_should_omit wslconfig wsl2 guiApplications true
    [ "$status" -eq 0 ]
}

@test "keep guiApplications=false" {
    run wslutil_info_should_omit wslconfig wsl2 guiApplications false
    [ "$status" -eq 1 ]
}

@test "omit networkingMode=NAT case-insensitively" {
    run wslutil_info_should_omit wslconfig wsl2 networkingMode NAT
    [ "$status" -eq 0 ]
}

@test "keep memory=4GB even though default is a formula" {
    run wslutil_info_should_omit wslconfig wsl2 memory 4GB
    [ "$status" -eq 1 ]
}

@test "keep unknown key" {
    run wslutil_info_should_omit wslconfig wsl2 totallyNewKey 1
    [ "$status" -eq 1 ]
}

@test "omit appendWindowsPath=true; keep false" {
    run wslutil_info_should_omit wslconf interop appendWindowsPath true
    [ "$status" -eq 0 ]
    run wslutil_info_should_omit wslconf interop appendWindowsPath false
    [ "$status" -eq 1 ]
}

@test "wslutil-info --help exits 0 and mentions --json and --distro" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--json" ]]
    [[ "$output" =~ "--distro" ]]
}

@test "wslutil-info unknown flag exits 1" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --bogus
    [ "$status" -eq 1 ]
}

@test "wslutil info --help dispatches" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil" info --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--json" ]]
}

make_fakebin() {
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wslinfo" <<'EOF'
#!/bin/bash
case "$1" in
--version) echo "2.7.12.0" ;;
--networking-mode) echo "mirrored" ;;
--vm-id) echo "{11111111-2222-3333-4444-555555555555}" ;;
--msal-proxy-path) echo "/mnt/c/fake/msal" ;;
*) exit 1 ;;
esac
EOF
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    cat <<'VER'
WSL version: 2.7.12.0
Kernel version: 6.18.33.2-2
WSLg version: 1.0.73.2
MSRDC version: 1.2.7214
Direct3D version: 1.611.1-81528511
DXCore version: 10.0.26100.1-240331-1435.ge-release
Windows version: 10.0.26200.9106
VER
    exit 0
fi
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    cat <<'LST'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  Debian    Stopped         2
LST
    exit 0
fi
echo "unexpected: $*" >&2
exit 1
EOF
    chmod +x "$FAKEBIN/wslinfo" "$FAKEBIN/wsl.exe"
}

@test "filter_ini_file omits default guiApplications and keeps false" {
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    local f="$TEST_TEMP_DIR/.wslconfig"
    cat >"$f" <<'EOF'
[wsl2]
guiApplications=true
memory=4GB
EOF
    run wslutil_info_filter_ini_file wslconfig "$f"
    [ "$status" -eq 0 ]
    [[ "$output" != *"guiApplications"* ]]
    [[ "$output" =~ "memory" ]]
    [[ "$output" =~ "4GB" ]]
}

@test "human report shows .wslconfig path and non-default memory" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_DISTRO=1
    export WIN_USERPROFILE="$TEST_TEMP_DIR/winhome"
    mkdir -p "$WIN_USERPROFILE"
    cat >"$WIN_USERPROFILE/.wslconfig" <<'EOF'
[wsl2]
networkingMode=mirrored
memory=4GB
guiApplications=true
EOF
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "4GB" ]]
    [[ "$output" != *"guiApplications"* ]]
    [[ "$output" =~ "configured:" ]]
    [[ "$output" =~ "mirrored" ]]
    [[ "$output" != *$'\n'"  wsl:"* ]]
}

@test "human report prints wslinfo version and networkingMode" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSLUTIL_INFO_SKIP_DISTRO=1
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "2.7.12.0" ]]
    [[ "$output" =~ "mirrored" ]]
    [[ "$output" =~ "1.0.73.2" ]]
}

@test "unknown --distro exits 1 and lists names" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro NoSuchDistro
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Ubuntu" ]]
}

@test "empty --distro= exits 1" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro=
    [ "$status" -eq 1 ]
    [[ "$output" =~ "non-empty name" ]]
}

@test "empty --distro \"\" exits 1" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "non-empty name" ]]
}

@test "distro block includes VHD path from Lxss TSV" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\AppData\\Local\\Packages\\Ubuntu\\LocalState\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ext4.vhdx" ]]
    [[ "$output" != *"vhd (wsl):"* ]]
    [[ "$output" =~ "Ubuntu" ]]
    [[ "$output" =~ "Running" ]]
}

make_fakebin_list_fail() {
    make_fakebin
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    cat <<'VER'
WSL version: 2.7.12.0
Kernel version: 6.18.33.2-2
WSLg version: 1.0.73.2
MSRDC version: 1.2.7214
Direct3D version: 1.611.1-81528511
DXCore version: 10.0.26100.1-240331-1435.ge-release
Windows version: 10.0.26200.9106
VER
    exit 0
fi
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    exit 1
fi
echo "unexpected: $*" >&2
exit 1
EOF
    chmod +x "$FAKEBIN/wsl.exe"
}

@test "failed distro list prints unavailable and exits 0" {
    make_fakebin_list_fail
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "unavailable" ]]
    [[ "$output" =~ "could not list distros" ]]
    [[ "$output" != *"unknown distro"* ]]
}

@test "empty distro list prints unavailable and exits 0" {
    make_fakebin
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "WSL version: 2.7.12.0"
    exit 0
fi
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    echo "  NAME      STATE           VERSION"
    exit 0
fi
exit 1
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "could not list distros" ]]
    [[ "$output" != *"unknown distro"* ]]
}

@test "stopped other distro does not call wsl.exe -d" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Debian\tC:\\wsldisks\\Debian\t2\t1000\nUbuntu\tC:\\u\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro Debian
    [ "$status" -eq 0 ]
    [[ "$output" =~ "distro not running" ]]
    [[ "$output" != *"-d Debian"* ]]
}

@test "--json has host and distro keys" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\LocalState\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    echo "$output" | yq eval '.host.versions.wsl' - | grep -q '2.7.12.0'
    echo "$output" | yq eval '.host.runtime.networkingMode' - | grep -q 'mirrored'
    echo "$output" | yq eval '.distro.name' - | grep -q 'Ubuntu'
}

@test "lxss_lookup does not require powershell.exe on PATH" {
    local ps="$TEST_TEMP_DIR/fake-powershell"
    cat >"$ps" <<'EOF'
#!/bin/bash
printf 'debian-13\tC:\\Users\\foo\\WSL2\\debian-13\t2\t0\r\n'
EOF
    chmod +x "$ps"
    export WSLUTIL_INFO_POWERSHELL="$ps"
    unset WSLUTIL_INFO_LXSS
    export PATH="/usr/bin:/bin"
    run wslutil_info_lxss_lookup debian-13
    [ "$status" -eq 0 ]
    [[ "$output" == *"C:\\Users\\foo\\WSL2\\debian-13"* ]]
    [[ "$output" == *$'\t'"2"$'\t'"0" ]]
}

@test "collect_versions uses win-run wsl.exe when WSLUTIL_INFO_WSL unset" {
    local wr="$TEST_TEMP_DIR/fake-win-run"
    cat >"$wr" <<EOF
#!/bin/bash
echo "\$*" >>"$TEST_TEMP_DIR/win-run.args"
if [[ "\$1" == "wsl.exe" && "\$2" == "--version" ]]; then
    cat <<'VER'
WSL version: 2.7.12.0
Kernel version: 6.18.33.2-2
WSLg version: 1.0.73.2
MSRDC version: 1.2.7214
Direct3D version: 1.611.1-81528511
DXCore version: 10.0.26100.1-240331-1435.ge-release
Windows version: 10.0.26200.9106
VER
    exit 0
fi
echo "unexpected: \$*" >&2
exit 1
EOF
    chmod +x "$wr"
    export WSLUTIL_INFO_WIN_RUN="$wr"
    unset WSLUTIL_INFO_WSL
    export PATH="/usr/bin:/bin"
    wslutil_info_collect_versions
    [ "$INFO_VER_WSL_EXE" = "2.7.12.0" ]
    grep -q 'wsl.exe --version' "$TEST_TEMP_DIR/win-run.args"
}

@test "format_uptime pretty matches wslutil-uptime" {
    [ "$(wslutil_info_format_uptime 90)" = "up 1 minutes" ]
    [ "$(wslutil_info_format_uptime 3661)" = "up 1:01" ]
    [ "$(wslutil_info_format_uptime 90061)" = "up 1 day, 1:01" ]
}

@test "human report has host VM uptime, distro uptime, blank line, Windows paths only" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\LocalState\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    export WSLUTIL_INFO_VM_UPTIME_SECS=90061
    export WSLUTIL_INFO_DISTRO_UPTIME="up 3:12"
    export WSLUTIL_INFO_COLOR=0
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "uptime:" ]]
    [[ "$output" =~ "up 1 day, 1:01" ]]
    [[ "$output" =~ "up 3:12" ]]
    [[ "$output" =~ $'\n\n== Distro:' ]]
    [[ "$output" != *"vhd (wsl):"* ]]
}

@test "stopped other distro omits distro uptime from wslutil-uptime" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Debian\tC:\\wsldisks\\Debian\t2\t1000\nUbuntu\tC:\\u\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    export WSLUTIL_INFO_VM_UPTIME_SECS=60
    export WSLUTIL_INFO_DISTRO_UPTIME="should-not-appear"
    export WSLUTIL_INFO_COLOR=0
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro Debian
    [ "$status" -eq 0 ]
    [[ "$output" != *"should-not-appear"* ]]
    [[ "$output" =~ "uptime:" ]]
}

@test "color headers when WSLUTIL_INFO_COLOR=1" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSLUTIL_INFO_SKIP_DISTRO=1
    export WSLUTIL_INFO_VM_UPTIME_SECS=60
    export WSLUTIL_INFO_COLOR=1
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\033['* ]]
}

@test "live wslutil info --json parses" {
    skip_if_not_wsl
    command -v yq >/dev/null 2>&1 || skip "need yq"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    echo "$output" | yq eval '.host' - >/dev/null
    echo "$output" | yq eval '.distro' - >/dev/null
    echo "$output" | yq eval '.distro.vhd.windowsPath' - | grep -qv '^null$'
}

@test "bootstrap does not log [INFO] to stdout when WIN_USERPROFILE unset" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_DISTRO=1
    unset WIN_USERPROFILE WIN_LOCALAPPDATA WIN_APPDATA
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" != *"[INFO]"* ]]
    [[ "$output" != *"Bootstrapping"* ]]
}

@test "collect_host_config leaves paths empty without WIN_USERPROFILE" {
    unset WIN_USERPROFILE
    wslutil_info_collect_host_config
    [ -z "${INFO_WSLCONFIG_WIN:-}" ]
    [ -z "${INFO_WSLCONFIG_WSL:-}" ]
    [ -z "${INFO_WSLGCONFIG_WIN:-}" ]
    [ -z "${INFO_WSLGCONFIG_WSL:-}" ]
    [ "${INFO_WSLCONFIG_EXISTS:-1}" -eq 0 ]
}

@test "json null host paths when WIN_USERPROFILE unset" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSLUTIL_INFO_SKIP_DISTRO=1
    unset WIN_USERPROFILE WIN_LOCALAPPDATA WIN_APPDATA
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.host.wslconfig.windowsPath' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.host.wslconfig.wslPath' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.host.wslgconfig.windowsPath' -)" = "null" ]
    [[ "$output" != *'"windowsPath": "unavailable"'* ]]
    [[ "$output" != *'"wslPath": "unavailable"'* ]]
}

@test "json distro unavailable when WSL_DISTRO_NAME unset" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    unset WSL_DISTRO_NAME
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.distro.available' -)" = "false" ]
    echo "$output" | yq eval '.distro.reason' - | grep -q 'WSL_DISTRO_NAME unset'
    [ "$(echo "$output" | yq eval '.distro.wslconf.available' -)" = "false" ]
    echo "$output" | yq eval '.distro.wslconf.reason' - | grep -q 'WSL_DISTRO_NAME unset'
    [ "$(echo "$output" | yq eval '.distro.name' -)" = "null" ]
}

@test "json distro unavailable when list fails" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    make_fakebin_list_fail
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.distro.available' -)" = "false" ]
    echo "$output" | yq eval '.distro.reason' - | grep -q 'could not list distros'
    [ "$(echo "$output" | yq eval '.distro.wslconf.available' -)" = "false" ]
}

@test "json wslconf exists false when file missing" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    INFO_DISTRO_AVAILABLE=1
    INFO_DISTRO_NAME="TestDistro"
    INFO_DISTRO_STATE="Running"
    INFO_DISTRO_CURRENT=1
    INFO_WSLCONF_AVAILABLE=1
    INFO_WSLCONF_EXISTS=0
    INFO_WSLCONF_PATH="$TEST_TEMP_DIR/missing-wsl.conf"
    INFO_WSLCONF_LINES=""
    run wslutil_info_emit_json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.distro.wslconf.available' -)" = "true" ]
    [ "$(echo "$output" | yq eval '.distro.wslconf.exists' -)" = "false" ]
    [ "$(echo "$output" | yq eval '.distro.wslconf.path' -)" = "$TEST_TEMP_DIR/missing-wsl.conf" ]
}

@test "json wslconfig unavailable when crudini missing but file exists" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    INFO_WSLCONFIG_WIN="C:\\Users\\foo\\.wslconfig"
    INFO_WSLCONFIG_WSL="$TEST_TEMP_DIR/.wslconfig"
    INFO_WSLCONFIG_EXISTS=1
    INFO_WSLCONFIG_LINES=""
    INFO_WSLCONFIG_UNAVAIL_REASON="need crudini"
    touch "$INFO_WSLCONFIG_WSL"
    run wslutil_info_emit_json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.host.wslconfig.exists' -)" = "true" ]
    [ "$(echo "$output" | yq eval '.host.wslconfig.unavailable' -)" = "true" ]
    echo "$output" | yq eval '.host.wslconfig.reason' - | grep -q 'need crudini'
    [ "$(echo "$output" | yq eval '.host.wslconfig.sections | length' -)" = "0" ]
}

@test "json wslconf unavailable when crudini missing but file exists" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    INFO_DISTRO_AVAILABLE=1
    INFO_DISTRO_NAME="TestDistro"
    INFO_DISTRO_STATE="Running"
    INFO_DISTRO_CURRENT=1
    INFO_WSLCONF_AVAILABLE=1
    INFO_WSLCONF_EXISTS=1
    INFO_WSLCONF_PATH="$TEST_TEMP_DIR/wsl.conf"
    INFO_WSLCONF_LINES=""
    INFO_WSLCONF_UNAVAIL_REASON="need crudini"
    touch "$INFO_WSLCONF_PATH"
    run wslutil_info_emit_json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.distro.wslconf.exists' -)" = "true" ]
    [ "$(echo "$output" | yq eval '.distro.wslconf.unavailable' -)" = "true" ]
    echo "$output" | yq eval '.distro.wslconf.reason' - | grep -q 'need crudini'
    [ "$(echo "$output" | yq eval '.distro.wslconf.sections | length' -)" = "0" ]
}

@test "collect_host_config sets crudini reason when file exists without crudini" {
    command -v crudini >/dev/null 2>&1 && skip "crudini installed; json emit test covers unavailable reason"
    export WIN_USERPROFILE="$TEST_TEMP_DIR/winhome"
    mkdir -p "$WIN_USERPROFILE"
    cat >"$WIN_USERPROFILE/.wslconfig" <<'EOF'
[wsl2]
memory=4GB
EOF
    wslutil_info_collect_host_config
    [ "${INFO_WSLCONFIG_EXISTS:-0}" -eq 1 ]
    [ "${INFO_WSLCONFIG_UNAVAIL_REASON:-}" = "need crudini" ]
    [ -z "${INFO_WSLCONFIG_LINES:-}" ]
}
