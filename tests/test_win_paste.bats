#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env

    # Force PowerShell fallback path (avoid hardcoded /usr/bin/wl-paste).
    unset WSL2_GUI_APPS_ENABLED || true
    export WSL2_GUI_APPS_ENABLED=0

    mkdir -p "$TEST_TEMP_DIR/Windows/System32/WindowsPowerShell/v1.0"
    export WIN_WINDIR="$TEST_TEMP_DIR/Windows"

    # Mock powershell.exe: dispatcher for text/HTML/image materialize probes.
    cat > "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe" << 'EOF'
#!/bin/bash
# Test double: inspect joined args for materialize probes.
args="$*"
if [[ "$args" == *Get-Clipboard*Html* ]] || [[ "$args" == *TextFormat.Html* ]]; then
    if [[ -n "${WIN_PASTE_HTML_FIXTURE:-}" && -f "${WIN_PASTE_HTML_FIXTURE}" ]]; then
        cat "${WIN_PASTE_HTML_FIXTURE}"
        exit 0
    fi
    exit 1
fi
# Image save: real command uses Clipboard::GetImage + WIN_PASTE_OUT
if [[ "$args" == *GetImage* ]] || [[ "$args" == *ImageFormat* ]]; then
    if [[ -n "${WIN_PASTE_IMAGE_FIXTURE:-}" && -f "${WIN_PASTE_IMAGE_FIXTURE}" && -n "${WIN_PASTE_OUT:-}" ]]; then
        dest="${WIN_PASTE_OUT}"
        # wslpath -w yields \\wsl.localhost\Distro\...; map back for bash cp
        case "$dest" in
            \\\\wsl.localhost\\*|\\\\wsl\$\\*)
                dest="$(printf '%s\n' "$dest" | sed -E 's/^\\\\wsl(\.localhost|\$)\\[^\\]+//; s/\\/\//g')"
                ;;
        esac
        cp "${WIN_PASTE_IMAGE_FIXTURE}" "$dest"
        exit 0
    fi
    exit 1
fi
# Default: text
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

@test "win-paste --file-path materializes text and prints absolute path" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'agent-text' >"$WIN_PASTE_FIXTURE"

    run win-paste --file-path
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^$XDG_CACHE_HOME/wslutil/clipboard/clip-[0-9]{8}-[0-9]{6}-text-[0-9a-f]{12}\.txt$ ]]
    [ "$(cat "$output")" = "agent-text" ]
}

@test "win-paste --file-url and --file-atpath emit shapes" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'shape' >"$WIN_PASTE_FIXTURE"

    run win-paste --file-url
    [ "$status" -eq 0 ]
    [[ "$output" == file:///* ]]

    run win-paste --file-atpath
    [ "$status" -eq 0 ]
    [[ "$output" == @/* ]]
}

@test "win-paste --file-path dedups identical text" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'dedup-me' >"$WIN_PASTE_FIXTURE"

    p1="$(win-paste --file-path)"
    sleep 1
    p2="$(win-paste --file-path)"
    [ "$p1" = "$p2" ]
}

@test "win-paste --format html on plain text fails" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'nope' >"$WIN_PASTE_FIXTURE"

    run win-paste --file-path --format html
    [ "$status" -ne 0 ]
}

@test "win-paste --file-path prefers image when fixture present" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'ignore-text' >"$WIN_PASTE_FIXTURE"
    export WIN_PASTE_IMAGE_FIXTURE="$TEST_TEMP_DIR/clip.png"
    # 1x1 PNG
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' >"$WIN_PASTE_IMAGE_FIXTURE"

    run win-paste --file-path
    [ "$status" -eq 0 ]
    [[ "$output" =~ -image-[0-9a-f]{12}\.png$ ]]
}

@test "win-paste --format png materializes image" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'ignore-text' >"$WIN_PASTE_FIXTURE"
    export WIN_PASTE_IMAGE_FIXTURE="$TEST_TEMP_DIR/clip.png"
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' >"$WIN_PASTE_IMAGE_FIXTURE"

    run win-paste --file-path --format png
    [ "$status" -eq 0 ]
    [[ "$output" =~ -image-[0-9a-f]{12}\.png$ ]]
}

@test "win-paste --format jpeg errors with use png hint" {
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WIN_PASTE_FIXTURE="$TEST_TEMP_DIR/clip.txt"
    printf 'nope' >"$WIN_PASTE_FIXTURE"

    run win-paste --file-path --format jpeg
    [ "$status" -ne 0 ]
    [[ "$output" =~ use\ png || "$stderr" =~ use\ png ]]
}

@test "win-paste WSLg path materializes jpeg via wl-paste ladder" {
    export WSL2_GUI_APPS_ENABLED=1
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WL_PASTE="$TEST_TEMP_DIR/fake-wl-paste"

    cat >"$WL_PASTE" <<'EOF'
#!/bin/bash
# Test double: jpeg-only clipboard (no PNG) to exercise MIME ladder.
if [[ "$1" == "-l" ]]; then
    printf 'image/jpeg\ntext/plain\n'
    exit 0
fi
# wl_try_mime uses: wl-paste -n -t <mime>
mime=""
prev=""
for a in "$@"; do
    if [[ "$prev" == "-t" || "$prev" == "--type" ]]; then
        mime="$a"
    fi
    prev="$a"
done
if [[ "$mime" == "image/jpeg" ]]; then
    printf 'fake-jpeg-bytes'
    exit 0
fi
exit 1
EOF
    chmod +x "$WL_PASTE"

    run win-paste --file-path
    [ "$status" -eq 0 ]
    [[ "$output" =~ -image-[0-9a-f]{12}\.jpg$ ]]
    [ "$(cat "$output")" = "fake-jpeg-bytes" ]
}

@test "win-paste WSLg path converts image/bmp to png" {
    if ! command -v convert >/dev/null 2>&1 && ! command -v magick >/dev/null 2>&1 && ! command -v ffmpeg >/dev/null 2>&1; then
        skip "ImageMagick or ffmpeg required for BMP→PNG"
    fi

    export WSL2_GUI_APPS_ENABLED=1
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    export WL_PASTE="$TEST_TEMP_DIR/fake-wl-paste"
    export WIN_PASTE_BMP_FIXTURE="$TEST_TEMP_DIR/clip.bmp"

    # Minimal 1x1 24-bit BMP
    python3 - "$WIN_PASTE_BMP_FIXTURE" <<'PY'
import struct, sys
path = sys.argv[1]
pixel = bytes([0, 0, 255, 0])  # BGR + pad
bisize, bfOffBits = 40, 54
bfSize = bfOffBits + len(pixel)
open(path, "wb").write(
    struct.pack("<2sIHHI", b"BM", bfSize, 0, 0, bfOffBits)
    + struct.pack("<IiiHHIIiiII", bisize, 1, 1, 1, 24, 0, len(pixel), 0, 0, 0, 0)
    + pixel
)
PY

    cat >"$WL_PASTE" <<EOF
#!/bin/bash
if [[ "\$1" == "-l" ]]; then
    printf 'image/bmp\\n'
    exit 0
fi
mime=""
prev=""
for a in "\$@"; do
    if [[ "\$prev" == "-t" || "\$prev" == "--type" ]]; then
        mime="\$a"
    fi
    prev="\$a"
done
if [[ "\$mime" == "image/bmp" || "\$mime" == "image/x-ms-bmp" ]]; then
    cat "${WIN_PASTE_BMP_FIXTURE}"
    exit 0
fi
exit 1
EOF
    chmod +x "$WL_PASTE"

    run win-paste --file-path
    [ "$status" -eq 0 ]
    [[ "$output" =~ -image-[0-9a-f]{12}\.png$ ]]
    [ "$(file -b --mime-type "$output")" = "image/png" ]
}
