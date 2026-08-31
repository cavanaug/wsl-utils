# `wslutil list` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add read-only `wslutil list` (`bin/wslutil-list`) that prints a table of every distro `wsl.exe -l -v` reports, with running type/hostname and opt-in `--location`.

**Architecture:** Pure parse/format helpers live in `lib/wslutil-list.sh` so BATS can source them without Windows. `bin/wslutil-list` parses flags, collects rows (injectable command names and `WSLUTIL_LIST_FILE_ROOT` / `WSLUTIL_LIST_LXSS`), prints a human table or `yq eval -o json`. File reads only — never `wsl.exe -d` and never `wsl --mount`. Do not source `lib/wslutil-info.sh`.

**Tech Stack:** Bash, BATS, crudini (optional for `wsl.conf` hostname), mikefarah `yq eval`, `win-utf8`, `wslpath`, PowerShell `-NoProfile`

**Spec:** `docs/superpowers/specs/2026-08-30-wslutil-list-design.md`

## Global Constraints

- Public name is `wslutil list` only (binary `wslutil-list`).
- Stdout is only the table or JSON. Usage / empty inventory / missing `yq`+`--json` go to stderr, exit 1.
- Partial field failure → cell `-` / JSON `null`. Exit 0.
- Never `wsl.exe -d NAME`. Never `wsl.exe --mount`.
- `--json` requires `yq`; human mode does not. Missing `yq` + `--json` → exit 1.
- `--location` is the only trigger for the Lxss/PowerShell query.
- PowerShell calls use `-NoProfile`.
- `wsl.exe` output goes through `win-utf8`.
- Do not source or call `lib/wslutil-info.sh` / `wslutil-info`.
- Do not change `wslutil doctor` or `wslutil info` behavior.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-list.sh` | Parse `-l -v`, PRETTY_NAME, hostname format, file resolve, collect, human + JSON emit |
| `bin/wslutil-list` | CLI (`--json`, `--location`, `--help`), source lib, exit codes |
| `bin/wslutil` | List `list` in usage / `--help`; exclude it from Extra Subcommands |
| `Makefile` | Install `wslutil-list` + `lib/wslutil-list.sh` |
| `tests/test_wslutil_list.bats` | Unit + CLI tests with fake `wsl.exe` / file root / Lxss TSV |
| `tests/test_make_install.bats` | Assert installed binary + lib |
| `README.md` | One row + one example for `wslutil list` |

Internal row TSV (tab-separated, 8 fields):

`name<TAB>state<TAB>version<TAB>default<TAB>type<TAB>hostname<TAB>hostnameConfigured<TAB>location`

- `default` is `yes` or `no`
- `version` is `1`, `2`, or empty
- empty `type` / `hostname` / `hostnameConfigured` / `location` means dash/null
- `hostnameConfigured` is set only when it differs from live

Globals: `LIST_ROWS=()`, `LIST_WANT_LOCATION=0`, `LIST_WANT_JSON=0`

---

### Task 1: Parse `-l -v`, PRETTY_NAME, hostname format

**Files:**
- Create: `lib/wslutil-list.sh`
- Create: `tests/test_wslutil_list.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `wslutil_list_parse_distro_list` — stdin `wsl.exe -l -v` text; stdout lines `name<TAB>state<TAB>version<TAB>default` (`default` is `yes`/`no`)
  - `wslutil_list_pretty_name file` — stdout `PRETTY_NAME`; exit 1 if missing/unreadable
  - `wslutil_list_format_hostname live configured` — stdout human hostname cell (`-`, `live`, or `live (configured)`)
  - `wslutil_list_hostname_configured_value live configured` — stdout override if it differs after trim, else empty

- [ ] **Step 1: Write failing tests**

Create `tests/test_wslutil_list.bats`:

```bash
#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/wslutil-list.sh"
}

teardown() {
    cleanup_test_env
}

@test "parse -l -v: default star, spaces in name, WSL 1 and 2" {
    run wslutil_list_parse_distro_list <<'EOF'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  Debian    Stopped         2
  OldBox    Stopped         1
  Ubuntu 22.04    Running         2
EOF
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t'"Running"$'\t'"2"$'\t'"yes"* ]]
    [[ "$output" == *"Debian"$'\t'"Stopped"$'\t'"2"$'\t'"no"* ]]
    [[ "$output" == *"OldBox"$'\t'"Stopped"$'\t'"1"$'\t'"no"* ]]
    [[ "$output" == *"Ubuntu 22.04"$'\t'"Running"$'\t'"2"$'\t'"no"* ]]
}

@test "pretty_name quoted and unquoted" {
    local f="$TEST_TEMP_DIR/os-release"
    printf 'PRETTY_NAME="Ubuntu 24.04.2 LTS"\n' >"$f"
    run wslutil_list_pretty_name "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "Ubuntu 24.04.2 LTS" ]
    printf 'PRETTY_NAME=Alpine\n' >"$f"
    run wslutil_list_pretty_name "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "Alpine" ]
}

@test "pretty_name missing file exits 1" {
    run wslutil_list_pretty_name "$TEST_TEMP_DIR/nope"
    [ "$status" -eq 1 ]
}

@test "format_hostname same vs differ vs empty" {
    run wslutil_list_format_hostname "mybox" ""
    [ "$output" = "mybox" ]
    run wslutil_list_format_hostname "mybox" "mybox"
    [ "$output" = "mybox" ]
    run wslutil_list_format_hostname "alpine" "devbox"
    [ "$output" = "alpine (devbox)" ]
    run wslutil_list_format_hostname "" ""
    [ "$output" = "-" ]
}

@test "hostname_configured_value only when different" {
    run wslutil_list_hostname_configured_value "alpine" "devbox"
    [ "$output" = "devbox" ]
    run wslutil_list_hostname_configured_value "mybox" "mybox"
    [ -z "$output" ]
    run wslutil_list_hostname_configured_value "mybox" ""
    [ -z "$output" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: FAIL — `lib/wslutil-list.sh` not found, or functions not defined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/wslutil-list.sh`:

```bash
#!/usr/bin/env bash
# wslutil-list helpers — sourced by bin/wslutil-list and BATS. Not wslutil-info.

wslutil_list_parse_distro_list() {
    awk '
        BEGIN { IGNORECASE=1 }
        NR==1 && /NAME/ { next }
        NF==0 { next }
        {
            def="no"
            if ($1=="*") { def="yes"; $1=""; sub(/^ +/, "") }
            if (NF<2) next
            ver=$NF
            state=$(NF-1)
            name=$1
            for (i=2; i<=NF-2; i++) name=name " " $i
            gsub(/\r/, "", name)
            gsub(/\r/, "", state)
            gsub(/\r/, "", ver)
            print name "\t" state "\t" ver "\t" def
        }'
}

wslutil_list_pretty_name() {
    local f="$1" line val
    [[ -f "$f" ]] || return 1
    line="$(grep -E '^PRETTY_NAME=' "$f" | tail -n1)" || return 1
    [[ -n "$line" ]] || return 1
    val="${line#PRETTY_NAME=}"
    val="${val%$'\r'}"
    if [[ "$val" == \"*\" ]]; then
        val="${val#\"}"
        val="${val%\"}"
    elif [[ "$val" == \'*\' ]]; then
        val="${val#\'}"
        val="${val%\'}"
    fi
    [[ -n "$val" ]] || return 1
    printf '%s\n' "$val"
}

wslutil_list_trim() {
    local s="$1"
    s="${s//$'\r'/}"
    s="${s//$'\n'/}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

wslutil_list_format_hostname() {
    local live configured
    live="$(wslutil_list_trim "${1:-}")"
    configured="$(wslutil_list_trim "${2:-}")"
    if [[ -z "$live" ]]; then
        printf '%s\n' "-"
        return 0
    fi
    if [[ -n "$configured" && "$configured" != "$live" ]]; then
        printf '%s (%s)\n' "$live" "$configured"
    else
        printf '%s\n' "$live"
    fi
}

wslutil_list_hostname_configured_value() {
    local live configured
    live="$(wslutil_list_trim "${1:-}")"
    configured="$(wslutil_list_trim "${2:-}")"
    if [[ -n "$configured" && "$configured" != "$live" ]]; then
        printf '%s\n' "$configured"
    fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: PASS (all Task 1 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-list.sh tests/test_wslutil_list.bats
git commit -m "$(cat <<'EOF'
feat: parse wsl list table, os-release, and hostname cells

EOF
)"
```

---

### Task 2: CLI, collect rows, human table

**Files:**
- Modify: `lib/wslutil-list.sh`
- Create: `bin/wslutil-list`
- Modify: `tests/test_wslutil_list.bats`

**Interfaces:**
- Consumes: Task 1 functions
- Produces:
  - `wslutil_list_cmd_wsl` / `wslutil_list_cmd_win_utf8` / `wslutil_list_cmd_wslpath` / `wslutil_list_cmd_powershell` — stdout command name (overridable via `WSLUTIL_LIST_WSL`, `WSLUTIL_LIST_WIN_UTF8`, `WSLUTIL_LIST_WSLPATH`, `WSLUTIL_LIST_POWERSHELL`)
  - `wslutil_list_resolve_file name rel` — stdout filesystem path. If `WSLUTIL_LIST_FILE_ROOT` is set: `$WSLUTIL_LIST_FILE_ROOT/$name/$rel`. Else if `name` equals `$WSL_DISTRO_NAME`: `/$rel`. Else `wslpath -u` on `\\wsl.localhost\name\rel`, fallback `/mnt/wsl.localhost/name/rel`.
  - `wslutil_list_read_line file` — first line of file, trimmed; empty if unreadable
  - `wslutil_list_wslconf_hostname file` — `crudini --get file network hostname` or empty
  - `wslutil_list_collect` — fills `LIST_ROWS` from `wsl.exe -l -v`. Exit 1 if no rows. For `state==Running`, fills type/hostname from files. Never calls `wsl.exe -d`. Does not query Lxss unless `LIST_WANT_LOCATION=1` (Task 4 implements that query; this task leaves location empty).
  - `wslutil_list_print_human` — prints aligned table from `LIST_ROWS` (`LOCATION` column iff `LIST_WANT_LOCATION=1`)
  - `bin/wslutil-list` — `--help` exit 0; unknown flag exit 1; default human table

- [ ] **Step 1: Write failing CLI / collect tests**

Append to `tests/test_wslutil_list.bats` (keep Task 1 tests). Add helpers + tests:

```bash
make_list_fakebin() {
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"${WSLUTIL_LIST_WSL_LOG:-/tmp/wsl-argv.log}"
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    cat <<'LST'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  debian    Stopped         2
  alpine    Running         2
LST
    exit 0
fi
echo "unexpected: $*" >&2
exit 1
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WIN_UTF8="cat"
    export WSLUTIL_LIST_WSL_LOG="$TEST_TEMP_DIR/wsl-argv.log"
    : >"$WSLUTIL_LIST_WSL_LOG"
}

seed_file_root() {
    export WSLUTIL_LIST_FILE_ROOT="$TEST_TEMP_DIR/fs"
    mkdir -p "$WSLUTIL_LIST_FILE_ROOT/Ubuntu/etc" \
        "$WSLUTIL_LIST_FILE_ROOT/Ubuntu/proc/sys/kernel" \
        "$WSLUTIL_LIST_FILE_ROOT/alpine/etc" \
        "$WSLUTIL_LIST_FILE_ROOT/alpine/proc/sys/kernel"
    printf 'PRETTY_NAME="Ubuntu 24.04.2 LTS"\n' >"$WSLUTIL_LIST_FILE_ROOT/Ubuntu/etc/os-release"
    printf 'mybox\n' >"$WSLUTIL_LIST_FILE_ROOT/Ubuntu/proc/sys/kernel/hostname"
    printf 'PRETTY_NAME="Alpine Linux v3.20"\n' >"$WSLUTIL_LIST_FILE_ROOT/alpine/etc/os-release"
    printf 'alpine\n' >"$WSLUTIL_LIST_FILE_ROOT/alpine/proc/sys/kernel/hostname"
    cat >"$WSLUTIL_LIST_FILE_ROOT/alpine/etc/wsl.conf" <<'EOF'
[network]
hostname=devbox
EOF
}

@test "resolve_file uses FILE_ROOT and current distro slash path" {
    export WSLUTIL_LIST_FILE_ROOT="$TEST_TEMP_DIR/fs"
    run wslutil_list_resolve_file Ubuntu etc/os-release
    [ "$output" = "$TEST_TEMP_DIR/fs/Ubuntu/etc/os-release" ]
    unset WSLUTIL_LIST_FILE_ROOT
    export WSL_DISTRO_NAME=Ubuntu
    run wslutil_list_resolve_file Ubuntu etc/os-release
    [ "$output" = "/etc/os-release" ]
}

@test "wslutil-list --help exits 0 and mentions --json and --location" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--json" ]]
    [[ "$output" =~ "--location" ]]
}

@test "wslutil-list unknown flag exits 1" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --bogus
    [ "$status" -eq 1 ]
}

@test "human table: running type/hostname, stopped dashes, never -d" {
    make_list_fakebin
    seed_file_root
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 0 ]
    [[ "$output" =~ NAME ]]
    [[ "$output" =~ Ubuntu ]]
    [[ "$output" =~ "Ubuntu 24.04.2 LTS" ]]
    [[ "$output" =~ mybox ]]
    [[ "$output" =~ debian ]]
    [[ "$output" =~ alpine ]]
    [[ "$output" =~ "Alpine Linux v3.20" ]]
    [[ "$output" =~ "alpine (devbox)" ]]
    [[ "$output" != *LOCATION* ]]
    if grep -E -- '-d' "$WSLUTIL_LIST_WSL_LOG"; then
        echo "wsl.exe -d was invoked" >&2
        cat "$WSLUTIL_LIST_WSL_LOG" >&2
        return 1
    fi
}

@test "empty distro list exits 1" {
    FAKEBIN="$TEST_TEMP_DIR/emptybin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
echo "  NAME      STATE           VERSION"
exit 0
EOF
    chmod +x "$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_LIST_WIN_UTF8="cat"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: FAIL — `bin/wslutil-list` missing and/or collect/print not defined.

- [ ] **Step 3: Implement collect, human print, and CLI**

Append to `lib/wslutil-list.sh`:

```bash
LIST_ROWS=()
LIST_WANT_LOCATION=0
LIST_WANT_JSON=0

wslutil_list_cmd_wsl() { echo "${WSLUTIL_LIST_WSL:-wsl.exe}"; }
wslutil_list_cmd_win_utf8() {
    if [[ -n "${WSLUTIL_LIST_WIN_UTF8:-}" ]]; then
        echo "$WSLUTIL_LIST_WIN_UTF8"
        return
    fi
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "$here/../bin/win-utf8" ]]; then
        echo "$here/../bin/win-utf8"
    else
        echo "win-utf8"
    fi
}
wslutil_list_cmd_wslpath() { echo "${WSLUTIL_LIST_WSLPATH:-wslpath}"; }
wslutil_list_cmd_powershell() { echo "${WSLUTIL_LIST_POWERSHELL:-powershell.exe}"; }

wslutil_list_resolve_file() {
    local name="$1" rel="$2"
    if [[ -n "${WSLUTIL_LIST_FILE_ROOT:-}" ]]; then
        printf '%s\n' "${WSLUTIL_LIST_FILE_ROOT}/${name}/${rel}"
        return 0
    fi
    if [[ -n "${WSL_DISTRO_NAME:-}" && "$name" == "$WSL_DISTRO_NAME" ]]; then
        printf '/%s\n' "$rel"
        return 0
    fi
    local wp unc wslp
    wp="$(wslutil_list_cmd_wslpath)"
    unc="\\\\wsl.localhost\\${name}\\${rel//\//\\}"
    wslp="$("$wp" -u "$unc" 2>/dev/null || true)"
    if [[ -n "$wslp" && -e "$wslp" ]]; then
        printf '%s\n' "$wslp"
        return 0
    fi
    printf '/mnt/wsl.localhost/%s/%s\n' "$name" "$rel"
}

wslutil_list_read_line() {
    local f="$1" line
    [[ -f "$f" && -r "$f" ]] || return 0
    IFS= read -r line <"$f" || true
    wslutil_list_trim "$line"
    printf '\n'
}

wslutil_list_wslconf_hostname() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    crudini --get "$f" network hostname 2>/dev/null || true
}

wslutil_list_lxss_map() {
    # Task 4 fills this. Default: no output.
    if [[ -n "${WSLUTIL_LIST_LXSS:-}" && -f "$WSLUTIL_LIST_LXSS" ]]; then
        cat "$WSLUTIL_LIST_LXSS"
        return 0
    fi
    return 0
}

wslutil_list_collect() {
    LIST_ROWS=()
    local ws u8 raw line name state ver def typ host hconf loc
    ws="$(wslutil_list_cmd_wsl)"
    u8="$(wslutil_list_cmd_win_utf8)"
    if ! raw="$("$ws" -l -v 2>/dev/null | "$u8" 2>/dev/null)"; then
        echo "wslutil-list: failed to list distros" >&2
        return 1
    fi
    local parsed
    parsed="$(printf '%s\n' "$raw" | wslutil_list_parse_distro_list)"
    if [[ -z "$parsed" ]]; then
        echo "wslutil-list: no distros found" >&2
        return 1
    fi
    declare -A lxss=()
    if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
        while IFS=$'\t' read -r n b; do
            [[ -n "$n" ]] || continue
            b="${b#\\\\?\\}"
            lxss["$n"]="$b"
        done < <(wslutil_list_lxss_map)
    fi
    while IFS=$'\t' read -r name state ver def; do
        [[ -n "$name" ]] || continue
        typ=""
        host=""
        hconf=""
        loc=""
        if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
            loc="${lxss[$name]:-}"
        fi
        if [[ "$state" == "Running" ]]; then
            typ="$(wslutil_list_pretty_name "$(wslutil_list_resolve_file "$name" etc/os-release)" 2>/dev/null || true)"
            host="$(wslutil_list_read_line "$(wslutil_list_resolve_file "$name" proc/sys/kernel/hostname)")"
            hconf="$(wslutil_list_wslconf_hostname "$(wslutil_list_resolve_file "$name" etc/wsl.conf)")"
            hconf="$(wslutil_list_hostname_configured_value "$host" "$hconf")"
        fi
        LIST_ROWS+=("${name}"$'\t'"${state}"$'\t'"${ver}"$'\t'"${def}"$'\t'"${typ}"$'\t'"${host}"$'\t'"${hconf}"$'\t'"${loc}")
    done <<<"$parsed"
    [[ ${#LIST_ROWS[@]} -gt 0 ]] || {
        echo "wslutil-list: no distros found" >&2
        return 1
    }
}

wslutil_list_dash() {
    if [[ -n "$1" ]]; then printf '%s' "$1"; else printf '%s' "-"; fi
}

wslutil_list_print_human() {
    local row name state ver def typ host hconf loc star
    local -a stars names states vers types hosts locs
    local w_name=4 w_state=5 w_ver=3 w_type=4 w_host=8 w_loc=8
    stars=(); names=(); states=(); vers=(); types=(); hosts=(); locs=()
    for row in "${LIST_ROWS[@]}"; do
        IFS=$'\t' read -r name state ver def typ host hconf loc <<<"$row"
        star=" "
        [[ "$def" == "yes" ]] && star="*"
        [[ "$ver" =~ ^[12]$ ]] || ver="-"
        typ="$(wslutil_list_dash "$typ")"
        if [[ -n "$host" ]]; then
            host="$(wslutil_list_format_hostname "$host" "$hconf")"
        else
            host="-"
        fi
        loc="$(wslutil_list_dash "$loc")"
        stars+=("$star")
        names+=("$name")
        states+=("$state")
        vers+=("$ver")
        types+=("$typ")
        hosts+=("$host")
        locs+=("$loc")
        (( ${#name} > w_name )) && w_name=${#name}
        (( ${#state} > w_state )) && w_state=${#state}
        (( ${#ver} > w_ver )) && w_ver=${#ver}
        (( ${#typ} > w_type )) && w_type=${#typ}
        (( ${#host} > w_host )) && w_host=${#host}
        (( ${#loc} > w_loc )) && w_loc=${#loc}
    done
    if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
        printf '%s %-*s  %-*s  %-*s  %-*s  %-*s  %s\n' " " "$w_name" "NAME" "$w_state" "STATE" "$w_ver" "WSL" "$w_type" "TYPE" "$w_host" "HOSTNAME" "LOCATION"
        local i
        for i in "${!names[@]}"; do
            printf '%s %-*s  %-*s  %-*s  %-*s  %-*s  %s\n' "${stars[$i]}" "$w_name" "${names[$i]}" "$w_state" "${states[$i]}" "$w_ver" "${vers[$i]}" "$w_type" "${types[$i]}" "$w_host" "${hosts[$i]}" "${locs[$i]}"
        done
    else
        printf '%s %-*s  %-*s  %-*s  %-*s  %s\n' " " "$w_name" "NAME" "$w_state" "STATE" "$w_ver" "WSL" "$w_type" "TYPE" "HOSTNAME"
        local i
        for i in "${!names[@]}"; do
            printf '%s %-*s  %-*s  %-*s  %-*s  %s\n' "${stars[$i]}" "$w_name" "${names[$i]}" "$w_state" "${states[$i]}" "$w_ver" "${vers[$i]}" "$w_type" "${types[$i]}" "${hosts[$i]}"
        done
    fi
}
```

Create `bin/wslutil-list`:

```bash
#!/usr/bin/bash
# wslutil-list - Table of registered WSL distros
set -euo pipefail

_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_wsu_bin/../lib/wslutil-list.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../lib/wslutil-list.sh"
elif [[ -f "$_wsu_bin/../share/wslutil/lib/wslutil-list.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../share/wslutil/lib/wslutil-list.sh"
else
    echo "wslutil-list: lib not found" >&2
    exit 1
fi

show_help() {
    cat <<EOF
Usage: wslutil-list [--json] [--location]

Table of all registered WSL distros (read-only; never starts a distro).

Options:
  --json       Machine-readable JSON on stdout
  --location   Include Windows BasePath folder
  --help       Show this help and exit
EOF
}

LIST_WANT_JSON=0
LIST_WANT_LOCATION=0
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --json)
        LIST_WANT_JSON=1
        shift
        ;;
    --location)
        LIST_WANT_LOCATION=1
        shift
        ;;
    *)
        echo "wslutil-list: unknown option: $1" >&2
        show_help >&2
        exit 1
        ;;
    esac
done

if [[ "$LIST_WANT_JSON" -eq 1 ]] && ! command -v yq >/dev/null 2>&1; then
    echo "wslutil-list: --json requires yq" >&2
    exit 1
fi

wslutil_list_collect
if [[ "$LIST_WANT_JSON" -eq 1 ]]; then
    wslutil_list_print_json
else
    wslutil_list_print_human
fi
```

`chmod +x bin/wslutil-list`

`wslutil_list_print_json` is called from the CLI when `--json` is set. Add a stub that fails loudly so Task 2 human tests still pass when `--json` is unused:

```bash
wslutil_list_print_json() {
    echo "wslutil-list: JSON not implemented" >&2
    return 1
}
```

Put that stub in `lib/wslutil-list.sh` in this task. Task 3 replaces it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: PASS. If alpine hostname test fails because crudini is missing, the test already `skip`s. If `alpine (devbox)` fails because `wsl.conf` is unread, fix `wslutil_list_wslconf_hostname` (must use the resolved path).

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-list.sh bin/wslutil-list tests/test_wslutil_list.bats
git commit -m "$(cat <<'EOF'
feat: add wslutil list human table of distros

EOF
)"
```

---

### Task 3: `--json`

**Files:**
- Modify: `lib/wslutil-list.sh` (`wslutil_list_print_json`)
- Modify: `tests/test_wslutil_list.bats`

**Interfaces:**
- Consumes: `LIST_ROWS`, `LIST_WANT_LOCATION`
- Produces: `wslutil_list_print_json` — JSON array on stdout via `yq eval -o json`. Keys: `name`, `default`, `state`, `wslVersion` (number or `null`), `type`, `hostname`, `hostnameConfigured`. `location` key **only** when `LIST_WANT_LOCATION=1`. Empty strings → `null`. `hostnameConfigured` already stored only when different.

- [ ] **Step 1: Write failing JSON tests**

Append:

```bash
@test "--json is an array with type and hostnameConfigured" {
    make_list_fakebin
    seed_file_root
    command -v yq >/dev/null 2>&1 || skip "need yq"
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.[0].name' -)" = "Ubuntu" ]
    [ "$(echo "$output" | yq eval '.[0].default' -)" = "true" ]
    [ "$(echo "$output" | yq eval '.[0].state' -)" = "Running" ]
    [ "$(echo "$output" | yq eval '.[0].wslVersion' -)" = "2" ]
    [ "$(echo "$output" | yq eval '.[0].type' -)" = "Ubuntu 24.04.2 LTS" ]
    [ "$(echo "$output" | yq eval '.[0].hostname' -)" = "mybox" ]
    [ "$(echo "$output" | yq eval '.[0].hostnameConfigured' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[0] | has("location")' -)" = "false" ]
    [ "$(echo "$output" | yq eval '.[1].name' -)" = "debian" ]
    [ "$(echo "$output" | yq eval '.[1].type' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[1].hostname' -)" = "null" ]
    [ "$(echo "$output" | yq eval '.[2].hostname' -)" = "alpine" ]
    [ "$(echo "$output" | yq eval '.[2].hostnameConfigured' -)" = "devbox" ]
}

@test "--json without yq exits 1" {
    make_list_fakebin
    seed_file_root
    local hide="$TEST_TEMP_DIR/hide"
    mkdir -p "$hide"
    run env PATH="$hide:$FAKEBIN:/bin:/usr/bin" WSLUTIL_LIST_WSL="$FAKEBIN/wsl.exe" \
        WSLUTIL_LIST_WIN_UTF8="cat" WSLUTIL_LIST_FILE_ROOT="$WSLUTIL_LIST_FILE_ROOT" \
        "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json
    [ "$status" -eq 1 ]
    [[ "$output" =~ yq ]]
}
```

The missing-`yq` test must not inherit a PATH that still has `yq`. `hide` has no `yq`. Keep `cat` and bash on PATH (`/bin` `/usr/bin`). `WSLUTIL_LIST_WSL` is an absolute path so `wsl.exe` still runs.

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: FAIL — stub prints `JSON not implemented` or non-JSON.

- [ ] **Step 3: Replace the JSON stub**

Replace `wslutil_list_print_json` in `lib/wslutil-list.sh` with:

```bash
wslutil_list_print_json() {
    local tmp row name state ver def typ host hconf loc
    tmp="$(mktemp)"
    : >"$tmp"
    for row in "${LIST_ROWS[@]}"; do
        IFS=$'\t' read -r name state ver def typ host hconf loc <<<"$row"
        export _ln="$name" _ls="$state" _lv="$ver" _ld="$def" _lt="$typ" _lh="$host" _lc="$hconf" _ll="$loc"
        if [[ "$LIST_WANT_LOCATION" -eq 1 ]]; then
            yq eval -n '{
                name: strenv(_ln),
                default: (strenv(_ld) == "yes"),
                state: strenv(_ls),
                wslVersion: (strenv(_lv) | select(. == "1" or . == "2") | tonumber // null),
                type: (strenv(_lt) | select(length > 0) // null),
                hostname: (strenv(_lh) | select(length > 0) // null),
                hostnameConfigured: (strenv(_lc) | select(length > 0) // null),
                location: (strenv(_ll) | select(length > 0) // null)
            }' >>"$tmp"
        else
            yq eval -n '{
                name: strenv(_ln),
                default: (strenv(_ld) == "yes"),
                state: strenv(_ls),
                wslVersion: (strenv(_lv) | select(. == "1" or . == "2") | tonumber // null),
                type: (strenv(_lt) | select(length > 0) // null),
                hostname: (strenv(_lh) | select(length > 0) // null),
                hostnameConfigured: (strenv(_lc) | select(length > 0) // null)
            }' >>"$tmp"
        fi
        printf '\n' >>"$tmp"
    done
    yq eval -s '.' -o json "$tmp"
    rm -f "$tmp"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-list.sh tests/test_wslutil_list.bats
git commit -m "$(cat <<'EOF'
feat: emit wslutil list JSON array

EOF
)"
```

---

### Task 4: `--location`

**Files:**
- Modify: `lib/wslutil-list.sh` (`wslutil_list_lxss_map`)
- Modify: `tests/test_wslutil_list.bats`

**Interfaces:**
- Consumes: `LIST_WANT_LOCATION`, `WSLUTIL_LIST_LXSS` (fixture TSV `name<TAB>BasePath`), else one PowerShell `-NoProfile` query
- Produces: `wslutil_list_lxss_map` — stdout `name<TAB>BasePath` lines. Strip `\\?\` prefix from BasePath. Without `--location`, this function is not used (collect already gates on the flag). Fake `powershell.exe` must not run when the flag is off.

PowerShell command (single pass, `-NoProfile`):

```powershell
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | ForEach-Object { $n = $_.GetValue('DistributionName'); if ($n) { $n + [char]9 + $_.GetValue('BasePath') } }
```

Pipe through `win-utf8`. If `powershell.exe` is missing or the command fails, emit no rows (cells `-` / `null`, exit 0).

- [ ] **Step 1: Write failing location tests**

Append:

```bash
@test "--location adds column and JSON key; off skips powershell" {
    make_list_fakebin
    seed_file_root
    command -v yq >/dev/null 2>&1 || skip "need yq"
    export WSLUTIL_LIST_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\Ubuntu\n' >"$WSLUTIL_LIST_LXSS"
    printf 'debian\tC:\\Users\\foo\\debian\n' >>"$WSLUTIL_LIST_LXSS"
    local ps="$FAKEBIN/powershell.exe"
    cat >"$ps" <<'EOF'
#!/bin/bash
echo invoked >>"${WSLUTIL_LIST_PS_LOG}"
exit 1
EOF
    chmod +x "$ps"
    export WSLUTIL_LIST_POWERSHELL="$ps"
    export WSLUTIL_LIST_PS_LOG="$TEST_TEMP_DIR/ps.log"
    : >"$WSLUTIL_LIST_PS_LOG"

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list"
    [ "$status" -eq 0 ]
    [[ "$output" != *LOCATION* ]]
    [[ ! -s "$WSLUTIL_LIST_PS_LOG" ]]

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --location
    [ "$status" -eq 0 ]
    [[ "$output" =~ LOCATION ]]
    [[ "$output" =~ "C:\\Users\\foo\\Ubuntu" ]]
    [[ ! -s "$WSLUTIL_LIST_PS_LOG" ]]

    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --json --location
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | yq eval '.[0].location' -)" = 'C:\Users\foo\Ubuntu' ]
    [ "$(echo "$output" | yq eval '.[1].location' -)" = 'C:\Users\foo\debian' ]
    [ "$(echo "$output" | yq eval '.[2].location' -)" = "null" ]
}

@test "--location with no map still prints table" {
    make_list_fakebin
    seed_file_root
    unset WSLUTIL_LIST_LXSS
    export WSLUTIL_LIST_POWERSHELL="$TEST_TEMP_DIR/missing-ps"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-list" --location
    [ "$status" -eq 0 ]
    [[ "$output" =~ LOCATION ]]
    [[ "$output" =~ Ubuntu ]]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: FAIL — location cells empty / no PowerShell implementation / JSON missing `location`.

- [ ] **Step 3: Implement `wslutil_list_lxss_map`**

Replace the Task 2 stub `wslutil_list_lxss_map` with:

```bash
wslutil_list_lxss_map() {
    if [[ -n "${WSLUTIL_LIST_LXSS:-}" && -f "$WSLUTIL_LIST_LXSS" ]]; then
        cat "$WSLUTIL_LIST_LXSS"
        return 0
    fi
    local ps u8 out
    ps="$(wslutil_list_cmd_powershell)"
    command -v "$ps" >/dev/null 2>&1 || return 0
    u8="$(wslutil_list_cmd_win_utf8)"
    out="$("$ps" -NoProfile -Command "Get-ChildItem HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Lxss | ForEach-Object { \$n = \$_.GetValue('DistributionName'); if (\$n) { \$n + [char]9 + \$_.GetValue('BasePath') } }" 2>/dev/null | "$u8" || true)"
    printf '%s\n' "$out"
}
```

Collect already strips `\\?\` and fills `loc` when `LIST_WANT_LOCATION=1`. Human/JSON already honor the flag.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-list.sh tests/test_wslutil_list.bats
git commit -m "$(cat <<'EOF'
feat: add --location BasePath column to wslutil list

EOF
)"
```

---

### Task 5: Dispatcher, Makefile, README, install test

**Files:**
- Modify: `bin/wslutil` (usage on empty args, `--help` subcommand list, extras grep, command-not-found usage)
- Modify: `Makefile` (`CORE_SCRIPTS` + `install` of `lib/wslutil-list.sh`)
- Modify: `tests/test_make_install.bats`
- Modify: `README.md`
- Modify: `tests/test_wslutil_list.bats` (dispatcher `--help`)

**Interfaces:**
- Consumes: `bin/wslutil-list` on PATH next to `bin/wslutil`
- Produces: `wslutil list` dispatches; `list` is a first-class subcommand in help, not Extra Subcommands; prefix install includes binary + lib

- [ ] **Step 1: Write failing dispatcher / install tests**

Append to `tests/test_wslutil_list.bats`:

```bash
@test "wslutil list --help dispatches" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil" list --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--json" ]]
}

@test "wslutil --help lists list as a core subcommand" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ list ]]
}
```

In `tests/test_make_install.bats`, add next to the `wslutil-info` asserts:

```bash
    [ -x "$PREFIX/bin/wslutil-list" ]
    [ -f "$PREFIX/share/wslutil/lib/wslutil-list.sh" ]
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./tests/run_tests.sh test_wslutil_list.bats` and `./tests/run_tests.sh test_make_install.bats`

Expected: dispatcher help may already run `wslutil-list` via local bin (that test can pass). `--help` text and `make install` should FAIL until Makefile / usage strings change.

- [ ] **Step 3: Wire dispatcher, Makefile, README**

`bin/wslutil`:

- Empty-args usage: `{doctor|info|list|shellenv|setup|upgrade}`
- Command-not-found usage: same set
- `--help` add after the `info` line:

```text
  list       List registered WSL distros (type, hostname; --location)
```

- Extras grep: `grep -E -v '(doctor|info|list|shellenv|setup|upgrade)'`

`Makefile`:

- Add `wslutil-list` to `CORE_SCRIPTS` next to `wslutil-info`
- After the `wslutil-info.sh` install line:

```make
	install -m 0644 lib/wslutil-list.sh $(DATADIR)/lib/wslutil-list.sh
```

`README.md` command table, after `wslutil info`:

```markdown
| `wslutil list` | List distros with state, OS pretty name, hostname; `--location` for BasePath |
```

Usage examples:

```bash
wslutil list                      # All distros
wslutil list --location           # Include Windows BasePath folder
wslutil list --json               # Same rows as JSON
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `./tests/run_tests.sh test_wslutil_list.bats`

Run: `./tests/run_tests.sh test_make_install.bats`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add bin/wslutil Makefile tests/test_make_install.bats tests/test_wslutil_list.bats README.md
git commit -m "$(cat <<'EOF'
feat: install and document wslutil list

EOF
)"
```

---

## Self-review (spec coverage)

| Spec requirement | Task |
|------------------|------|
| `wslutil list` / `wslutil-list`, `--json`, `--location`, `--help` | 2, 3, 4 |
| Table columns NAME/STATE/WSL/TYPE/HOSTNAME, `*` default | 1, 2 |
| TYPE = `PRETTY_NAME`, running only | 1, 2 |
| Live hostname + `(configured)` when `wsl.conf` differs | 1, 2 |
| Stopped → `-` / `null`; never `-d` / `--mount` | 2 |
| `--location` = Windows `BasePath` folder; no query unless flag | 4 |
| JSON same rows; `location` key only with flag; `hostnameConfigured` | 3, 4 |
| Empty list / missing `wsl.exe` → exit 1 | 2 |
| Missing `yq` + `--json` → exit 1 | 3 |
| Partial field failure exit 0 | 2, 4 |
| Standalone lib (not `wslutil-info`) | 1–4 |
| Makefile, dispatcher help, README | 5 |
| Names with spaces, WSL 1 vs 2 | 1 |
| Unset `WSL_DISTRO_NAME` → `wsl.localhost` paths | 2 (`resolve_file`) |
| `WSLUTIL_LIST_*` overrides for BATS | 2, 4 |
