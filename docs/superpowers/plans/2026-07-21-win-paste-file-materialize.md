# `win-paste` File Materialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `--file-url` / `--file-path` / `--file-atpath` (and `--format`) to `win-paste` so clipboard payloads become a private cache file and a single agent-friendly reference on stdout.

**Architecture:** Pure bash helpers in `lib/wslutil-clipboard-file.sh` own cache paths, hashing, dedup, naming, and emit shapes. `bin/win-paste` parses flags, fetches the richest (or `--format`) payload via WSLg `wl-paste` or PowerShell, writes through the helper, then prints one reference. Default text paste path stays unchanged when no `--file-*` flag is set.

**Tech Stack:** Bash, BATS, PowerShell (`-NoProfile`), `wl-paste` (WSLg), `sha256sum`, GNU `date`

**Spec:** `docs/superpowers/specs/2026-07-21-win-paste-file-materialize-design.md`

## Global Constraints

- Emit flags: `--file-url` | `--file-path` | `--file-atpath` — exactly one in materialize mode
- Always materialize when a `--file-*` flag is set (including short text)
- Default pick (no `--format`): richest = image → html → plain text
- `--format` short names only: `png` | `jpeg` | `jpg` | `gif` | `webp` | `txt` | `html`
- Cache: `${XDG_CACHE_HOME:-$HOME/.cache}/wslutil/clipboard/` mode `0700`; files `0600`
- Filename: `clip-<local YYYYMMDD-HHMMSS>-<kind>-<12-hex-sha256>.<ext>`
- Kind reflects **written** bytes: `image` | `html` | `text`; `jpeg`/`jpg` → `.jpg`
- Dedup: reuse first `clip-*-<kind>-<shortsum>.<ext>` match; skip write
- `--raw` + `--file-*` → error; empty clipboard / bad conversion → stderr + non-zero
- No new top-level command; no HDROP; no cache GC

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-clipboard-file.sh` | Cache dir, shortsum, dedup lookup, store, emit (`url`/`path`/`atpath`), format→ext/kind maps, `file://` encoding |
| `bin/win-paste` | Flag parse; help; richest/`--format` fetch (WSLg + PowerShell); call store+emit; keep legacy text paste |
| `Makefile` | Install new lib next to existing `lib/*.sh` |
| `tests/test_clipboard_file.bats` | Unit tests for helper (store/dedup/emit/format) |
| `tests/test_win_paste.bats` | CLI: mutual exclusion, text materialize shapes, dedup, `--format` errors, CR regression, help |
| `README.md` | Short usage note for `--file-*` |

---

### Task 1: Clipboard-file helper — store / dedup / emit

**Files:**
- Create: `lib/wslutil-clipboard-file.sh`
- Create: `tests/test_clipboard_file.bats`
- Modify: `Makefile` (install the new lib)

**Interfaces:**
- Produces (sourceable functions):
  - `wslutil_clipboard_cache_dir` → prints cache dir path (creates `0700` if missing)
  - `wslutil_clipboard_shortsum <file>` → 12 lowercase hex chars (SHA-256 of file bytes)
  - `wslutil_clipboard_find_dedup <kind> <shortsum> <ext>` → existing abspath or empty
  - `wslutil_clipboard_store <srcfile> <kind> <ext>` → prints abspath of cached file (dedup or new `clip-…` name, `0600`)
  - `wslutil_clipboard_emit <mode> <abspath>` → prints one line (`url`|`path`|`atpath`)
  - `wslutil_clipboard_format_ext <format>` → `png`|`jpg`|`gif`|`webp`|`txt`|`html` or return 1
  - `wslutil_clipboard_format_kind <format>` → `image`|`html`|`text` or return 1
  - `wslutil_clipboard_file_url <abspath>` → `file://…` with percent-encoding

- [ ] **Step 1: Write failing helper tests**

Create `tests/test_clipboard_file.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_clipboard_file.bats`

Expected: FAIL (missing `lib/wslutil-clipboard-file.sh` or undefined functions)

- [ ] **Step 3: Implement helper library**

Create `lib/wslutil-clipboard-file.sh`:

```bash
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
    local abspath="${1:?}" encoded="" c hex i
    [[ "$abspath" == /* ]] || { echo "wslutil_clipboard_file_url: path must be absolute" >&2; return 1; }
    # Percent-encode path bytes; keep /
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
```

- [ ] **Step 4: Install lib from Makefile**

Add alongside existing lib installs in `Makefile`:

```makefile
	install -m 0644 lib/wslutil-clipboard-file.sh $(DATADIR)/lib/wslutil-clipboard-file.sh
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_clipboard_file.bats`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/wslutil-clipboard-file.sh tests/test_clipboard_file.bats Makefile
git commit -m "$(cat <<'EOF'
feat: add clipboard file cache helpers for win-paste

EOF
)"
```

---

### Task 2: CLI flag parsing, help, and conflict errors

**Files:**
- Modify: `bin/win-paste`
- Modify: `tests/test_win_paste.bats`

**Interfaces:**
- Consumes: nothing from Task 1 yet (parse-only)
- Produces: `win-paste` recognizes `--file-url` / `--file-path` / `--file-atpath` / `--format <fmt>`; exits 1 on mutual exclusion or `--raw` combo; help documents flags

- [ ] **Step 1: Write failing CLI tests**

Append to `tests/test_win_paste.bats`:

```bash
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
```

Note: BATS merges stderr into `$output` unless `run` is used carefully; assert on `$output` if that is the project norm (match existing tests).

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: FAIL on new assertions (help/flags missing or no error)

- [ ] **Step 3: Implement flag parsing + help in `bin/win-paste`**

Source the helper using the same checkout/install pattern as `bin/win-run`:

```bash
_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_wsu_bin/../lib/wslutil-clipboard-file.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../lib/wslutil-clipboard-file.sh"
elif [[ -f "$_wsu_bin/../share/wslutil/lib/wslutil-clipboard-file.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../share/wslutil/lib/wslutil-clipboard-file.sh"
else
    echo "win-paste: clipboard helper not found" >&2
    exit 1
fi
```

Only require the helper when a `--file-*` flag is present (optional optimization); requiring always is fine and simpler.

Replace the simple argv loop with parsing that sets:

```bash
RAW=0
FILE_MODE=""   # url|path|atpath|empty
FORMAT=""      # optional short name
ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --raw) RAW=1; shift ;;
        --file-url|--file-path|--file-atpath)
            if [[ -n "$FILE_MODE" ]]; then
                echo "win-paste: use only one of --file-url, --file-path, --file-atpath" >&2
                exit 1
            fi
            case "$1" in
                --file-url) FILE_MODE=url ;;
                --file-path) FILE_MODE=path ;;
                --file-atpath) FILE_MODE=atpath ;;
            esac
            shift
            ;;
        --format)
            [[ $# -ge 2 ]] || { echo "win-paste: --format requires a value" >&2; exit 1; }
            FORMAT="$2"
            shift 2
            ;;
        --format=*)
            FORMAT="${1#--format=}"
            shift
            ;;
        -h|--help)
            # existing help path — or fall through if help already handled at top
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ -n "$FILE_MODE" && $RAW -eq 1 ]]; then
    echo "win-paste: --raw cannot be combined with --file-*" >&2
    exit 1
fi

if [[ -n "$FORMAT" ]]; then
    wslutil_clipboard_format_ext "$FORMAT" >/dev/null || {
        echo "win-paste: unsupported --format: $FORMAT" >&2
        exit 1
    }
fi
```

Update the `--help` text to document:

```text
    --file-url      Materialize clipboard to cache; print file:// URL
    --file-path     Materialize clipboard to cache; print absolute path
    --file-atpath   Materialize clipboard to cache; print @<absolute-path>
    --format FMT    Convert/write as png|jpeg|jpg|gif|webp|txt|html
```

Include a one-line note about cache location and richest-default.

When `FILE_MODE` is empty, keep the existing `paste_clipboard` / CR-strip behavior (pass remaining `ARGS` through).

When `FILE_MODE` is set, for this task only: `echo "win-paste: file materialize not implemented" >&2; exit 1` — Task 3 fills it in. Alternatively skip the stub and implement text materialize in Task 3 immediately after these parse tests pass for help/conflicts only.

Prefer: after parse tests for conflicts/help pass, leave a clear branch:

```bash
if [[ -n "$FILE_MODE" ]]; then
    materialize_clipboard_and_emit "$FILE_MODE" "$FORMAT"
    exit $?
fi
```

with `materialize_clipboard_and_emit` stubbed to exit 1 until Task 3 — but then help/conflict tests must not call materialize. They already do not.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: PASS (including existing CR / `--raw` tests)

- [ ] **Step 5: Commit**

```bash
git add bin/win-paste tests/test_win_paste.bats
git commit -m "$(cat <<'EOF'
feat: parse win-paste --file-* and --format flags

EOF
)"
```

---

### Task 3: Text (and HTML) materialize on PowerShell fallback path

**Files:**
- Modify: `bin/win-paste`
- Modify: `tests/test_win_paste.bats`

**Interfaces:**
- Consumes: `wslutil_clipboard_store`, `wslutil_clipboard_emit`, format helpers
- Produces: `materialize_clipboard_and_emit(mode, format)` working for plain text (and HTML when offered) on the non-WSLg path

- [ ] **Step 1: Write failing materialize tests**

Extend setup mock so PowerShell can answer richer queries. Replace the mock `powershell.exe` with a dispatcher driven by env fixtures:

```bash
# In setup() of test_win_paste.bats — replace mock body with:
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
if [[ "$args" == *Format*Image* ]] || [[ "$args" == *Get-Clipboard*Image* ]]; then
    if [[ -n "${WIN_PASTE_IMAGE_FIXTURE:-}" && -f "${WIN_PASTE_IMAGE_FIXTURE}" ]]; then
        cat "${WIN_PASTE_IMAGE_FIXTURE}"
        exit 0
    fi
    exit 1
fi
# Default: text
cat "${WIN_PASTE_FIXTURE:?}"
EOF
chmod +x "$WIN_WINDIR/System32/WindowsPowerShell/v1.0/powershell.exe"
```

Add tests (force PowerShell path — already `WSL2_GUI_APPS_ENABLED=0`):

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: FAIL on materialize tests (`not implemented` or wrong output)

- [ ] **Step 3: Implement PowerShell text/HTML fetch + materialize**

In `bin/win-paste`, add helpers (names may vary but behavior must match):

```bash
powershell_bin() {
    printf '%s' "${WIN_WINDIR}/System32/WindowsPowerShell/v1.0/powershell.exe"
}

# Returns 0 and writes bytes to $1 when clipboard has plain text
ps_try_text() {
    local out="$1"
    "$(powershell_bin)" -NoProfile -Command \
        '[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; $t=Get-Clipboard -Raw -ErrorAction SilentlyContinue; if($null -eq $t -or $t -eq ""){ exit 1 }; [Console]::Out.Write($t)' \
        >"$out" 2>/dev/null
}

# Returns 0 and writes HTML to $1 when available
ps_try_html() {
    local out="$1"
    "$(powershell_bin)" -NoProfile -Command \
        '$h=Get-Clipboard -TextFormatType Html -ErrorAction SilentlyContinue; if($null -eq $h -or $h -eq ""){ exit 1 }; [Console]::OutputEncoding=[System.Text.Encoding]::UTF8; [Console]::Out.Write($h)' \
        >"$out" 2>/dev/null
}
```

Richness without `--format` on PS path for this task (image comes in Task 4):

```bash
fetch_clipboard_payload() {
    # args: format(optional) → sets globals PAYLOAD_FILE KIND EXT via temp file
    local format="${1:-}" tmp
    tmp="$(mktemp)"
    if [[ -n "$format" ]]; then
        case "$format" in
            txt)
                ps_try_text "$tmp" || { rm -f "$tmp"; echo "win-paste: no text on clipboard" >&2; return 1; }
                # strip CR for stored text (materialize owns encoding; not --raw)
                sed 's/\r$//' "$tmp" >"${tmp}.out" && mv "${tmp}.out" "$tmp"
                PAYLOAD_FILE="$tmp"; KIND=text; EXT=txt; return 0
                ;;
            html)
                ps_try_html "$tmp" || { rm -f "$tmp"; echo "win-paste: no HTML on clipboard" >&2; return 1; }
                PAYLOAD_FILE="$tmp"; KIND=html; EXT=html; return 0
                ;;
            png|jpeg|jpg|gif|webp)
                echo "win-paste: image formats require image clipboard support" >&2
                rm -f "$tmp"
                return 1
                ;;
            *)
                rm -f "$tmp"; return 1
                ;;
        esac
    fi

    # richest: prefer html over text for now; Task 4 inserts image first
    if ps_try_html "$tmp"; then
        PAYLOAD_FILE="$tmp"; KIND=html; EXT=html; return 0
    fi
    if ps_try_text "$tmp"; then
        sed 's/\r$//' "$tmp" >"${tmp}.out" && mv "${tmp}.out" "$tmp"
        PAYLOAD_FILE="$tmp"; KIND=text; EXT=txt; return 0
    fi
    rm -f "$tmp"
    echo "win-paste: clipboard empty or unsupported" >&2
    return 1
}

materialize_clipboard_and_emit() {
    local mode="$1" format="${2:-}" path
    fetch_clipboard_payload "$format" || return 1
    path="$(wslutil_clipboard_store "$PAYLOAD_FILE" "$KIND" "$EXT")" || return 1
    rm -f "$PAYLOAD_FILE"
    wslutil_clipboard_emit "$mode" "$path"
    printf '\n'
}
```

Wire the `FILE_MODE` branch to call this. Ensure `printf '\n'` matches “one line” expectations in BATS (`$output` strips final newline anyway).

For `--format txt` when only HTML exists: either extract with a simple strip later or fail; spec says HTML→txt if straightforward. v1 minimal strip:

```bash
# optional in format=txt path if text probe fails:
ps_try_html "$tmp" && sed -e 's/<[^>]*>//g' ... 
```

Keep first cut strict: `--format txt` requires plain text; add HTML→txt in same task only if tests demand it. Spec lists it — add a small test + `sed`/`python` strip if cheap; otherwise document as follow-up only if extraction is too weak. Prefer a minimal tag-strip for compliance.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add bin/win-paste tests/test_win_paste.bats
git commit -m "$(cat <<'EOF'
feat: materialize clipboard text via win-paste --file-*

EOF
)"
```

---

### Task 4: Image materialize (PowerShell + WSLg) and richest ladder

**Files:**
- Modify: `bin/win-paste`
- Modify: `tests/test_win_paste.bats`

**Interfaces:**
- Consumes: store/emit helpers; existing fetch
- Produces: image → png (DIB/BMP normalized); richest = image → html → text; `--format png` works

- [ ] **Step 1: Write failing image tests**

Use a tiny PNG fixture (binary). Generate in setup:

```bash
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
```

Extend the PowerShell mock so image probes copy `WIN_PASTE_IMAGE_FIXTURE` bytes (already sketched in Task 3). Align `win-paste`’s real PowerShell command strings with what the mock matches (or match mock on a dedicated sentinel env the script sets only in tests — prefer matching real `-Command` substrings).

- [ ] **Step 2: Run test to verify it fails**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: FAIL (text still preferred or image unsupported)

- [ ] **Step 3: Implement PowerShell image save**

Use PowerShell to save clipboard image as PNG to a path passed from bash (convert WSL path with `wslpath -w` when available; in tests, mock can ignore path and stdout the fixture — better: pass output path as env `WIN_PASTE_OUT` for the real command):

Real command sketch:

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$img = [System.Windows.Forms.Clipboard]::GetImage()
if ($img -eq $null) { exit 1 }
$out = $env:WIN_PASTE_OUT
$img.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
```

Bash:

```bash
ps_try_image_png() {
    local out="$1" win_out
    if command -v wslpath >/dev/null 2>&1; then
        win_out="$(wslpath -w "$out")"
    else
        win_out="$out"
    fi
    WIN_PASTE_OUT="$win_out" "$(powershell_bin)" -NoProfile -Command \
        'Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing; $img=[Windows.Forms.Clipboard]::GetImage(); if($null -eq $img){exit 1}; $img.Save($env:WIN_PASTE_OUT,[Drawing.Imaging.ImageFormat]::Png)' \
        2>/dev/null
    [[ -s "$out" ]]
}
```

In tests, mock `powershell.exe` to `cp "$WIN_PASTE_IMAGE_FIXTURE" "$WIN_PASTE_OUT"` when image save is detected (check `$WIN_PASTE_OUT` / args).

Update richest order in `fetch_clipboard_payload`:

1. `ps_try_image_png` → `KIND=image` `EXT=png`
2. html
3. text

`--format png`: require image path; fail if none.

`--format jpeg`/`gif`/`webp`: try native save if easy via `ImageFormat`; else error with clear message (spec: best-effort or clear error). Minimum: support `png` solidly; others may error in v1.

**WSLg path:** when `WSL2_GUI_APPS_ENABLED=1` and `/usr/bin/wl-paste` executable:

```bash
wl_list_types() { /usr/bin/wl-paste -l 2>/dev/null || true; }

wl_try_mime() {
    local mime="$1" out="$2"
    /usr/bin/wl-paste -n -t "$mime" >"$out" 2>/dev/null && [[ -s "$out" ]]
}
```

Richness: if types contain `image/png` (or jpeg/gif/webp), fetch that MIME; DIB-like types → prefer `image/png` if listed else fetch and still store as png only if bytes are png (or convert — v1: require `image/png` offer). HTML `text/html`, then `text/plain`.

Keep WSLg + PS behavior aligned on ladder.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_win_paste.bats`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add bin/win-paste tests/test_win_paste.bats
git commit -m "$(cat <<'EOF'
feat: materialize clipboard images in win-paste --file-*

EOF
)"
```

---

### Task 5: Docs touch-up

**Files:**
- Modify: `README.md` (clipboard section)
- Modify: `bin/win-paste` help only if any wording gaps remain after Tasks 2–4

- [ ] **Step 1: Add a short README example**

Near existing `win-paste` docs:

```markdown
# Materialize clipboard for agents (image or large text)
win-paste --file-atpath            # → @/home/.../clip-...-image-....png
win-paste --file-url --format png  # → file:///.../clip-....png
```

- [ ] **Step 2: Run full paste-related tests**

Run: `./tests/run_tests.sh test_win_paste.bats test_clipboard_file.bats`

Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add README.md bin/win-paste
git commit -m "$(cat <<'EOF'
docs: document win-paste --file-* materialize flags

EOF
)"
```

---

## Spec coverage check

| Spec item | Task |
|-----------|------|
| `--file-url` / `--file-path` / `--file-atpath` mutually exclusive | 2 |
| Always materialize | 3 |
| Richest image → html → text | 4 (html/text in 3, image first in 4) |
| `--format` short names | 2 (parse), 3–4 (apply) |
| Cache dir / modes / filename / localtime / 12-hex | 1 |
| Dedup by kind+shortsum+ext | 1, 3 |
| `--raw` conflict | 2 |
| DIB/BMP → png | 4 (PS `GetImage`→PNG) |
| Plain text → html error | 3 |
| WSLg + PowerShell backends | 4 |
| Default text paste unchanged | 2–3 (existing tests) |
| BATS cases listed in spec | 1–4 |
| No HDROP / no GC | n/a (non-goals) |

## Placeholder / consistency notes

- Emit mode names are consistently `url` | `path` | `atpath` across helper and CLI.
- Kind/ext always describe **written** bytes after conversion.
- Test doubles must track the real PowerShell command shape used in `bin/win-paste`.
