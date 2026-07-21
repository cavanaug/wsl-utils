#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    skip_if_no_yq
    # Will fail until lib exists
    source "$CHECKOUT_ROOT/lib/wslutil-exes-config.sh" 2>/dev/null || true
}

teardown() {
    cleanup_test_env
}

@test "exes merge: user entry replaces factory entry for same name" {
    local factory="$TEST_TEMP_DIR/factory.yml"
    local user="$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    cat > "$factory" << 'EOF'
exes:
  shared.exe:
    mode: direct
  only-factory.exe:
    mode: shim
EOF
    cat > "$user" << 'EOF'
exes:
  shared.exe:
    mode: none
    path: ${WIN_WINDIR}/System32/cmd.exe
  only-user.exe:
    mode: shim
EOF

    run wslutil_exes_load_merged "" "$TEST_TEMP_DIR" "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    # Write merged to temp for queries — or load_merged writes a file; prefer:
    # wslutil_exes_load_merged prints YAML with top-level exes:
    echo "$output" > "$TEST_TEMP_DIR/merged.yml"

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "shared.exe"
    [ "$output" = "none" ]

    run wslutil_exes_path "$TEST_TEMP_DIR/merged.yml" "shared.exe"
    [[ "$output" == *'${WIN_WINDIR}/System32/cmd.exe'* ]] || [[ "$output" == *'/System32/cmd.exe'* ]]

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "only-factory.exe"
    [ "$output" = "shim" ]

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "only-user.exe"
    [ "$output" = "shim" ]
}

@test "exes -c uses only custom file" {
    local factory="$TEST_TEMP_DIR/config/wslutil.yml"
    mkdir -p "$TEST_TEMP_DIR/config"
    cat > "$factory" << 'EOF'
exes:
  from-factory.exe:
    mode: direct
EOF
    local custom="$TEST_TEMP_DIR/custom.yml"
    cat > "$custom" << 'EOF'
exes:
  from-custom.exe:
    mode: shim
EOF
    # Also plant a user file that must be ignored when -c is set
    cat > "$XDG_CONFIG_HOME/wslutil/wslutil.yml" << 'EOF'
exes:
  from-user.exe:
    mode: none
EOF

    run wslutil_exes_load_merged "$custom" "$TEST_TEMP_DIR" "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    echo "$output" > "$TEST_TEMP_DIR/merged.yml"

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-custom.exe"
    [ "$output" = "shim" ]
    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-factory.exe"
    [ "$output" = "" ]
    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-user.exe"
    [ "$output" = "" ]
}

@test "exes expand applies only safe WIN_* vars" {
    export WIN_WINDIR="/mnt/c/Windows"
    export MALICIOUS="/tmp/evil"
    run wslutil_exes_expand '${WIN_WINDIR}/System32/x.exe ${MALICIOUS}'
    [ "$status" -eq 0 ]
    [[ "$output" == "/mnt/c/Windows/System32/x.exe "* ]] || [[ "$output" == "/mnt/c/Windows/System32/x.exe \${MALICIOUS}" ]] || [[ "$output" == *'/mnt/c/Windows/System32/x.exe'* ]]
    [[ "$output" != *"/tmp/evil"* ]]
}

@test "exes warn_legacy mentions win-run.yml when present" {
    touch "$XDG_CONFIG_HOME/wslutil/win-run.yml"
    run bash -c 'wslutil_exes_warn_legacy "$0" 2>&1' "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "win-run.yml" ]]
}
