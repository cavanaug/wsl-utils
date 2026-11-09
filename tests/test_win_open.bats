#!/usr/bin/env bats

setup() {
    export WIN_WINDIR="$BATS_TEST_TMPDIR/Windows"
    export OPEN_INPUT="$BATS_TEST_TMPDIR/input"
    export OPEN_ARGS="$BATS_TEST_TMPDIR/args"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    unset WSLUTIL_DEBUG
    mkdir -p "$WIN_WINDIR/System32/WindowsPowerShell/v1.0" "$BATS_TEST_TMPDIR/bin"
    cat > "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$OPEN_ARGS"
cat > "$OPEN_INPUT"
exit "${OPEN_STATUS:-0}"
EOF
    # Never open a real GUI if the old Explorer implementation is exercised.
    printf '#!/bin/bash\nexit 1\n' > "$WIN_WINDIR/explorer.exe"
    cat > "$BATS_TEST_TMPDIR/bin/wslpath" <<'EOF'
#!/bin/bash
[[ "$1" == -w && "$#" == 2 ]] || exit 1
[[ "${OPEN_CONVERSION_FAIL:-0}" == 0 ]] || exit 1
printf 'C:\\Test\\%s\n' "${2##*/}"
EOF
    chmod +x "$WIN_WINDIR/explorer.exe" \
        "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" \
        "$BATS_TEST_TMPDIR/bin/wslpath"
    WIN_OPEN="$BATS_TEST_DIRNAME/../bin/win-open"
}

@test "win-open returns success when the launcher accepts the request" {
    run "$WIN_OPEN" 'https://example.com/'
    [ "$status" -eq 0 ]
    printf 'https://example.com/\0' > "$BATS_TEST_TMPDIR/expected"
    cmp "$OPEN_INPUT" "$BATS_TEST_TMPDIR/expected"
}

@test "win-open propagates launcher failure" {
    export OPEN_STATUS=7
    run "$WIN_OPEN" 'missing-document.pdf'
    [ "$status" -eq 7 ]
}

@test "win-open converts existing paths without splitting special characters" {
    local name='résumé [1] $test; quote'"'"'.pdf'
    touch "$BATS_TEST_TMPDIR/$name"
    run "$WIN_OPEN" "$BATS_TEST_TMPDIR/$name" 'https://example.com/?a=1&b=2'
    [ "$status" -eq 0 ]
    printf 'C:\\Test\\%s\0https://example.com/?a=1&b=2\0' "$name" > "$BATS_TEST_TMPDIR/expected"
    cmp "$OPEN_INPUT" "$BATS_TEST_TMPDIR/expected"
    # Targets must be data on stdin, not executable PowerShell source.
    ! grep -F "$name" "$OPEN_ARGS"
}

@test "win-open stops on path conversion failure" {
    export OPEN_CONVERSION_FAIL=1
    touch "$BATS_TEST_TMPDIR/document.pdf"
    run "$WIN_OPEN" "$BATS_TEST_TMPDIR/document.pdf"
    [ "$status" -ne 0 ]
    [ ! -e "$OPEN_INPUT" ]
}

@test "win-open with no targets requests the default Explorer window" {
    run "$WIN_OPEN"
    [ "$status" -eq 0 ]
    [ -f "$OPEN_INPUT" ]
    [ ! -s "$OPEN_INPUT" ]
}

@test "win-open preserves an explicitly empty target for launcher validation" {
    run "$WIN_OPEN" ''
    [ "$status" -eq 0 ]
    printf '\0' > "$BATS_TEST_TMPDIR/expected"
    cmp "$OPEN_INPUT" "$BATS_TEST_TMPDIR/expected"
}

# Run the actual PowerShell program, replacing only the GUI-launching cmdlet.
# This catches parsing, UTF-8 decoding, target splitting, and aggregate status bugs.
use_real_powershell() {
    local real_ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
    [ -x "$real_ps" ] || skip 'Windows PowerShell is unavailable'
    cat > "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" <<'EOF'
#!/bin/bash
prefix='
function Start-Process {
    [CmdletBinding()]
    param([string]$FilePath)
    if ($FilePath -eq "fail") { throw "test launch failure" }
    [Console]::WriteLine("opened:<{0}>", $FilePath)
}
'
exec /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    -NoLogo -NoProfile -NonInteractive -Command "$prefix${!#}"
EOF
}

@test "win-open PowerShell preserves Unicode and code-like target text as data" {
    use_real_powershell
    local target='https://example.com/résumé?q='"'"'; throw "injected"; #'
    run "$WIN_OPEN" "$target" $'a\nb'
    [ "$status" -eq 0 ]
    [[ "$output" == *"opened:<$target>"* ]]
    [[ "$output" == *$'opened:<a\nb>'* || "$output" == *$'opened:<a\r\nb>'* ]]
}

@test "win-open PowerShell continues after failure and returns aggregate failure" {
    use_real_powershell
    run "$WIN_OPEN" first fail last
    [ "$status" -eq 1 ]
    [[ "$output" == *'opened:<first>'* ]]
    [[ "$output" == *'test launch failure'* ]]
    [[ "$output" == *'opened:<last>'* ]]
}

@test "win-open PowerShell opens Explorer by default" {
    use_real_powershell
    run "$WIN_OPEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'\explorer.exe>'* ]]
}

@test "win-open reports a real Windows launch error for a missing document" {
    local real_ps=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
    [ -x "$real_ps" ] || skip 'Windows PowerShell is unavailable'
    printf '#!/bin/bash\nexec %q "$@"\n' "$real_ps" > \
        "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
    run "$WIN_OPEN" "C:\\__win_open_missing_${BATS_TEST_NUMBER}_$$.pdf"
    [ "$status" -eq 1 ]
    [[ "$output" == *'win-open:'* ]]
}
