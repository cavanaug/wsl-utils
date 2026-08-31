#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/wslutil-list.sh"
}

teardown() {
    cleanup_test_env
}

@test "parse -l -v: default star, spaces in name, WSL 1 and 2" {
    run wslutil_list_parse_distro_list <<'EOF'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  Debian    Stopped         2
  OldBox    Stopped         1
  Ubuntu 22.04    Running         2
EOF
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t'"Running"$'\t'"2"$'\t'"yes"* ]]
    [[ "$output" == *"Debian"$'\t'"Stopped"$'\t'"2"$'\t'"no"* ]]
    [[ "$output" == *"OldBox"$'\t'"Stopped"$'\t'"1"$'\t'"no"* ]]
    [[ "$output" == *"Ubuntu 22.04"$'\t'"Running"$'\t'"2"$'\t'"no"* ]]
}

@test "pretty_name quoted and unquoted" {
    local f="$TEST_TEMP_DIR/os-release"
    printf 'PRETTY_NAME="Ubuntu 24.04.2 LTS"\n' >"$f"
    run wslutil_list_pretty_name "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "Ubuntu 24.04.2 LTS" ]
    printf 'PRETTY_NAME=Alpine\n' >"$f"
    run wslutil_list_pretty_name "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "Alpine" ]
}

@test "pretty_name missing file exits 1" {
    run wslutil_list_pretty_name "$TEST_TEMP_DIR/nope"
    [ "$status" -eq 1 ]
}

@test "format_hostname same vs differ vs empty" {
    run wslutil_list_format_hostname "mybox" ""
    [ "$output" = "mybox" ]
    run wslutil_list_format_hostname "mybox" "mybox"
    [ "$output" = "mybox" ]
    run wslutil_list_format_hostname "alpine" "devbox"
    [ "$output" = "alpine (devbox)" ]
    run wslutil_list_format_hostname "" ""
    [ "$output" = "-" ]
}

@test "hostname_configured_value only when different" {
    run wslutil_list_hostname_configured_value "alpine" "devbox"
    [ "$output" = "devbox" ]
    run wslutil_list_hostname_configured_value "mybox" "mybox"
    [ -z "$output" ]
    run wslutil_list_hostname_configured_value "mybox" ""
    [ -z "$output" ]
}

make_list_fakebin() {
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${WSLUTIL_LIST_WSL_LOG:-/tmp/wsl-argv.log}"
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    cat <<'LST'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  debian    Stopped         2
  alpine    Running         2
LST
    exit 0
fi
echo "unexpected: $*" >&2
exit 1
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WIN_UTF8="cat"
    export WSLUTIL_LIST_WSL_LOG="$TEST_TEMP_DIR/wsl-argv.log"
    : >"$WSLUTIL_LIST_WSL_LOG"
}

seed_file_root() {
    export WSLUTIL_LIST_FILE_ROOT="$TEST_TEMP_DIR/fs"
    mkdir -p "$WSLUTIL_LIST_FILE_ROOT/Ubuntu/etc" \
        "$WSLUTIL_LIST_FILE_ROOT/Ubuntu/proc/sys/kernel" \
        "$WSLUTIL_LIST_FILE_ROOT/alpine/etc" \
        "$WSLUTIL_LIST_FILE_ROOT/alpine/proc/sys/kernel"
    printf 'PRETTY_NAME="Ubuntu 24.04.2 LTS"\n' >"$WSLUTIL_LIST_FILE_ROOT/Ubuntu/etc/os-release"
    printf 'mybox\n' >"$WSLUTIL_LIST_FILE_ROOT/Ubuntu/proc/sys/kernel/hostname"
    printf 'PRETTY_NAME="Alpine Linux v3.20"\n' >"$WSLUTIL_LIST_FILE_ROOT/alpine/etc/os-release"
    printf 'alpine\n' >"$WSLUTIL_LIST_FILE_ROOT/alpine/proc/sys/kernel/hostname"
    cat >"$WSLUTIL_LIST_FILE_ROOT/alpine/etc/wsl.conf" <<'EOF'
[network]
hostname=devbox
EOF
}

@test "resolve_file uses FILE_ROOT and current distro slash path" {
    export WSLUTIL_LIST_FILE_ROOT="$TEST_TEMP_DIR/fs"
    run wslutil_list_resolve_file Ubuntu etc/os-release
    [ "$output" = "$TEST_TEMP_DIR/fs/Ubuntu/etc/os-release" ]
    unset WSLUTIL_LIST_FILE_ROOT
    export WSL_DISTRO_NAME=Ubuntu
    run wslutil_list_resolve_file Ubuntu etc/os-release
    [ "$output" = "/etc/os-release" ]
}

@test "wslutil-list --help exits 0 and mentions --json and --location" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--json" ]]
    [[ "$output" =~ "--location" ]]
}

@test "wslutil-list unknown flag exits 1" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --bogus
    [ "$status" -eq 1 ]
}

@test "human table: running type/hostname, stopped dashes, never -d" {
    make_list_fakebin
    seed_file_root
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ NAME ]]
    [[ "$output" =~ Ubuntu ]]
    [[ "$output" =~ "Ubuntu 24.04.2 LTS" ]]
    [[ "$output" =~ mybox ]]
    [[ "$output" =~ debian ]]
    [[ "$output" =~ alpine ]]
    [[ "$output" =~ "Alpine Linux v3.20" ]]
    [[ "$output" =~ "alpine (devbox)" ]]
    [[ "$output" != *LOCATION* ]]
    if grep -E -- '-d' "$WSLUTIL_LIST_WSL_LOG"; then
        echo "wsl.exe -d was invoked" >&2
        cat "$WSLUTIL_LIST_WSL_LOG" >&2
        return 1
    fi
}

@test "empty distro list exits 1" {
    FAKEBIN="$TEST_TEMP_DIR/emptybin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
echo "  NAME      STATE           VERSION"
exit 0
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WIN_UTF8="cat"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 1 ]
}

@test "--json is an array with type and hostnameConfigured" {
    make_list_fakebin
    seed_file_root
    command -v yq >/dev/null 2>&1 || skip "need yq"
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.[0].name' -)" = "Ubuntu" ]
    [ "$(echo "$output" | yq eval '.[0].default' -)" = "true" ]
    [ "$(echo "$output" | yq eval '.[0].state' -)" = "Running" ]
    [ "$(echo "$output" | yq eval '.[0].wslVersion' -)" = "2" ]
    [ "$(echo "$output" | yq eval '.[0].type' -)" = "Ubuntu 24.04.2 LTS" ]
    [ "$(echo "$output" | yq eval '.[0].hostname' -)" = "mybox" ]
    [ "$(echo "$output" | yq eval '.[0].hostnameConfigured' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[0] | has("location")' -)" = "false" ]
    [ "$(echo "$output" | yq eval '.[1].name' -)" = "debian" ]
    [ "$(echo "$output" | yq eval '.[1].type' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[1].hostname' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[2].hostname' -)" = "alpine" ]
    [ "$(echo "$output" | yq eval '.[2].hostnameConfigured' -)" = "devbox" ]
}

@test "--json keeps object keys when wslVersion is not 1 or 2" {
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    cat <<'LST'
  NAME      STATE           VERSION
* WeirdDistro    Stopped         weird
LST
    exit 0
fi
exit 1
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WIN_UTF8="cat"
    command -v yq >/dev/null 2>&1 || skip "need yq"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.[0].name' -)" = "WeirdDistro" ]
    [ "$(echo "$output" | yq eval '.[0].wslVersion' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[0].state' -)" = "Stopped" ]
    [ "$(echo "$output" | yq eval '.[0].default' -)" = "true" ]
}

@test "--json without yq exits 1" {
    make_list_fakebin
    seed_file_root
    local priv="$TEST_TEMP_DIR/privbin" cmd
    mkdir -p "$priv"
    for cmd in bash cat awk grep mktemp rm dirname; do
        ln -sf "$(command -v "$cmd")" "$priv/$cmd"
    done
    run env PATH="$priv:$FAKEBIN" WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe" \
        WSLUTIL_LIST_WIN_UTF8="cat" WSLUTIL_LIST_FILE_ROOT="$WSLUTIL_LIST_FILE_ROOT" \
        "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json
    [ "$status" -eq 1 ]
    [[ "$output" =~ yq ]]
}

@test "--location adds column and JSON key; off skips powershell" {
    make_list_fakebin
    seed_file_root
    command -v yq >/dev/null 2>&1 || skip "need yq"
    export WSLUTIL_LIST_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\Ubuntu\n' >"$WSLUTIL_LIST_LXSS"
    printf 'debian\tC:\\Users\\foo\\debian\n' >>"$WSLUTIL_LIST_LXSS"
    local ps="$FAKEBIN/powershell.exe"
    cat >"$ps" <<'EOF'
#!/bin/bash
echo invoked >>"${WSLUTIL_LIST_PS_LOG}"
exit 1
EOF
    chmod +x "$ps"
    export WSLUTIL_LIST_POWERSHELL="$ps"
    export WSLUTIL_LIST_PS_LOG="$TEST_TEMP_DIR/ps.log"
    : >"$WSLUTIL_LIST_PS_LOG"

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 0 ]
    [[ "$output" != *LOCATION* ]]
    [[ ! -s "$WSLUTIL_LIST_PS_LOG" ]]

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --location
    [ "$status" -eq 0 ]
    [[ "$output" =~ LOCATION ]]
    [[ "$output" =~ "C:\\Users\\foo\\Ubuntu" ]]
    [[ ! -s "$WSLUTIL_LIST_PS_LOG" ]]

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json --location
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.[0].location' -)" = 'C:\Users\foo\Ubuntu' ]
    [ "$(echo "$output" | yq eval '.[1].location' -)" = 'C:\Users\foo\debian' ]
    [ "$(echo "$output" | yq eval '.[2].location' -)" = "null" ]
}

@test "--location with no map still prints table" {
    make_list_fakebin
    seed_file_root
    unset WSLUTIL_LIST_LXSS
    export WSLUTIL_LIST_POWERSHELL="$TEST_TEMP_DIR/missing-ps"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --location
    [ "$status" -eq 0 ]
    [[ "$output" =~ LOCATION ]]
    [[ "$output" =~ Ubuntu ]]
}
