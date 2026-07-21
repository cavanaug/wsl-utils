#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    skip_if_no_yq
}

teardown() {
    cleanup_test_env
}

@test "integration: win-run with custom config and alias" {
    # Create a comprehensive test config
    local config_file="$TEST_TEMP_DIR/integration.yml"
    cat > "$config_file" << 'EOF'
exes:
  test-echo:
    mode: none
    path: ${WIN_WINDIR}/System32/cmd.exe
    options: "/c echo"
  test-ping:
    mode: none
    path: ${WIN_WINDIR}/System32/ping.exe
    options: "-n 1"
EOF
    
    # Test basic alias resolution
    run bash -c "timeout 5 win-run -c '$config_file' test-echo 'Hello World' || true"
    
    # Should not have config errors
    [[ ! "$output" =~ "Error:" ]]
}

@test "integration: environment variable expansion in full pipeline" {
    local config_file="$TEST_TEMP_DIR/env-integration.yml"
    cat > "$config_file" << 'EOF'
exes:
  env-test:
    mode: none
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: null
  multi-env:
    mode: none
    path: ${WIN_PROGRAMFILES}/../Windows/System32/whoami.exe
    options: null
EOF
    
    # Test environment variable expansion
    export CUSTOM_CONFIG="$config_file"
    source "$CHECKOUT_ROOT/bin/win-run"
    
    # Test basic environment expansion
    run resolve_alias "env-test"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "C:\\Windows\\System32\\ipconfig.exe" ]]
    
    # Test complex path with relative navigation
    run resolve_alias "multi-env"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "whoami.exe" ]]
}

@test "integration: config hierarchy precedence" {
    # Create a fake datadir (factory config) instead of mutating the checkout
    local fake_datadir="$TEST_TEMP_DIR/datadir"
    mkdir -p "$fake_datadir/config"
    cat > "$fake_datadir/config/wslutil.yml" << 'EOF'
exes:
  hierarchy-test:
    mode: none
    path: ${WIN_WINDIR}/System32/global.exe
    options: "global"
EOF

    # Create user config that overrides
    local user_config="$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    cat > "$user_config" << 'EOF'
exes:
  hierarchy-test:
    mode: none
    path: ${WIN_WINDIR}/System32/user.exe
    options: "user"
EOF

    export WSLUTIL_DATADIR="$fake_datadir"
    source "$CHECKOUT_ROOT/bin/win-run"

    # User config should take precedence
    run resolve_alias "hierarchy-test"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "user.exe" ]]

    run get_alias_options "hierarchy-test"
    [ "$status" -eq 0 ]
    [ "$output" = "user" ]
}

@test "integration: help system is comprehensive" {
    run win-run --help
    [ "$status" -eq 0 ]
    
    # Check that help contains all major sections
    [[ "$output" =~ "SYNOPSIS" ]]
    [[ "$output" =~ "DESCRIPTION" ]]
    [[ "$output" =~ "OPTIONS" ]]
    [[ "$output" =~ "CONFIGURATION" ]]
    [[ "$output" =~ "EXAMPLES" ]]
    [[ "$output" =~ "PATH CONVERSION" ]]
    [[ "$output" =~ "OUTPUT PROCESSING" ]]
    
    # Check that all implemented options are documented
    [[ "$output" =~ "--raw" ]]
    [[ "$output" =~ "-c FILE" ]]
    [[ "$output" =~ "--help" ]]
    
    # Check that environment variables are documented
    [[ "$output" =~ "WIN_WINDIR" ]]
    [[ "$output" =~ "WIN_PROGRAMFILES" ]]
}

@test "integration: error handling is user-friendly" {
    # Test various error conditions produce helpful messages
    
    # Missing command
    run win-run
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: No command specified" ]]
    
    # Invalid option
    run win-run --invalid
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Unknown option" ]]
    [[ "$output" =~ "Use --help for usage information" ]]
    
    # Missing config file argument
    run win-run -c
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: -c option requires a config file argument" ]]
    
    # Non-existent config file
    run win-run -c "/does/not/exist.yml" test
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Config file '/does/not/exist.yml' does not exist" ]]
}

@test "integration: logging functionality" {
    local config_file="$TEST_TEMP_DIR/log-test.yml"
    create_test_alias_config "$config_file"
    
    # Clear any existing log
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    rm -f "$log_file"
    
    # Run command that should create log entry
    export WSLUTIL_DEBUG=1
    run bash -c "timeout 2 win-run -c '$config_file' testcmd || true"
    
    # Check that log file was created and contains expected entry
    [ -f "$log_file" ]
    
    local log_content
    log_content=$(cat "$log_file")
    [[ "$log_content" =~ "win-run" ]]
    [[ "$log_content" =~ "alias: testcmd" ]]
    [[ "$log_content" =~ "ipconfig.exe" ]]
}