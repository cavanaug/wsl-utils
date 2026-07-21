#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    export XDG_CACHE_HOME="$TEST_TEMP_DIR/xdg-cache"
    _wsu_root="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    # shellcheck source=/dev/null
    source "$_wsu_root/lib/wslutil-clipboard-file.sh"
}

teardown() {
    cleanup_test_env
}

@test "store writes clip-timestamp-kind-shortsum.ext under cache" {
    src="$TEST_TEMP_DIR/payload.txt"
    printf 'hello-clipboard' >"$src"
    run wslutil_clipboard_store "$src" text txt
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^$XDG_CACHE_HOME/wslutil/clipboard/clip-[0-9]{8}-[0-9]{6}-text-[0-9a-f]{12}\.txt$ ]]
    [ -f "$output" ]
    [ "$(stat -c '%a' "$output")" = "600" ]
    [ "$(stat -c '%a' "$(dirname "$output")")" = "700" ]
    [ "$(cat "$output")" = "hello-clipboard" ]
}

@test "store dedups by kind+shortsum+ext" {
    src="$TEST_TEMP_DIR/payload.txt"
    printf 'same-bytes' >"$src"
    path1="$(wslutil_clipboard_store "$src" text txt)"
    # bump mtime/name potential: second store must reuse path1
    sleep 1
    path2="$(wslutil_clipboard_store "$src" text txt)"
    [ "$path1" = "$path2" ]
    count="$(find "$XDG_CACHE_HOME/wslutil/clipboard" -type f | wc -l)"
    [ "$count" -eq 1 ]
}

@test "emit url path and atpath shapes" {
    f="$TEST_TEMP_DIR/xdg-cache/wslutil/clipboard/clip-20260721-160812-text-aaaaaaaaaaaa.txt"
    mkdir -p "$(dirname "$f")"
    printf 'x' >"$f"
    [ "$(wslutil_clipboard_emit path "$f")" = "$f" ]
    [ "$(wslutil_clipboard_emit atpath "$f")" = "@$f" ]
    url="$(wslutil_clipboard_emit url "$f")"
    [[ "$url" == file://* ]]
    [[ "$url" == *"/clip-20260721-160812-text-aaaaaaaaaaaa.txt" ]]
}

@test "file url percent-encodes UTF-8 octets for non-ASCII path" {
    # café → c3 a9 in UTF-8; must not emit bare %E9 (Unicode codepoint)
    dir="$XDG_CACHE_HOME/wslutil/clipboard"
    mkdir -p "$dir"
    f="$dir/clip-café-text-bbbbbbbbbbbb.txt"
    printf 'x' >"$f"
    url="$(wslutil_clipboard_file_url "$f")"
    [[ "$url" == file://* ]]
    [[ "$url" == *"caf%C3%A9"* ]]
    [[ "$url" != *"caf%E9"* ]]
}

@test "format maps and rejects unknown" {
    [ "$(wslutil_clipboard_format_ext png)" = "png" ]
    [ "$(wslutil_clipboard_format_ext jpeg)" = "jpg" ]
    [ "$(wslutil_clipboard_format_ext jpg)" = "jpg" ]
    [ "$(wslutil_clipboard_format_kind html)" = "html" ]
    [ "$(wslutil_clipboard_format_kind txt)" = "text" ]
    [ "$(wslutil_clipboard_format_kind png)" = "image" ]
    run wslutil_clipboard_format_ext pdf
    [ "$status" -ne 0 ]
}
