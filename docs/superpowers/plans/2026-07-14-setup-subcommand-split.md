# Setup Subcommand Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace flag-based `wslutil setup` with `wslutil setup {exes|windows|linux}`, isolating `/etc/wsl.conf` merges in `wslutil-setup-linux` (auto-sudo).

**Architecture:** `wslutil setup <sub>` still dispatches to `wslutil-setup` via existing `wslutil-*` discovery. That script implements `exes` and `windows`, and `exec`s sibling `wslutil-setup-linux` for `linux`. Shared merge/bootstrap helpers are sourced from a small lib file so both scripts stay DRY. Hard cut: no `--shims`/`--system`, no “run everything” default.

**Tech Stack:** Bash, BATS, yq, crudini, GNU Make

**Spec:** `docs/superpowers/specs/2026-07-14-setup-subcommand-split-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-setup-common.sh` | Shared logging, `bootstrap_win_env_if_needed`, `merge_config_file` (no nested sudo), path/datadir already via `wslutil-paths.sh` |
| `bin/wslutil-setup` | Parse `exes\|windows\|linux`; implement exes + windows; forward linux |
| `bin/wslutil-setup-linux` | Elevate if needed; merge factory+user `wsl.conf` → `/etc/wsl.conf` |
| `Makefile` | Install/uninstall `wslutil-setup-linux` |
| `tests/test_wslutil_setup.bats` | Retarget all cases to new CLI |
| `README.md`, `DETAILS.md`, `install.sh`, `bin/wslutil` help, `bin/wslutil-doctor` tip | User-facing command strings |

---

### Task 1: Failing CLI contract tests

**Files:**
- Modify: `tests/test_wslutil_setup.bats`

- [ ] **Step 1: Replace help / flag tests with subcommand contract**

Update the top of `tests/test_wslutil_setup.bats` so these replace the old `--help` / `--shims` / `--system` expectations:

```bash
@test "wslutil-setup --help documents exes windows linux" {
    run "$WSLUTIL_SETUP" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage: wslutil-setup" ]]
    [[ "$output" =~ "exes" ]]
    [[ "$output" =~ "windows" ]]
    [[ "$output" =~ "linux" ]]
    [[ "$output" != *"--shims"* ]]
    [[ "$output" != *"--system"* ]]
}

@test "wslutil-setup without subcommand prints usage and fails" {
    run "$WSLUTIL_SETUP"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "exes" ]]
    [[ "$output" =~ "windows" ]]
    [[ "$output" =~ "linux" ]]
}

@test "wslutil-setup unknown subcommand fails" {
    run "$WSLUTIL_SETUP" bogons
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown" ]] || [[ "$output" =~ "Usage:" ]]
}
```

Also change every existing `"$WSLUTIL_SETUP" --shims` → `"$WSLUTIL_SETUP" exes` and every `--system` that only cared about Windows/INI dry-run → temporarily leave failing until Task 3/4 (or mark those tests with the new names once implemented). For this task, at minimum convert help/bare/unknown tests and convert **exe-link** tests from `--shims` to `exes`.

- [ ] **Step 2: Run tests — expect CLI contract failures**

Run: `./tests/run_tests.sh test_wslutil_setup.bats`

Expected: FAIL on help / bare / unknown (and any already-converted `exes` invocations if parser still wants flags).

- [ ] **Step 3: Commit test expectations (red)**

```bash
git add tests/test_wslutil_setup.bats
git commit -m "$(cat <<'EOF'
test: expect setup exes/windows/linux subcommands

EOF
)"
```

---

### Task 2: Shared setup helpers lib

**Files:**
- Create: `lib/wslutil-setup-common.sh`
- Modify: `bin/wslutil-setup` (source it; move helpers)

- [ ] **Step 1: Extract shared helpers**

Create `lib/wslutil-setup-common.sh` containing (moved from `bin/wslutil-setup`, adjusted as noted):

- Color + `log_info` / `log_success` / `log_warning` / `log_error`
- `bootstrap_win_env_if_needed` (needs `$_wsu_bin` set by caller before source)
- `merge_config_file` — **remove** the `/etc/*` → nested `sudo` branch; callers that write `/etc` must already be root (linux script). Keep dry-run short-circuit.
- Do **not** move winexe/winrun symlink functions yet unless needed by both scripts (they stay in `wslutil-setup` only).

Caller preamble pattern (both scripts):

```bash
_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# source wslutil-paths.sh (existing pattern)
# shellcheck source=/dev/null
source "$_wsu_bin/../lib/wslutil-setup-common.sh"  # or share/wslutil/lib/… when packaged
```

Packaged installs must install this lib: add to `Makefile` install alongside `wslutil-paths.sh`:

```make
install -m 0644 lib/wslutil-setup-common.sh $(DATADIR)/lib/wslutil-setup-common.sh
```

And resolve source path like paths helper (checkout `../lib` vs packaged `../share/wslutil/lib`).

- [ ] **Step 2: Point `wslutil-setup` at the lib; keep old flag CLI temporarily so prior tests that still use `--shims` can be ignored — prefer finishing Task 3 in the same sitting if flags are already broken by Task 1.**

- [ ] **Step 3: Commit**

```bash
git add lib/wslutil-setup-common.sh bin/wslutil-setup Makefile
git commit -m "$(cat <<'EOF'
refactor: extract wslutil-setup-common helpers

EOF
)"
```

---

### Task 3: Subcommand parser + `exes` / `windows` in `wslutil-setup`

**Files:**
- Modify: `bin/wslutil-setup`
- Modify: `tests/test_wslutil_setup.bats`

- [ ] **Step 1: Rewrite CLI parsing**

Replace flag mode selection with:

```bash
DRY_RUN=0
CUSTOM_CONFIG_FILE=""
SUBCOMMAND=""

show_help() {
    cat <<EOF
Usage: wslutil-setup <exes|windows|linux> [OPTIONS]

  exes      Create winexe/winrun links in the XDG data bin directory (user)
  windows   Merge .wslconfig and .wslgconfig into the Windows user profile (user)
  linux     Merge /etc/wsl.conf (elevated; execs wslutil-setup-linux)

Options:
  --dry-run          Show what would be done without making changes
  -c, --config FILE  (exes only) Use custom wslutil.yml
  --help             Show this help message and exit

Examples:
  wslutil setup exes
  wslutil setup windows
  wslutil setup linux
  sudo wslutil-setup-linux

EOF
}

# Parse: first non-option is subcommand; allow --help/-h anywhere
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help|-h) show_help; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -c|--config)
        [[ -n "${2:-}" && -f "$2" ]] || { echo "Error: -c/--config requires an existing file" >&2; exit 1; }
        CUSTOM_CONFIG_FILE="$2"; shift 2 ;;
    exes|windows|linux)
        [[ -z "$SUBCOMMAND" ]] || { echo "Error: multiple subcommands" >&2; exit 1; }
        SUBCOMMAND="$1"; shift ;;
    *)
        echo "Unknown option or subcommand: $1" >&2
        show_help
        exit 1 ;;
    esac
done

if [[ -z "$SUBCOMMAND" ]]; then
    show_help
    exit 1
fi
```

`main`:

```bash
case "$SUBCOMMAND" in
exes) process_shims ;;   # rename later to process_exes if desired; behavior unchanged
windows) process_windows ;;
linux)
    linux_script="${_wsu_bin}/wslutil-setup-linux"
    if [[ ! -x "$linux_script" ]]; then
        log_error "wslutil-setup-linux not found: $linux_script"
        exit 1
    fi
    args=()
    [[ $DRY_RUN -eq 1 ]] && args+=(--dry-run)
    exec "$linux_script" "${args[@]}"
    ;;
esac
```

- [ ] **Step 2: Split former `process_system_configs`**

Replace `process_system_configs` / dual-phase directory walk with:

```bash
process_windows() {
    bootstrap_win_env_if_needed
    require_crudini
    merge_windows_from_dir "$DATADIR/config" "Factory"
    merge_windows_from_dir "${XDG_CONFIG_HOME:-$HOME/.config}/wslutil" "User"
}

merge_windows_from_dir() {
    local config_dir="$1" phase_name="$2"
    [[ -d "$config_dir" ]] || { log_info "Config directory not found: $config_dir (skipping $phase_name)"; return 0; }
    if [[ -z "${WIN_USERPROFILE:-}" ]]; then
        log_warning "WIN_USERPROFILE not set - skipping Windows config files for $phase_name"
        return 0
    fi
    [[ -f "$config_dir/wslconfig" ]] && merge_config_file "$config_dir/wslconfig" "$WIN_USERPROFILE/.wslconfig" "WSL2 configuration ($phase_name)"
    [[ -f "$config_dir/wslgconfig" ]] && merge_config_file "$config_dir/wslgconfig" "$WIN_USERPROFILE/.wslgconfig" "WSLg configuration ($phase_name)"
}
```

Remove any `/etc/wsl.conf` handling from `wslutil-setup`. Remove `--shims`/`--system`/`MODE_SPECIFIED`/`RUN_*` entirely.

- [ ] **Step 3: Retarget remaining bats for `exes` and `windows`**

Examples:

```bash
@test "wslutil-setup windows --dry-run shows what would be done" {
    create_test_config "$XDG_CONFIG_HOME/wslutil/wslconfig" "[wsl2]
memory=4GB"
    export WIN_USERPROFILE="$TEST_TEMP_DIR/winprofile"
    mkdir -p "$WIN_USERPROFILE"
    run "$WSLUTIL_SETUP" windows --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Running in dry-run mode" ]]
    [[ "$output" =~ "Would merge configuration" ]]
}

@test "wslutil-setup windows requires crudini" {
    # same PATH empty-dir trick as before, invoke: windows
    ...
}

@test "wslutil-setup exes --dry-run ..." { ... }  # former --shims cases
```

Ensure no test still expects `/etc/wsl.conf` merges from `wslutil-setup` alone.

- [ ] **Step 4: Run bats**

Run: `./tests/run_tests.sh test_wslutil_setup.bats`

Expected: PASS for help/bare/`exes`/`windows`; `linux` tests may still be absent/fail until Task 4.

- [ ] **Step 5: Commit**

```bash
git add bin/wslutil-setup tests/test_wslutil_setup.bats
git commit -m "$(cat <<'EOF'
feat: wslutil-setup exes and windows subcommands

EOF
)"
```

---

### Task 4: `wslutil-setup-linux` + elevation

**Files:**
- Create: `bin/wslutil-setup-linux`
- Modify: `Makefile`
- Modify: `tests/test_wslutil_setup.bats`

- [ ] **Step 1: Write failing tests for linux script**

```bash
@test "wslutil-setup-linux --help shows usage" {
    run "$CHECKOUT_ROOT/bin/wslutil-setup-linux" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "wslutil-setup-linux" ]]
    [[ "$output" =~ "/etc/wsl.conf" ]]
}

@test "wslutil-setup linux forwards to wslutil-setup-linux" {
    # dry-run under test sudo stub
    export WSLUTIL_SUDO="$TEST_TEMP_DIR/fake-sudo"
    cat >"$WSLUTIL_SUDO" <<'EOF'
#!/bin/bash
# record and run remaining args without elevation
echo "fake-sudo $*" >>"${WSLUTIL_SUDO_LOG:?}"
exec "$@"
EOF
    chmod +x "$WSLUTIL_SUDO"
    export WSLUTIL_SUDO_LOG="$TEST_TEMP_DIR/sudo.log"
    : >"$WSLUTIL_SUDO_LOG"

    create_test_config "$XDG_CONFIG_HOME/wslutil/wsl.conf" "[interop]
appendWindowsPath = false"

    run "$WSLUTIL_SETUP" linux --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Would merge configuration" ]] || [[ "$output" =~ "wsl.conf" ]]
}

@test "wslutil-setup-linux non-root re-execs via WSLUTIL_SUDO" {
    export WSLUTIL_SUDO="$TEST_TEMP_DIR/fake-sudo"
    # same fake-sudo as above
    ...
    # Only assert if EUID != 0
    if [[ "$EUID" -eq 0 ]]; then
        skip "already root"
    fi
    run "$CHECKOUT_ROOT/bin/wslutil-setup-linux" --dry-run
    [ "$status" -eq 0 ]
    grep -q 'wslutil-setup-linux' "$WSLUTIL_SUDO_LOG"
}
```

- [ ] **Step 2: Implement `bin/wslutil-setup-linux`**

```bash
#!/usr/bin/bash
# wslutil-setup-linux - Merge factory/user wsl.conf into /etc/wsl.conf
set -euo pipefail

_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# source paths + setup-common (same dual checkout/packaged lookup as wslutil-setup)

DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help|-h)
        cat <<EOF
Usage: wslutil-setup-linux [--dry-run]

Merge wsl.conf into /etc/wsl.conf (requires root).
Preferred invocation: sudo wslutil-setup-linux

EOF
        exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Elevate when not root (test hook: WSLUTIL_SUDO overrides sudo binary)
if [[ $EUID -ne 0 ]]; then
    sudo_bin="${WSLUTIL_SUDO:-sudo}"
    args=()
    [[ $DRY_RUN -eq 1 ]] && args+=(--dry-run)
    exec "$sudo_bin" -- "$_wsu_bin/wslutil-setup-linux" "${args[@]}"
fi

DATADIR="$(wslutil_resolve_datadir "${BASH_SOURCE[0]}")"
require_crudini

merge_linux_from_dir() {
    local config_dir="$1" phase_name="$2"
    [[ -d "$config_dir" ]] || return 0
    [[ -f "$config_dir/wsl.conf" ]] || return 0
    merge_config_file "$config_dir/wsl.conf" "/etc/wsl.conf" "WSL configuration ($phase_name)"
}

[[ $DRY_RUN -eq 1 ]] && log_info "Running in dry-run mode - no changes will be made"
merge_linux_from_dir "$DATADIR/config" "Factory"
merge_linux_from_dir "${XDG_CONFIG_HOME:-$HOME/.config}/wslutil" "User"
[[ $DRY_RUN -eq 1 ]] && log_info "Dry-run completed - no changes were made" || log_success "Linux WSL configuration setup completed"
```

Note: under `fake-sudo` that `exec`s the script again **without** changing EUID, the script would loop. Fake-sudo for the re-exec test must either:

1. set a sentinel env `WSLUTIL_SETUP_LINUX_ELEVATED=1` and have the script treat that as root for tests, **or**
2. fake-sudo runs the script body by sourcing after exporting `EUID` mock (hard in bash).

**Preferred test hook (add to script):**

```bash
if [[ $EUID -ne 0 && -z "${WSLUTIL_SETUP_LINUX_ASSUME_ROOT:-}" ]]; then
    sudo_bin="${WSLUTIL_SUDO:-sudo}"
    ...
    exec "$sudo_bin" -- env WSLUTIL_SETUP_LINUX_ASSUME_ROOT=1 "$_wsu_bin/wslutil-setup-linux" "${args[@]}"
fi
```

And fake-sudo:

```bash
#!/bin/bash
echo "fake-sudo $*" >>"$WSLUTIL_SUDO_LOG"
exec "$@"
```

So second entry has `WSLUTIL_SETUP_LINUX_ASSUME_ROOT=1` and skips re-exec. Production `sudo` preserves that env by default when using `sudo -- env …`.

- [ ] **Step 3: Makefile**

In `CORE_SCRIPTS` add `wslutil-setup-linux`. Ensure `lib/wslutil-setup-common.sh` is installed (Task 2).

- [ ] **Step 4: Run bats — expect PASS**

Run: `./tests/run_tests.sh test_wslutil_setup.bats`

- [ ] **Step 5: Commit**

```bash
git add bin/wslutil-setup-linux Makefile tests/test_wslutil_setup.bats lib/wslutil-setup-common.sh
git commit -m "$(cat <<'EOF'
feat: add wslutil-setup-linux with sudo re-exec

EOF
)"
```

---

### Task 5: Docs, install tip, doctor, dispatcher help

**Files:**
- Modify: `README.md`, `DETAILS.md`, `install.sh`, `bin/wslutil`, `bin/wslutil-doctor`
- Optionally: `AGENTS.md` / `CLAUDE.md` setup flag mentions (only if they still say `--shims`)

- [ ] **Step 1: Update user-facing strings**

Replace:

- `wslutil setup --shims` → `wslutil setup exes`
- Bare “run setup for everything” → list the three actions
- Doctor tip `wslutil setup` → `wslutil setup exes` (and mention optional windows/linux)
- `bin/wslutil` `--help` setup line: document nested subcommands, note linux uses `sudo wslutil-setup-linux`

`install.sh` next steps:

```bash
echo "       wslutil setup exes"
echo "       # optional: wslutil setup windows"
echo "       # optional: sudo wslutil-setup-linux"
```

- [ ] **Step 2: Grep for stale flags**

Run: `rg -n 'setup --shims|setup --system|wslutil setup"' README.md DETAILS.md install.sh bin/ tests/ AGENTS.md CLAUDE.md`

Expected: no user-facing stale references (historical `docs/superpowers/plans/2026-07-11-*` may remain).

- [ ] **Step 3: Commit**

```bash
git add README.md DETAILS.md install.sh bin/wslutil bin/wslutil-doctor
git commit -m "$(cat <<'EOF'
docs: point install and help at setup exes/windows/linux

EOF
)"
```

---

### Task 6: Full regression

- [ ] **Step 1: Run full suite**

Run: `./tests/run_tests.sh`

Expected: all PASS (skip Windows-dependent cases as today).

- [ ] **Step 2: Smoke make install**

```bash
PREFIX=/tmp/wsu-setup-split-test
rm -rf "$PREFIX"
make install PREFIX="$PREFIX"
test -x "$PREFIX/bin/wslutil-setup"
test -x "$PREFIX/bin/wslutil-setup-linux"
test -f "$PREFIX/share/wslutil/lib/wslutil-setup-common.sh"
"$PREFIX/bin/wslutil-setup" --help | grep -q exes
"$PREFIX/bin/wslutil-setup-linux" --help | grep -q wsl.conf
```

- [ ] **Step 3: Final commit only if smoke fixed anything; else done**

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| `setup exes` / `windows` / `linux` CLI | 1, 3, 4 |
| Hard cut flags / no full default | 3 |
| `wslutil-setup` owns exes+windows | 3 |
| `wslutil-setup-linux` + auto-sudo; docs say `sudo wslutil-setup-linux` | 4, 5 |
| windows merges both profile files | 3 |
| linux only `/etc/wsl.conf` | 4 |
| Makefile installs new binary + lib | 2, 4 |
| Docs / install.sh / doctor | 5 |
| BATS retarget + elevation hook | 1, 3, 4, 6 |
