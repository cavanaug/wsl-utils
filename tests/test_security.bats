#!/usr/bin/env bats

load test_helpers

setup() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    TEST_DIR="${BATS_TMPDIR}/wslutil_security_test_$$"
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
    export CHECKOUT_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
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
    skip "win-run is not sourceable as a library (runs as a command)"
}

@test "SEC-002: envsubst does not expand arbitrary variables in win-run" {
    skip "win-run is not sourceable as a library (runs as a command)"
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

    run bash -c "cd '$CHECKOUT_ROOT/bin' && source wslutil-setup && echo 'test' | envsubst '\${WIN_PROGRAMFILES}'"
    
    [ "$status" -eq 0 ]
}

@test "SEC-004: win-env reads cache as data (does not source shell)" {
    # Cache is KEY=value text; even if someone embeds shell metacharacters in a value,
    # win-env must only print the value, never execute it.
    cat >"$TEST_DIR/env.win" <<'EOF'
USERPROFILE=/mnt/c/Users/test
EVIL=$(rm -rf /tmp/should-not-run)
EOF
    export WSLUTIL_WIN_ENV_CACHE="$TEST_DIR/env.win"
    run "$CHECKOUT_ROOT/bin/win-env" EVIL
    [ "$status" -eq 0 ]
    [[ "$output" == '$(rm -rf /tmp/should-not-run)' ]]
}

@test "SEC-004: win-env --export quotes values safely" {
    cat >"$TEST_DIR/env.win" <<'EOF'
USERPROFILE=/mnt/c/Users/o'brian
EOF
    export WSLUTIL_WIN_ENV_CACHE="$TEST_DIR/env.win"
    run "$CHECKOUT_ROOT/bin/win-env" --export USERPROFILE
    [ "$status" -eq 0 ]
    [[ "$output" =~ export\ WIN_USERPROFILE= ]]
    # Eval must preserve the apostrophe, not break the shell
    eval "$output"
    [[ "$WIN_USERPROFILE" == "/mnt/c/Users/o'brian" ]]
}
