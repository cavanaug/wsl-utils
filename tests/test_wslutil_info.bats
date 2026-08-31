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
