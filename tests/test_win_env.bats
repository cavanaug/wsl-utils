#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    export WSLUTIL_WIN_ENV_CACHE="$TEST_TEMP_DIR/env.win"
    cat >"$WSLUTIL_WIN_ENV_CACHE" <<'EOF'
USERPROFILE=/mnt/c/Users/testuser
APPDATA=/mnt/c/Users/testuser/AppData/Roaming
LOCALAPPDATA=/mnt/c/Users/testuser/AppData/Local
ProgramFiles=/mnt/c/Program Files
ProgramFiles_x86=/mnt/c/Program Files (x86)
USERNAME=testuser
EOF
    WIN_ENV="$BATS_TEST_DIRNAME/../bin/win-env"
}

teardown() {
    cleanup_test_env
}

@test "win-env prints a single variable" {
    run "$BATS_TEST_DIRNAME/../bin/win-env" USERPROFILE
    [ "$status" -eq 0 ]
    [ "$output" = "/mnt/c/Users/testuser" ]
}

@test "win-env --export emits WIN_ prefixed exports" {
    run "$BATS_TEST_DIRNAME/../bin/win-env" --export USERPROFILE APPDATA
    [ "$status" -eq 0 ]
    [[ "$output" =~ export\ WIN_USERPROFILE= ]]
    [[ "$output" =~ export\ WIN_APPDATA= ]]
}

@test "win-env --export --prefix overrides prefix" {
    run "$BATS_TEST_DIRNAME/../bin/win-env" --export --prefix 'W_' USERNAME
    [ "$status" -eq 0 ]
    [[ "$output" =~ export\ W_USERNAME= ]]
}

@test "win-env lists keys with no args" {
    run "$BATS_TEST_DIRNAME/../bin/win-env"
    [ "$status" -eq 0 ]
    [[ "$output" =~ USERPROFILE ]]
    [[ "$output" =~ ProgramFiles_x86 ]]
}

@test "win-env --export is eval-safe" {
    unset WIN_USERPROFILE WIN_APPDATA
    eval "$("$BATS_TEST_DIRNAME/../bin/win-env" --export USERPROFILE APPDATA)"
    [ "$WIN_USERPROFILE" = "/mnt/c/Users/testuser" ]
    [ "$WIN_APPDATA" = "/mnt/c/Users/testuser/AppData/Roaming" ]
}
