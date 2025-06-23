#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "win-run --help displays help message" {
    run "$WSLUTIL_DIR/bin/win-run" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "win-run - Execute Windows programs from WSL" ]]
    [[ "$output" =~ "SYNOPSIS" ]]
    [[ "$output" =~ "OPTIONS" ]]
    [[ "$output" =~ "EXAMPLES" ]]
}

@test "win-run with no arguments shows error" {
    run "$WSLUTIL_DIR/bin/win-run"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: No command specified" ]]
}

@test "win-run with unknown option shows error and help hint" {
    run "$WSLUTIL_DIR/bin/win-run" --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Unknown option --unknown-option" ]]
    [[ "$output" =~ "Use --help for usage information" ]]
}

@test "win-run -c without argument shows error" {
    run "$WSLUTIL_DIR/bin/win-run" -c
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: -c option requires a config file argument" ]]
}

@test "win-run -c with non-existent file shows error" {
    run "$WSLUTIL_DIR/bin/win-run" -c "/non/existent/file.yml" testcmd
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Config file '/non/existent/file.yml' does not exist" ]]
}

@test "win-run -c with valid file accepts option" {
    # Create a minimal config file
    local config_file="$TEST_TEMP_DIR/test-config.yml"
    create_test_alias_config "$config_file"
    
    # This should not fail due to config file validation
    # (actual command execution might fail, but config validation should pass)
    run bash -c "cd '$WSLUTIL_DIR' && timeout 5 bin/win-run -c '$config_file' testcmd || true"
    # Status might not be 0 due to command execution, but should not be config validation error
    [[ ! "$output" =~ "Error: Config file" ]]
}

@test "win-run --raw option is accepted" {
    # Test that --raw option doesn't cause parsing errors
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run --raw echo test || true"
    # Should not fail due to option parsing
    [[ ! "$output" =~ "Error: Unknown option" ]]
}

@test "win-run combines --raw and -c options" {
    local config_file="$TEST_TEMP_DIR/test-config.yml"
    create_test_alias_config "$config_file"
    
    # Test that both options can be used together
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run --raw -c '$config_file' testcmd || true"
    # Should not fail due to option parsing
    [[ ! "$output" =~ "Error:" ]]
}