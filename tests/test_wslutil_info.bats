#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/wslutil-info.sh"
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

@test "bootstrap does not log [INFO] to stdout when WIN_USERPROFILE unset" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_DISTRO=1
    export WSLUTIL_INFO_SKIP_CONFIG=1
    unset WIN_USERPROFILE WIN_LOCALAPPDATA WIN_APPDATA
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" != *"[INFO]"* ]]
    [[ "$output" != *"Bootstrapping"* ]]
}
