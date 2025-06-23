#!/usr/bin/env bash

# Test helper functions for win-run tests

# Setup test environment
setup_test_env() {
    export WSLUTIL_DIR="$BATS_TEST_DIRNAME/.."
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export TEST_TEMP_DIR="$BATS_TMPDIR/wsl-utils-test-$$"
    mkdir -p "$TEST_TEMP_DIR"
    
    # Override config directories for testing
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
    mkdir -p "$XDG_CONFIG_HOME/wslutil"
    
    # Create test log directory
    export HOME="$TEST_TEMP_DIR"
    mkdir -p "$HOME/.local/state/wslutil"
    
    # Set up environment variables for testing
    export WIN_WINDIR="/mnt/c/Windows"
    export WIN_PROGRAMFILES="/mnt/c/Program Files"
    export WIN_PROGRAMFILES_X86="/mnt/c/Program Files (x86)"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create a test config file
create_test_config() {
    local config_file="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$config_file")"
    echo "$content" > "$config_file"
}

# Create a test alias config
create_test_alias_config() {
    local config_file="$1"
    
    cat > "$config_file" << 'EOF'
aliases:
  testcmd:
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: null
  testcmd-with-opts:
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: "/all"
  testping:
    path: ${WIN_WINDIR}/System32/ping.exe
    options: "-n 2"
EOF
}

# Mock wslpath command for testing
mock_wslpath() {
    local input_path="$1"
    
    # Simple mock: convert /mnt/c/... to C:\...
    if [[ "$input_path" =~ ^/mnt/c/(.*) ]]; then
        echo "C:\\${BASH_REMATCH[1]//\/\\}"
    else
        echo "$input_path"
    fi
}

# Check if running in WSL (for conditional tests)
is_wsl() {
    [[ -f /proc/version ]] && grep -q Microsoft /proc/version
}

# Skip test if not in WSL
skip_if_not_wsl() {
    if ! is_wsl; then
        skip "Test requires WSL environment"
    fi
}

# Skip test if yq is not available
skip_if_no_yq() {
    if ! command -v yq >/dev/null 2>&1; then
        skip "Test requires yq to be installed"
    fi
}

# Create a temporary test file
create_test_file() {
    local filename="$1"
    local content="${2:-test content}"
    
    echo "$content" > "$TEST_TEMP_DIR/$filename"
    echo "$TEST_TEMP_DIR/$filename"
}