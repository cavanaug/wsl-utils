#!/usr/bin/env bats

load test_helpers

# Setup and teardown for each test
setup() {
    setup_test_env
    export WSLUTIL_SETUP="$CHECKOUT_ROOT/bin/wslutil-setup"
    export XDG_DATA_HOME="$TEST_TEMP_DIR/.local/share"
    export TEST_SHIMDIR="$XDG_DATA_HOME/wslutil/bin"
    
    # Create mock directories and files for testing
    mkdir -p "$TEST_TEMP_DIR/bin"
    mkdir -p "$TEST_TEMP_DIR/config"
    mkdir -p "$HOME/.config/wslutil"
    
    # Create a mock win-run script
    echo '#!/bin/bash' > "$TEST_TEMP_DIR/bin/win-run"
    echo 'echo "mock win-run $@"' >> "$TEST_TEMP_DIR/bin/win-run"
    chmod +x "$TEST_TEMP_DIR/bin/win-run"
    
    # Create cache directory structure
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/.cache"
    mkdir -p "$XDG_CACHE_HOME/wslutil"
}

teardown() {
    cleanup_test_env
}

# Test help functionality
@test "wslutil-setup --help shows usage information" {
    run "$WSLUTIL_SETUP" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: wslutil-setup" ]]
    [[ "$output" =~ "Configure and merge wslutil settings" ]]
    [[ "$output" =~ "--shims" ]]
    [[ "$output" =~ "--system" ]]
}

@test "wslutil-setup shows help for unknown option" {
    run "$WSLUTIL_SETUP" --unknown-option
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown option" ]]
    [[ "$output" =~ "Usage: wslutil-setup" ]]
}

# Test dry-run functionality
@test "wslutil-setup --dry-run shows what would be done" {
    # Create a minimal config file
    create_test_config "$XDG_CONFIG_HOME/wslutil/wsl.conf" "[interop]
appendWindowsPath = false"
    
    run "$WSLUTIL_SETUP" --system --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Running in dry-run mode" ]]
    [[ "$output" =~ "Would merge configuration" ]]
    [[ "$output" =~ "Dry-run completed" ]]
}

# Test missing crudini
@test "wslutil-setup fails gracefully when crudini is missing" {
    # Mock missing crudini
    old_path="$PATH"
    mkdir -p "$TEST_TEMP_DIR/empty-path"
    ln -s "$(command -v dirname)" "$TEST_TEMP_DIR/empty-path/dirname"
    export PATH="$TEST_TEMP_DIR/empty-path"
    
    run "$WSLUTIL_SETUP" --system
    export PATH="$old_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "crudini is required but not installed" ]]
}

# Test YAML processing with yq
@test "wslutil-setup processes wslutil.yml when yq is available" {
    skip_if_no_yq
    
    # Create a test wslutil.yml
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winexe:
  - cmd.exe
  - notepad.exe
winrun:
  - curl.exe
  - reg.exe'
    
    # Create mock Windows executables cache
    echo "/mnt/c/Windows/System32/cmd.exe" > "$XDG_CACHE_HOME/wslutil/programs"
    echo "/mnt/c/Windows/System32/notepad.exe" >> "$XDG_CACHE_HOME/wslutil/programs"
    echo "/mnt/c/Windows/System32/curl.exe" >> "$XDG_CACHE_HOME/wslutil/programs"
    echo "/mnt/c/Windows/System32/reg.exe" >> "$XDG_CACHE_HOME/wslutil/programs"
    
    # Create the actual mock executables
    mkdir -p "/mnt/c/Windows/System32" 2>/dev/null || true
    touch "/mnt/c/Windows/System32/cmd.exe" 2>/dev/null || true
    touch "/mnt/c/Windows/System32/notepad.exe" 2>/dev/null || true
    touch "/mnt/c/Windows/System32/curl.exe" 2>/dev/null || true
    touch "/mnt/c/Windows/System32/reg.exe" 2>/dev/null || true
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing wslutil configuration" ]]
    [[ "$output" =~ "Processing winrun entries" ]]
    [[ "$output" =~ "Processing winexe entries" ]]
}

# Test variable expansion in wslutil.yml
@test "wslutil-setup expands variables in wslutil.yml paths" {
    skip_if_no_yq
    
    # Set up test environment variables
    export WIN_PROGRAMFILES="$TEST_TEMP_DIR/Program Files"
    mkdir -p "$WIN_PROGRAMFILES/TestApp/bin"
    echo "mock executable" > "$WIN_PROGRAMFILES/TestApp/bin/testapp"
    
    # Create wslutil.yml with variable expansion
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winexe:
  - "${WIN_PROGRAMFILES}/TestApp/bin/testapp"'
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing wslutil configuration" ]]
    [[ "$output" =~ "Creating direct symlink: testapp" ]]
}

# Test skipping missing executables
@test "wslutil-setup skips missing full path executables" {
    skip_if_no_yq
    
    # Create wslutil.yml with non-existent path
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winexe:
  - "/nonexistent/path/to/app.exe"'
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping missing executable: /nonexistent/path/to/app.exe" ]]
}

# Test existing symlink detection
@test "wslutil-setup skips existing correct symlinks" {
    skip_if_no_yq
    
    # Create a test wslutil.yml
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winrun:
  - testexe.exe'
    
    # Create existing symlink
    mkdir -p "$TEST_SHIMDIR"
    win_run_target="$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)/win-run"
    ln -s "$win_run_target" "$TEST_SHIMDIR/testexe.exe"
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Symlink already exists: testexe.exe -> $win_run_target (skipping)" ]]
}

# Test shim config precedence
@test "wslutil-setup prefers user shim config over factory config" {
    skip_if_no_yq
    
    # Create user config
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winrun:
  - user-tool.exe'
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "$XDG_CONFIG_HOME/wslutil/wslutil.yml" ]]
    [[ "$output" =~ "Creating winrun symlink: user-tool.exe" ]]
}

# Test INI file merging with crudini
@test "wslutil-setup merges INI configuration files" {
    # Create source config file
    create_test_config "$TEST_TEMP_DIR/config/wsl.conf" "[interop]
appendWindowsPath = false
enabled = true"
    
    # Create target file (simulating /etc/wsl.conf)
    target_file="$TEST_TEMP_DIR/etc_wsl.conf"
    mkdir -p "$(dirname "$target_file")"
    touch "$target_file"
    
    # Mock the merge by running crudini directly
    if command -v crudini >/dev/null 2>&1; then
        run crudini --merge "$target_file" < "$TEST_TEMP_DIR/config/wsl.conf"
        [ "$status" -eq 0 ]
        
        # Verify content was merged
        run crudini --get "$target_file" interop appendWindowsPath
        [ "$status" -eq 0 ]
        [ "$output" = "false" ]
    else
        skip "crudini not available for testing"
    fi
}

# Test Windows executable cache building
@test "wslutil-setup builds Windows executable cache" {
    skip_if_no_yq
    
    # Create mock Windows directories with executables
    mkdir -p "$TEST_TEMP_DIR/Windows/System32"
    mkdir -p "$TEST_TEMP_DIR/Program Files/App1"
    mkdir -p "$TEST_TEMP_DIR/Program Files (x86)/App2"
    
    echo "mock" > "$TEST_TEMP_DIR/Windows/System32/cmd.exe"
    echo "mock" > "$TEST_TEMP_DIR/Program Files/App1/app1.exe"
    echo "mock" > "$TEST_TEMP_DIR/Program Files (x86)/App2/app2.exe"
    
    # Set up environment to use test directories
    export WIN_WINDIR="$TEST_TEMP_DIR/Windows"
    export WIN_PROGRAMFILES="$TEST_TEMP_DIR/Program Files"
    export WIN_PROGRAMFILES_X86="$TEST_TEMP_DIR/Program Files (x86)"
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"
    mkdir -p "$WIN_USERPROFILE/AppData/Local/Programs"
    
    # Create wslutil.yml that will trigger cache building
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winexe:
  - cmd.exe'
    
    run "$WSLUTIL_SETUP" --shims --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Building/updating Windows executable cache" ]]
    [[ "$output" =~ "Building executable cache using Windows PATH" ]]
    
    # Verify cache file was created
    [ -f "$XDG_CACHE_HOME/wslutil/programs" ]
    
    # Verify cache contains expected entries
    run grep "cmd.exe" "$XDG_CACHE_HOME/wslutil/programs"
    [ "$status" -eq 0 ]
}

# Test shimdir symlink creation for winrun
@test "wslutil-setup --shims writes winrun links to XDG shimdir" {
    skip_if_no_yq

    # Create wslutil.yml
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winrun:
  - test.exe'
    
    # Run setup (not dry-run to actually create symlinks)
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"  # Required to avoid error
    run "$WSLUTIL_SETUP" --shims
    [ "$status" -eq 0 ]
    
    # Verify symlink was created in the XDG shimdir with an absolute target
    [ -L "$TEST_SHIMDIR/test.exe" ]
    [ ! -e "$TEST_TEMP_DIR/bin/test.exe" ]
    link_target=$(readlink "$TEST_SHIMDIR/test.exe")
    [ "$link_target" = "$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)/win-run" ]
}

# Test error handling for missing win-run script
@test "wslutil-setup handles missing win-run script gracefully" {
    skip_if_no_yq

    # Run a checkout-shaped copy of setup without win-run beside it.
    missing_winrun_checkout="$TEST_TEMP_DIR/missing-winrun-checkout"
    mkdir -p "$missing_winrun_checkout/bin" "$missing_winrun_checkout/config" "$missing_winrun_checkout/env" "$missing_winrun_checkout/lib"
    cp "$BATS_TEST_DIRNAME/../bin/wslutil-setup" "$missing_winrun_checkout/bin/wslutil-setup"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$missing_winrun_checkout/lib/wslutil-paths.sh"
    
    # Create wslutil.yml with winrun entry
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'winrun:
  - test.exe'
    
    run "$missing_winrun_checkout/bin/wslutil-setup" --shims --dry-run
    [ "$status" -eq 0 ]  # Should continue despite error
    [[ "$output" =~ "win-run script not found" ]]
}

# Test config directory not found handling
@test "wslutil-setup handles missing config directories gracefully" {
    # Don't create any config directories
    rm -rf "$XDG_CONFIG_HOME/wslutil"
    
    run "$WSLUTIL_SETUP" --system --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Config directory not found" ]]
    [[ "$output" =~ "skipping" ]]
}

# Test missing WIN_USERPROFILE handling
@test "wslutil-setup handles missing WIN_USERPROFILE gracefully" {
    # Create minimal system config
    create_test_config "$XDG_CONFIG_HOME/wslutil/wsl.conf" "[interop]
appendWindowsPath = false"
    
    # Unset WIN_USERPROFILE
    unset WIN_USERPROFILE
    
    run "$WSLUTIL_SETUP" --system --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "WIN_USERPROFILE not set - skipping Windows config files" ]]
}
