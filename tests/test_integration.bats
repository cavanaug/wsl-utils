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
aliases:
  test-echo:
    path: ${WIN_WINDIR}/System32/cmd.exe
    options: "/c echo"
  test-ping:
    path: ${WIN_WINDIR}/System32/ping.exe
    options: "-n 1"
EOF
    
    # Test basic alias resolution
    run bash -c "cd '$WSLUTIL_DIR' && timeout 5 bin/win-run -c '$config_file' test-echo 'Hello World' || true"
    
    # Should not have config errors
    [[ ! "$output" =~ "Error:" ]]
}

@test "integration: environment variable expansion in full pipeline" {
    local config_file="$TEST_TEMP_DIR/env-integration.yml"
    cat > "$config_file" << 'EOF'
aliases:
  env-test:
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: null
  multi-env:
    path: ${WIN_PROGRAMFILES}/../Windows/System32/whoami.exe
    options: null
EOF
    
    # Test environment variable expansion
    export CUSTOM_CONFIG="$config_file"
    source "$WSLUTIL_DIR/bin/win-run"
    
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
    # Create global config
    local global_config="$WSLUTIL_DIR/config/win-run.yml"
    local global_backup=""
    if [[ -f "$global_config" ]]; then
        global_backup=$(mktemp)
        cp "$global_config" "$global_backup"
    fi
    
    cat > "$global_config" << 'EOF'
aliases:
  hierarchy-test:
    path: ${WIN_WINDIR}/System32/global.exe
    options: "global"
EOF
    
    # Create user config that overrides
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    cat > "$user_config" << 'EOF'
aliases:
  hierarchy-test:
    path: ${WIN_WINDIR}/System32/user.exe
    options: "user"
EOF
    
    source "$WSLUTIL_DIR/bin/win-run"
    
    # User config should take precedence
    run resolve_alias "hierarchy-test"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "user.exe" ]]
    
    run get_alias_options "hierarchy-test"
    [ "$status" -eq 0 ]
    [ "$output" = "user" ]
    
    # Restore global config
    if [[ -n "$global_backup" ]]; then
        mv "$global_backup" "$global_config"
    else
        rm -f "$global_config"
    fi
}

@test "integration: help system is comprehensive" {
    run "$WSLUTIL_DIR/bin/win-run" --help
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
    run "$WSLUTIL_DIR/bin/win-run"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: No command specified" ]]
    
    # Invalid option
    run "$WSLUTIL_DIR/bin/win-run" --invalid
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: Unknown option" ]]
    [[ "$output" =~ "Use --help for usage information" ]]
    
    # Missing config file argument
    run "$WSLUTIL_DIR/bin/win-run" -c
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Error: -c option requires a config file argument" ]]
    
    # Non-existent config file
    run "$WSLUTIL_DIR/bin/win-run" -c "/does/not/exist.yml" test
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
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run -c '$config_file' testcmd || true"
    
    # Check that log file was created and contains expected entry
    [ -f "$log_file" ]
    
    local log_content
    log_content=$(cat "$log_file")
    [[ "$log_content" =~ "win-run" ]]
    [[ "$log_content" =~ "alias: testcmd" ]]
    [[ "$log_content" =~ "ipconfig.exe" ]]
}