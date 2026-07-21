#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env

    # Force PowerShell fallback path (avoid hardcoded /usr/bin/wl-paste).
    unset WSL2_GUI_APPS_ENABLED || true
    export WSL2_GUI_APPS_ENABLED=0

    mkdir -p "$TEST_TEMP_DIR/Windows/System32/WindowsPowerShell/v1.0"
    export WIN_WINDIR="$TEST_TEMP_DIR/Windows"

    # Mock powershell.exe: ignore args, emit fixture from WIN_PASTE_FIXTURE.
    cat > "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" << 'EOF'
#!/bin/bash
cat "${WIN_PASTE_FIXTURE:?}"
EOF
    chmod +x "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
}

teardown() {
    cleanup_test_env
}

@test "win-paste --help documents --raw and CR stripping" {
    run win-paste --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--raw" ]]
    [[ "$output" =~ "carriage return" || "$output" =~ "^M" || "$output" =~ "line ending" ]]
}

@test "win-paste strips trailing CR from text by default" {
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'line1\r\nline2\r\n' > "$WIN_PASTE_FIXTURE"

    run win-paste
    [ "$status" -eq 0 ]
    [ "$output" = $'line1\nline2' ]
}

@test "win-paste --raw preserves trailing CR" {
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'line1\r\nline2\r\n' > "$WIN_PASTE_FIXTURE"

    run win-paste --raw
    [ "$status" -eq 0 ]
    # bats $output strips trailing newlines; compare via printf capture
    result="$(win-paste --raw | od -An -tx1)"
    expected="$(printf 'line1\r\nline2\r\n' | od -An -tx1)"
    [ "$result" = "$expected" ]
}

@test "win-paste rejects multiple --file-* emit flags" {
    run win-paste --file-url --file-path
    [ "$status" -ne 0 ]
    [[ "$output" =~ file || "$stderr" =~ file || "$output" =~ exclusive || "$stderr" =~ exclusive ]]
}

@test "win-paste rejects --file-* with --raw" {
    run win-paste --file-path --raw
    [ "$status" -ne 0 ]
}

@test "win-paste --help documents file materialize flags" {
    run win-paste --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--file-url" ]]
    [[ "$output" =~ "--file-path" ]]
    [[ "$output" =~ "--file-atpath" ]]
    [[ "$output" =~ "--format" ]]
}
