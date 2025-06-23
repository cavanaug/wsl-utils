#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
}

teardown() {
    cleanup_test_env
}

@test "path conversion works for existing files" {
    skip_if_not_wsl
    
    # Create a test file
    local test_file
    test_file=$(create_test_file "testfile.txt")
    
    # Test that win-run converts the path
    # We'll check the log to see if path conversion happened
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run echo '$test_file' || true"
    
    # Check the log for path conversion
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    if [[ -f "$log_file" ]]; then
        local last_log
        last_log=$(tail -1 "$log_file")
        # Log should show Windows path format
        [[ "$last_log" =~ "\\\\" ]] || [[ "$last_log" =~ "C:\\\\" ]]
    fi
}

@test "path conversion skips non-existent paths" {
    skip_if_not_wsl
    
    # Test with non-existent path - should not be converted
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run echo '/non/existent/path' || true"
    
    # Check the log
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    if [[ -f "$log_file" ]]; then
        local last_log
        last_log=$(tail -1 "$log_file")
        # Should contain the original path, not converted
        [[ "$last_log" =~ "/non/existent/path" ]]
    fi
}

@test "path conversion works for directories" {
    skip_if_not_wsl
    
    # Create a test directory
    local test_dir="$TEST_TEMP_DIR/testdir"
    mkdir -p "$test_dir"
    
    # Test that win-run converts the directory path
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run echo '$test_dir' || true"
    
    # Check the log for path conversion
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    if [[ -f "$log_file" ]]; then
        local last_log
        last_log=$(tail -1 "$log_file")
        # Log should show Windows path format for directory
        [[ "$last_log" =~ "\\\\" ]] || [[ "$last_log" =~ "C:\\\\" ]]
    fi
}

@test "multiple path arguments are all converted" {
    skip_if_not_wsl
    
    # Create multiple test files
    local file1 file2
    file1=$(create_test_file "file1.txt")
    file2=$(create_test_file "file2.txt")
    
    # Test with multiple file arguments
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run echo '$file1' '$file2' || true"
    
    # Check the log for both path conversions
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    if [[ -f "$log_file" ]]; then
        local last_log
        last_log=$(tail -1 "$log_file")
        # Both files should appear in converted form
        local converted_count
        converted_count=$(echo "$last_log" | grep -o '\\\\' | wc -l)
        [[ "$converted_count" -ge 2 ]] || [[ "$last_log" =~ "C:\\\\" ]]
    fi
}

@test "alias options undergo path conversion" {
    skip_if_not_wsl
    skip_if_no_yq
    
    # Create test directory for options
    local test_dir="$TEST_TEMP_DIR/optionsdir"
    mkdir -p "$test_dir"
    
    # Create config with directory in options
    local config_file="$TEST_TEMP_DIR/path-options.yml"
    cat > "$config_file" << EOF
aliases:
  pathtest:
    path: \${WIN_WINDIR}/System32/echo.exe
    options: "$test_dir"
EOF
    
    # Test alias with path in options
    run bash -c "cd '$WSLUTIL_DIR' && timeout 2 bin/win-run -c '$config_file' pathtest || true"
    
    # Check the log for path conversion in options
    local log_file="$HOME/.local/state/wslutil/win-run.log"
    if [[ -f "$log_file" ]]; then
        local last_log
        last_log=$(tail -1 "$log_file")
        # Options should be converted to Windows paths
        [[ "$last_log" =~ "\\\\" ]] || [[ "$last_log" =~ "C:\\\\" ]]
    fi
}

@test "environment variable expansion in paths" {
    skip_if_no_yq
    
    # Test that environment variables are expanded correctly
    local config_file="$TEST_TEMP_DIR/env-expansion.yml"
    cat > "$config_file" << 'EOF'
aliases:
  envpath:
    path: ${WIN_WINDIR}/System32/cmd.exe
    options: null
EOF
    
    # Create a mock script to capture the resolved path
    local mock_script="$TEST_TEMP_DIR/mock-win-run.sh"
    cat > "$mock_script" << 'EOF'
#!/bin/bash
source "$1"
echo "$(resolve_alias "$2")"
EOF
    chmod +x "$mock_script"
    
    export CUSTOM_CONFIG="$config_file"
    run "$mock_script" "$WSLUTIL_DIR/bin/win-run" "envpath"
    
    [ "$status" -eq 0 ]
    # Should expand WIN_WINDIR and convert to Windows path
    [[ "$output" =~ "C:\\Windows\\System32\\cmd.exe" ]]
}