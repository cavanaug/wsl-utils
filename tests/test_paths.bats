#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    FAKE_PREFIX="$TEST_TEMP_DIR/prefix"
    mkdir -p "$FAKE_PREFIX/bin" "$FAKE_PREFIX/share/wslutil/config" "$FAKE_PREFIX/share/wslutil/env"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$FAKE_PREFIX/share/wslutil/lib/wslutil-paths.sh" 2>/dev/null || true
}

teardown() {
    cleanup_test_env
}

@test "packaged layout resolves share/wslutil as datadir" {
    mkdir -p "$FAKE_PREFIX/share/wslutil/lib"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$FAKE_PREFIX/share/wslutil/lib/"
    run bash -c "
        source '$FAKE_PREFIX/share/wslutil/lib/wslutil-paths.sh'
        wslutil_resolve_datadir '$FAKE_PREFIX/bin/wslutil'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$FAKE_PREFIX/share/wslutil" ]
}

@test "checkout layout resolves repo root as datadir" {
    REPO="$TEST_TEMP_DIR/checkout"
    mkdir -p "$REPO/bin" "$REPO/config" "$REPO/env" "$REPO/lib"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$REPO/lib/"
    run bash -c "
        source '$REPO/lib/wslutil-paths.sh'
        wslutil_resolve_datadir '$REPO/bin/wslutil'
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$REPO" ]
}

@test "shimdir uses XDG_DATA_HOME" {
    export XDG_DATA_HOME="$TEST_TEMP_DIR/xdg-data"
    run bash -c "
        source '$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh'
        wslutil_shimdir
    "
    [ "$status" -eq 0 ]
    [ "$output" = "$TEST_TEMP_DIR/xdg-data/wslutil/bin" ]
}
