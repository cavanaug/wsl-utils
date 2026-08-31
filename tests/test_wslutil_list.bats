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
