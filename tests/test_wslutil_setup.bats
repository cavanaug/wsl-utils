#!/usr/bin/env bats

load test_helpers

# Setup and teardown for each test
setup() {
    setup_test_env
    export WSLUTIL_SETUP="$CHECKOUT_ROOT/bin/wslutil-setup"
    export WSLUTIL_SETUP_LINUX="$CHECKOUT_ROOT/bin/wslutil-setup-linux"
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

# Install a fake sudo that logs its invocation and execs the remaining args
# directly (no real elevation), so wslutil-setup-linux's re-exec path can be
# exercised without needing root or prompting for a password.
setup_fake_sudo() {
    export WSLUTIL_SUDO_LOG="$TEST_TEMP_DIR/fake-sudo.log"
    : >"$WSLUTIL_SUDO_LOG"
    export WSLUTIL_SUDO="$TEST_TEMP_DIR/fake-sudo"
    cat >"$WSLUTIL_SUDO" <<'EOF'
#!/bin/bash
echo "fake-sudo $*" >>"${WSLUTIL_SUDO_LOG:?}"
exec "$@"
EOF
    chmod +x "$WSLUTIL_SUDO"
}

# Test CLI subcommand contract
@test "wslutil-setup --help documents exes windows linux" {
    run "$WSLUTIL_SETUP" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: wslutil-setup" ]]
    [[ "$output" =~ "exes" ]]
    [[ "$output" =~ "windows" ]]
    [[ "$output" =~ "linux" ]]
    [[ "$output" != *"--shims"* ]]
    [[ "$output" != *"--system"* ]]
}

@test "wslutil-setup without subcommand prints usage and fails" {
    run "$WSLUTIL_SETUP"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "exes" ]]
    [[ "$output" =~ "windows" ]]
    [[ "$output" =~ "linux" ]]
}

@test "wslutil-setup unknown subcommand fails" {
    run "$WSLUTIL_SETUP" bogons
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown" ]] || [[ "$output" =~ "Usage:" ]]
}

@test "wslutil-setup rejects -c/--config for non-exes subcommands" {
    config_file="$TEST_TEMP_DIR/custom-wslutil.yml"
    create_test_config "$config_file" 'winexe:
  - cmd.exe'

    run "$WSLUTIL_SETUP" windows -c "$config_file"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "only valid with the exes subcommand" ]]
}

# Test dry-run functionality
@test "wslutil-setup windows --dry-run shows what would be done" {
    # Create a minimal Windows profile config file
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslconfig" "[wsl2]
memory=4GB"
    
    run "$WSLUTIL_SETUP" windows --dry-run
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
    
    run "$WSLUTIL_SETUP" windows
    export PATH="$old_path"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "crudini is required but not installed" ]]
}

# Test YAML processing with yq
@test "wslutil-setup exes processes exes: map entries when yq is available" {
    skip_if_no_yq

    # Create a test wslutil.yml using the unified exes: map (direct + shim modes)
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  cmd.exe:
    mode: direct
  notepad.exe:
    mode: direct
  curl.exe:
    mode: shim
  reg.exe:
    mode: shim
'

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
    
    run "$WSLUTIL_SETUP" exes -c "$config_file" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing exes entries" ]]
    [[ "$output" =~ "Creating direct symlink: cmd.exe" ]]
    [[ "$output" =~ "Creating winrun symlink: curl.exe" ]]
}

# Test variable expansion in wslutil.yml
@test "wslutil-setup expands variables in wslutil.yml paths" {
    skip_if_no_yq
    
    # Set up test environment variables (all WIN_* set so win-env bootstrap does not overwrite)
    export WIN_WINDIR="$TEST_TEMP_DIR/Windows"
    export WIN_PROGRAMFILES="$TEST_TEMP_DIR/Program Files"
    export WIN_PROGRAMFILES_X86="$TEST_TEMP_DIR/Program Files (x86)"
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"
    export WIN_LOCALAPPDATA="$WIN_USERPROFILE/AppData/Local"
    export WIN_APPDATA="$WIN_USERPROFILE/AppData/Roaming"
    mkdir -p "$WIN_PROGRAMFILES/TestApp/bin"
    echo "mock executable" > "$WIN_PROGRAMFILES/TestApp/bin/testapp"
    
    # Create wslutil.yml with variable expansion
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  testapp:
    mode: direct
    path: "${WIN_PROGRAMFILES}/TestApp/bin/testapp"
'

    run "$WSLUTIL_SETUP" exes -c "$config_file" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Processing exes entries" ]]
    [[ "$output" =~ "Creating direct symlink: testapp" ]]
}

# Test skipping missing executables
@test "wslutil-setup skips missing full path executables" {
    skip_if_no_yq
    
    # Create wslutil.yml with non-existent path
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  app.exe:
    mode: direct
    path: "/nonexistent/path/to/app.exe"
'

    run "$WSLUTIL_SETUP" exes -c "$config_file" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping missing executable: /nonexistent/path/to/app.exe" ]]
}

# Test existing symlink detection
@test "wslutil-setup skips existing correct symlinks" {
    skip_if_no_yq
    
    # Create a test wslutil.yml
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  testexe.exe:
    mode: shim
'

    # Create existing symlink
    mkdir -p "$TEST_SHIMDIR"
    win_run_target="$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)/win-run"
    ln -s "$win_run_target" "$TEST_SHIMDIR/testexe.exe"
    
    run "$WSLUTIL_SETUP" exes -c "$config_file" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Symlink already exists: testexe.exe -> $win_run_target (skipping)" ]]
}

# Test factory+user merge precedence (user entry overrides factory entry for the same key)
@test "wslutil-setup exes merges user wslutil.yml with factory (user wins per key)" {
    skip_if_no_yq

    # Factory config ships cmd.exe with mode: direct; user overrides it to mode: shim
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'exes:
  cmd.exe:
    mode: shim
'

    run "$WSLUTIL_SETUP" exes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Creating winrun symlink: cmd.exe" ]]
    [[ "$output" != *"Creating direct symlink: cmd.exe"* ]]
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
    
    # Create wslutil.yml that will trigger cache building (name-lookup mode: direct, no path)
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  cmd.exe:
    mode: direct
'

    run "$WSLUTIL_SETUP" exes -c "$config_file" --dry-run
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
@test "wslutil-setup exes writes winrun links to XDG shimdir" {
    skip_if_no_yq

    # Create wslutil.yml
    local config_file="$TEST_TEMP_DIR/wslutil.yml"
    create_test_config "$config_file" 'exes:
  test.exe:
    mode: shim
'

    # Run setup (not dry-run to actually create symlinks)
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"  # Required to avoid error
    run "$WSLUTIL_SETUP" exes -c "$config_file"
    [ "$status" -eq 0 ]
    
    # Verify symlink was created in the XDG shimdir with an absolute target
    [ -L "$TEST_SHIMDIR/test.exe" ]
    [ ! -e "$TEST_TEMP_DIR/bin/test.exe" ]
    link_target=$(readlink "$TEST_SHIMDIR/test.exe")
    [ "$link_target" = "$(cd "$BATS_TEST_DIRNAME/../bin" && pwd)/win-run" ]
}

# Test mode: none removes a stale shimdir link
@test "wslutil-setup exes removes shimdir link when mode is none" {
    skip_if_no_yq

    mkdir -p "$TEST_SHIMDIR"
    ln -s "$CHECKOUT_ROOT/bin/win-run" "$TEST_SHIMDIR/stale.exe"

    local config_file="$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    create_test_config "$config_file" 'exes:
  stale.exe:
    mode: none
'

    # Use -c so only this file applies (factory/user merge would not re-add stale.exe here anyway)
    run "$WSLUTIL_SETUP" exes -c "$config_file"
    [ "$status" -eq 0 ]
    [ ! -e "$TEST_SHIMDIR/stale.exe" ]
}

# Test error handling for missing win-run script
@test "wslutil-setup handles missing win-run script gracefully" {
    skip_if_no_yq

    # Run a checkout-shaped copy of setup without win-run beside it.
    missing_winrun_checkout="$TEST_TEMP_DIR/missing-winrun-checkout"
    mkdir -p "$missing_winrun_checkout/bin" "$missing_winrun_checkout/config" "$missing_winrun_checkout/env" "$missing_winrun_checkout/lib"
    cp "$BATS_TEST_DIRNAME/../bin/wslutil-setup" "$missing_winrun_checkout/bin/wslutil-setup"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$missing_winrun_checkout/lib/wslutil-paths.sh"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-setup-common.sh" "$missing_winrun_checkout/lib/wslutil-setup-common.sh"
    cp "$BATS_TEST_DIRNAME/../lib/wslutil-exes-config.sh" "$missing_winrun_checkout/lib/wslutil-exes-config.sh"
    
    # Create wslutil.yml with a shim entry
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'exes:
  test.exe:
    mode: shim
'
    
    run "$missing_winrun_checkout/bin/wslutil-setup" exes --dry-run
    [ "$status" -eq 0 ]  # Should continue despite error
    [[ "$output" =~ "win-run script not found" ]]
}

# Test config directory not found handling
@test "wslutil-setup handles missing config directories gracefully" {
    # Don't create any config directories
    rm -rf "$XDG_CONFIG_HOME/wslutil"
    export WIN_USERPROFILE="$TEST_TEMP_DIR/Users/testuser"
    
    run "$WSLUTIL_SETUP" windows --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Config directory not found" ]]
    [[ "$output" =~ "skipping" ]]
}

# Test missing WIN_USERPROFILE handling when bootstrap cannot load shellenv
@test "wslutil-setup handles missing WIN_USERPROFILE gracefully" {
    # Create minimal Windows profile config
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslconfig" "[wsl2]
memory=4GB"
    
    # Unset WIN_* so bootstrap runs
    unset WIN_USERPROFILE WIN_WINDIR
    
    run "$WSLUTIL_SETUP" windows --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bootstrapping Windows environment variables via win-env" ]]
    if is_wsl; then
        [[ "$output" != *"WIN_USERPROFILE not set - skipping Windows config files"* ]]
    else
        [[ "$output" =~ "Could not bootstrap WIN_\* via win-env" ]]
        [[ "$output" =~ "WIN_USERPROFILE not set - skipping Windows config files" ]]
    fi
}

# Test WIN_* bootstrap when shellenv was not loaded
@test "wslutil-setup bootstraps WIN_* via win-env when not preloaded" {
    skip_if_not_wsl
    skip_if_no_yq
    
    unset WIN_USERPROFILE WIN_WINDIR WIN_PROGRAMFILES WIN_PROGRAMFILES_X86
    
    # Use factory config (no user wslutil.yml) so WIN_USERPROFILE paths are exercised
    rm -f "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    
    run "$WSLUTIL_SETUP" exes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Bootstrapping Windows environment variables via win-env" ]]
    [[ "$output" != *"Could not bootstrap WIN_* via win-env"* ]]
}

# --- wslutil-setup-linux ---

@test "wslutil-setup-linux --help shows usage" {
    run "$WSLUTIL_SETUP_LINUX" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "wslutil-setup-linux" ]]
    [[ "$output" =~ "/etc/wsl.conf" ]]
    [[ "$output" =~ "sudo wslutil-setup-linux" ]]
}

@test "wslutil setup linux --dry-run merges wsl.conf via fake sudo" {
    setup_fake_sudo

    create_test_config "$XDG_CONFIG_HOME/wslutil/wsl.conf" "[interop]
appendWindowsPath = false"

    run "$WSLUTIL_SETUP" linux --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would merge configuration" ]]
    [[ "$output" =~ "wsl.conf" ]]
}

@test "wslutil-setup-linux non-root re-execs via WSLUTIL_SUDO" {
    if [[ "$EUID" -eq 0 ]]; then
        skip "test requires non-root EUID"
    fi
    setup_fake_sudo

    run "$WSLUTIL_SETUP_LINUX" --dry-run
    [ "$status" -eq 0 ]

    run grep -q "wslutil-setup-linux" "$WSLUTIL_SUDO_LOG"
    [ "$status" -eq 0 ]
}
