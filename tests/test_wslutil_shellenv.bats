#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "wslutil with no arguments shows usage without unbound variable" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" != *"unbound variable"* ]]
}

@test "checkout shellenv does not emit WSLUTIL_DIR and prepends shimdir" {
    run env -u WSLUTIL_DIR SHELL=/bin/bash "$BATS_TEST_DIRNAME/../bin/wslutil" shellenv

    [ "$status" -eq 0 ]
    [[ "$output" != *"WSLUTIL_DIR="* ]]
    [[ "$output" == *"wslutil/bin"* ]]
}

@test "packaged shellenv resolves share datadir without WSLUTIL_DIR" {
    PREFIX="$TEST_TEMP_DIR/pfx"
    make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX" >/dev/null

    run env -u WSLUTIL_DIR SHELL=/bin/bash "$PREFIX/bin/wslutil" shellenv

    [ "$status" -eq 0 ]
    [[ "$output" != *"WSLUTIL_DIR="* ]]
    [[ "$output" == *"wslutil/bin"* ]]
}
