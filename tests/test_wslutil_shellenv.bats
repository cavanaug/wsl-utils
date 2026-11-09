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

@test "stale-cache refresh is detached without disowning existing interactive jobs" {
    export WIN_WINDIR="$TEST_TEMP_DIR/Windows"
    export XDG_DATA_HOME="$TEST_TEMP_DIR/data"
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/cache"
    export WSL_INTEROP="$TEST_TEMP_DIR/interop.sock"
    mkdir -p "$WIN_WINDIR" "$XDG_CACHE_HOME/wslutil"
    touch -d '2 hours ago' "$XDG_CACHE_HOME/wslutil/env.win"
    python3 -c 'import socket, sys; s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' \
        "$WSL_INTEROP"

    run env SHELL=/bin/bash bash --noprofile --norc -i <<'BASH'
        PS1=
        set -m
        win-env() {
            local attempt
            printf "%s\n" "$@" > "$TEST_TEMP_DIR/refresh-args"
            for ((attempt = 0; attempt < 500; attempt++)); do
                if [[ -f "$TEST_TEMP_DIR/refresh-release" ]]; then
                    : > "$TEST_TEMP_DIR/refresh-complete"
                    return 0
                fi
                sleep 0.01
            done
            return 1
        }
        sleep 30 &
        existing_job=$!
        eval "$("$CHECKOUT_ROOT/bin/wslutil" shellenv)"
        shellenv_status=$?
        refresh_job=$!
        tracked_jobs=$(jobs -p)
        : > "$TEST_TEMP_DIR/refresh-release"
        for ((attempt = 0; attempt < 500; attempt++)); do
            [[ -f "$TEST_TEMP_DIR/refresh-complete" ]] && break
            sleep 0.01
        done
        kill "$refresh_job" 2>/dev/null || :
        kill "$existing_job"
        wait "$existing_job" 2>/dev/null || :
        [[ $shellenv_status -eq 0 && $tracked_jobs == "$existing_job" &&
            -f "$TEST_TEMP_DIR/refresh-complete" ]]
        exit "$?"
BASH

    [ "$status" -eq 0 ]
    [[ "$output" != *"Done"* ]]
    [ "$(cat "$TEST_TEMP_DIR/refresh-args")" = "--refresh" ]
}
