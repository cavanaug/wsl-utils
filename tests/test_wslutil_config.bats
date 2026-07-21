#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    export WSLUTIL_CONFIG="$BATS_TEST_DIRNAME/../bin/wslutil-config"
    export WSLUTIL="$BATS_TEST_DIRNAME/../bin/wslutil"
}

teardown() {
    cleanup_test_env
}

@test "config init copies missing factory files into XDG config" {
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
    run "$WSLUTIL" config init
    [ "$status" -eq 0 ]
    [ -f "$XDG_CONFIG_HOME/wslutil/wslutil.yml" ]
    grep -q 'exes:' "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
}

@test "config init does not overwrite unless --force" {
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
    mkdir -p "$XDG_CONFIG_HOME/wslutil"
    echo 'exes: {}' > "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    run "$WSLUTIL" config init
    [ "$status" -eq 0 ]
    grep -q 'exes: {}' "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
}

@test "config init --force overwrites existing files" {
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
    mkdir -p "$XDG_CONFIG_HOME/wslutil"
    echo 'exes: {}' > "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    run "$WSLUTIL" config init --force
    [ "$status" -eq 0 ]
    ! grep -q '^exes: {}$' "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    grep -q 'cmd.exe' "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
}

@test "wslutil-config init --help shows usage" {
    run "$WSLUTIL_CONFIG" init --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "init" ]]
}
