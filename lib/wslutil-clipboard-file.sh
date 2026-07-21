# lib/wslutil-clipboard-file.sh — clipboard materialize helpers for win-paste

wslutil_clipboard_cache_dir() {
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/wslutil/clipboard"
    mkdir -m 700 -p "$dir"
    # ensure mode even if dir already existed with looser perms
    chmod 700 "$dir"
    printf '%s' "$dir"
}

wslutil_clipboard_shortsum() {
    local file="${1:?}"
    sha256sum -- "$file" | awk '{print substr($1,1,12)}'
}

wslutil_clipboard_find_dedup() {
    local kind="${1:?}" shortsum="${2:?}" ext="${3:?}" dir match
    dir="$(wslutil_clipboard_cache_dir)"
    # ponytail: glob scan is fine for a personal clipboard cache; upgrade to an index if it ever gets huge
    match="$(compgen -G "$dir/clip-"*"-${kind}-${shortsum}.${ext}" || true)"
    if [[ -n "$match" ]]; then
        # first match only (compgen may return multiple lines)
        printf '%s' "$(printf '%s\n' "$match" | head -n1)"
    fi
}

wslutil_clipboard_store() {
    local src="${1:?}" kind="${2:?}" ext="${3:?}"
    local dir shortsum existing ts dest
    [[ -f "$src" ]] || { echo "wslutil_clipboard_store: not a file: $src" >&2; return 1; }
    dir="$(wslutil_clipboard_cache_dir)"
    shortsum="$(wslutil_clipboard_shortsum "$src")"
    existing="$(wslutil_clipboard_find_dedup "$kind" "$shortsum" "$ext")"
    if [[ -n "$existing" ]]; then
        printf '%s' "$existing"
        return 0
    fi
    ts="$(date +%Y%m%d-%H%M%S)" # local time
    dest="${dir}/clip-${ts}-${kind}-${shortsum}.${ext}"
    cp -- "$src" "$dest"
    chmod 600 "$dest"
    printf '%s' "$dest"
}

wslutil_clipboard_file_url() {
    local abspath="${1:?}"
    [[ "$abspath" == /* ]] || { echo "wslutil_clipboard_file_url: path must be absolute" >&2; return 1; }
    # Percent-encode UTF-8 octets (not Unicode codepoints); keep /
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys, urllib.parse; sys.stdout.write("file://" + urllib.parse.quote(sys.argv[1], safe="/"))' "$abspath"
        return
    fi
    # Fallback: LC_ALL=C byte-wise walk of UTF-8 path bytes
    local encoded="" c hex i
    local LC_ALL=C
    for ((i = 0; i < ${#abspath}; i++)); do
        c="${abspath:i:1}"
        case "$c" in
            [A-Za-z0-9._~/-]) encoded+="$c" ;;
            *)
                printf -v hex '%%%02X' "'$c"
                encoded+="$hex"
                ;;
        esac
    done
    printf 'file://%s' "$encoded"
}

wslutil_clipboard_emit() {
    local mode="${1:?}" abspath="${2:?}"
    case "$mode" in
        path) printf '%s' "$abspath" ;;
        atpath) printf '@%s' "$abspath" ;;
        url) wslutil_clipboard_file_url "$abspath" ;;
        *) echo "wslutil_clipboard_emit: bad mode: $mode" >&2; return 1 ;;
    esac
}

wslutil_clipboard_format_ext() {
    case "${1:?}" in
        png) printf 'png' ;;
        jpeg|jpg) printf 'jpg' ;;
        gif) printf 'gif' ;;
        webp) printf 'webp' ;;
        txt) printf 'txt' ;;
        html) printf 'html' ;;
        *) return 1 ;;
    esac
}

wslutil_clipboard_format_kind() {
    case "${1:?}" in
        png|jpeg|jpg|gif|webp) printf 'image' ;;
        html) printf 'html' ;;
        txt) printf 'text' ;;
        *) return 1 ;;
    esac
}
