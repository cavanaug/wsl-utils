#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    skip_if_no_yq
}

teardown() {
    cleanup_test_env
}

@test "resolve_alias returns original command when no config" {
    # Test resolve_alias function directly by sourcing it
    source "$WSLUTIL_DIR/bin/win-run"
    
    run resolve_alias "nonexistent-command"
    [ "$status" -eq 0 ]
    [ "$output" = "nonexistent-command" ]
}

@test "resolve_alias finds alias in user config" {
    # Create user config with test alias
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    create_test_alias_config "$user_config"
    
    # Source the win-run script to get access to functions
    source "$WSLUTIL_DIR/bin/win-run"
    
    run resolve_alias "testcmd"
    [ "$status" -eq 0 ]
    # Should resolve to Windows path format
    [[ "$output" =~ "C:\\Windows\\System32\\ipconfig.exe" ]]
}

@test "resolve_alias expands environment variables" {
    # Create config with environment variable
    local config_file="$TEST_TEMP_DIR/env-test.yml"
    cat > "$config_file" << 'EOF'
aliases:
  envtest:
    path: ${WIN_WINDIR}/System32/cmd.exe
    options: null
EOF
    
    # Set custom config and source script
    export CUSTOM_CONFIG="$config_file"
    source "$WSLUTIL_DIR/bin/win-run"
    
    run resolve_alias "envtest"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "C:\\Windows\\System32\\cmd.exe" ]]
}

@test "get_alias_options returns options from config" {
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    create_test_alias_config "$user_config"
    
    source "$WSLUTIL_DIR/bin/win-run"
    
    run get_alias_options "testcmd-with-opts"
    [ "$status" -eq 0 ]
    [ "$output" = "/all" ]
}

@test "get_alias_options returns empty for alias without options" {
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    create_test_alias_config "$user_config"
    
    source "$WSLUTIL_DIR/bin/win-run"
    
    run get_alias_options "testcmd"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "get_alias_options returns empty for non-existent alias" {
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    create_test_alias_config "$user_config"
    
    source "$WSLUTIL_DIR/bin/win-run"
    
    run get_alias_options "nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "custom config file takes precedence" {
    # Create user config
    local user_config="$XDG_CONFIG_HOME/wslutil/win-run.yml"
    cat > "$user_config" << 'EOF'
aliases:
  testcmd:
    path: /mnt/c/Windows/System32/whoami.exe
    options: null
EOF
    
    # Create custom config with different alias
    local custom_config="$TEST_TEMP_DIR/custom.yml"
    cat > "$custom_config" << 'EOF'
aliases:
  testcmd:
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: null
EOF
    
    export CUSTOM_CONFIG="$custom_config"
    source "$WSLUTIL_DIR/bin/win-run"
    
    run resolve_alias "testcmd"
    [ "$status" -eq 0 ]
    # Should use custom config (ipconfig), not user config (whoami)
    [[ "$output" =~ "ipconfig.exe" ]]
    [[ ! "$output" =~ "whoami.exe" ]]
}

@test "alias resolution works with complex paths" {
    local config_file="$TEST_TEMP_DIR/complex.yml"
    cat > "$config_file" << 'EOF'
aliases:
  complex-path:
    path: ${WIN_PROGRAMFILES}/Test App/with spaces/app.exe
    options: null
EOF
    
    export CUSTOM_CONFIG="$config_file"
    source "$WSLUTIL_DIR/bin/win-run"
    
    run resolve_alias "complex-path"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Program Files" ]]
    [[ "$output" =~ "Test App" ]]
}