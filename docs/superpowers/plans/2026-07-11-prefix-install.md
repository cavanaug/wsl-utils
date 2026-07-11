# PREFIX Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make wsl-utils installable via `make install PREFIX=…` with packaged core files under `bin/` + `share/wslutil/`, machine-local Windows shims under XDG data, and no `WSLUTIL_DIR` dependency.

**Architecture:** A small path helper resolves the data root from the script location (packaged `../share/wslutil` or checkout `../{config,env}`). `make install` copies core scripts and factory data only. `wslutil setup --shims` writes winexe/winrun links into `${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin`. `shellenv` prepends that shim dir to `PATH` and stops exporting `WSLUTIL_DIR`.

**Tech Stack:** Bash, GNU Make, BATS, yq/crudini (runtime deps checked by `make check-deps` / doctor)

**Spec:** `docs/superpowers/specs/2026-07-11-prefix-install-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-paths.sh` | `wslutil_resolve_datadir`, `wslutil_shimdir`, source bootstrap |
| `Makefile` | `install` / `uninstall` / `check-deps` |
| `VERSION` | Packaged version string |
| `bin/wslutil` | shellenv/upgrade/version/config dispatch; use path helper |
| `bin/wslutil-setup` | `--shims` / `--system`; write to shimdir |
| `bin/wslutil-config` | `config init [--force]` |
| `bin/win-run` | Resolve factory `win-run.yml` via datadir |
| `env/shellenv.bash` | PATH = shimdir only; no `WSLUTIL_DIR` |
| `install.sh` | Thin clone + `make install PREFIX=$HOME/.local` |
| `tests/test_paths.bats` | Datadir / shimdir resolution |
| `tests/test_make_install.bats` | PREFIX layout + uninstall safety |
| `tests/test_wslutil_setup.bats` | Update for shimdir + flags |
| `tests/test_helpers.bash` | Drop `WSLUTIL_DIR` reliance where possible |
| `README.md` / `DETAILS.md` | Install + setup docs |

---

### Task 1: Path helper library

**Files:**
- Create: `lib/wslutil-paths.sh`
- Create: `tests/test_paths.bats`
- Modify: `tests/test_helpers.bash`

- [ ] **Step 1: Write failing tests for datadir resolution**

```bash
#!/usr/bin/env bats
load test_helpers

setup() {
  setup_test_env
  FAKE_PREFIX="$TEST_TEMP_DIR/prefix"
  mkdir -p "$FAKE_PREFIX/bin" "$FAKE_PREFIX/share/wslutil/config" "$FAKE_PREFIX/share/wslutil/env"
  cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$FAKE_PREFIX/share/wslutil/lib/wslutil-paths.sh" 2>/dev/null || true
}

@test "packaged layout resolves share/wslutil as datadir" {
  mkdir -p "$FAKE_PREFIX/share/wslutil/lib"
  cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$FAKE_PREFIX/share/wslutil/lib/"
  # simulate script in bindir sourcing helper
  run bash -c "
    source '$FAKE_PREFIX/share/wslutil/lib/wslutil-paths.sh'
    wslutil_resolve_datadir '$FAKE_PREFIX/bin/wslutil'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$FAKE_PREFIX/share/wslutil" ]
}

@test "checkout layout resolves repo root as datadir" {
  REPO="$TEST_TEMP_DIR/checkout"
  mkdir -p "$REPO/bin" "$REPO/config" "$REPO/env" "$REPO/lib"
  cp "$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh" "$REPO/lib/"
  run bash -c "
    source '$REPO/lib/wslutil-paths.sh'
    wslutil_resolve_datadir '$REPO/bin/wslutil'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO" ]
}

@test "shimdir uses XDG_DATA_HOME" {
  export XDG_DATA_HOME="$TEST_TEMP_DIR/xdg-data"
  run bash -c "
    source '$BATS_TEST_DIRNAME/../lib/wslutil-paths.sh'
    wslutil_shimdir
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_TEMP_DIR/xdg-data/wslutil/bin" ]
}
```

- [ ] **Step 2: Run tests — expect fail (missing lib)**

Run: `./tests/run_tests.sh test_paths.bats`  
Expected: FAIL (cannot source `lib/wslutil-paths.sh`)

- [ ] **Step 3: Implement `lib/wslutil-paths.sh`**

```bash
# lib/wslutil-paths.sh — path helpers for wsl-utils (no exported WSLUTIL_* layout vars)
# Usage: source this file, then call functions below.
# Caller passes the path to the invoking script (usually "${BASH_SOURCE[0]}" or "$0").

wslutil_resolve_datadir() {
  local script_path="${1:?script path required}"
  local bindir
  bindir="$(cd "$(dirname "$script_path")" && pwd)"

  if [[ -d "$bindir/../share/wslutil/config" && -d "$bindir/../share/wslutil/env" ]]; then
    cd "$bindir/../share/wslutil" && pwd
    return 0
  fi
  if [[ -d "$bindir/../config" && -d "$bindir/../env" ]]; then
    cd "$bindir/.." && pwd
    return 0
  fi
  echo "wslutil: cannot find data directory relative to $bindir" >&2
  return 1
}

wslutil_shimdir() {
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin"
}

# Source this helper from an installed or checkout script in bin/:
#   _wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   if [[ -f "$_wsu_bin/../lib/wslutil-paths.sh" ]]; then
#     # checkout: repo/lib
#     # shellcheck source=/dev/null
#     source "$_wsu_bin/../lib/wslutil-paths.sh"
#   elif [[ -f "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh" ]]; then
#     # packaged: PREFIX/share/wslutil/lib
#     # shellcheck source=/dev/null
#     source "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh"
#   else
#     echo "wslutil: path helper not found" >&2
#     exit 1
#   fi
```

- [ ] **Step 4: Re-run tests — expect pass**

Run: `./tests/run_tests.sh test_paths.bats`  
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-paths.sh tests/test_paths.bats
git commit -m "$(cat <<'EOF'
Add path helper for packaged vs checkout data roots.

EOF
)"
```

---

### Task 2: Makefile install / uninstall / VERSION

**Files:**
- Create: `Makefile`
- Create: `VERSION` (content: calendar or semver string already used in project — start with `0.1.0` or today’s `2026.07.11`; pick one and keep it)
- Create: `tests/test_make_install.bats`
- Note: install `lib/wslutil-paths.sh` → `$(PREFIX)/share/wslutil/lib/`
- Note: install `wslview` as symlink to `win-browser` under `$(PREFIX)/bin`

- [ ] **Step 1: Write failing install-layout test**

```bash
#!/usr/bin/env bats
load test_helpers

@test "make install PREFIX places bin and share/wslutil" {
  PREFIX="$TEST_TEMP_DIR/pfx"
  run make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX"
  [ "$status" -eq 0 ]
  [ -x "$PREFIX/bin/wslutil" ]
  [ -f "$PREFIX/share/wslutil/config/wslutil.yml" ]
  [ -f "$PREFIX/share/wslutil/env/shellenv.bash" ]
  [ -f "$PREFIX/share/wslutil/lib/wslutil-paths.sh" ]
  [ -f "$PREFIX/share/wslutil/VERSION" ]
  [ -L "$PREFIX/bin/wslview" ] || [ -f "$PREFIX/bin/wslview" ]
}

@test "make uninstall leaves shimdir alone under PREFIX share" {
  PREFIX="$TEST_TEMP_DIR/pfx"
  make -C "$BATS_TEST_DIRNAME/.." install PREFIX="$PREFIX"
  mkdir -p "$PREFIX/share/wslutil/bin"
  ln -sf /bin/true "$PREFIX/share/wslutil/bin/dummy.exe"
  run make -C "$BATS_TEST_DIRNAME/.." uninstall PREFIX="$PREFIX"
  [ "$status" -eq 0 ]
  [ ! -e "$PREFIX/bin/wslutil" ]
  [ ! -d "$PREFIX/share/wslutil/config" ]
  [ ! -d "$PREFIX/share/wslutil/env" ]
  [ -L "$PREFIX/share/wslutil/bin/dummy.exe" ]
}
```

- [ ] **Step 2: Run test — expect fail**

Run: `./tests/run_tests.sh test_make_install.bats`  
Expected: FAIL (no Makefile)

- [ ] **Step 3: Implement Makefile**

```makefile
PREFIX  ?= /usr/local
DESTDIR ?=

BINDIR      := $(DESTDIR)$(PREFIX)/bin
DATADIR     := $(DESTDIR)$(PREFIX)/share/wslutil

CORE_SCRIPTS := \
	wslutil wslutil-doctor wslutil-setup wslutil-uptime \
	win-run win-open win-browser win-copy win-paste win-utf8 \
	wslpath-drive

.PHONY: install uninstall check-deps

install:
	install -d $(BINDIR) $(DATADIR)/config $(DATADIR)/env $(DATADIR)/lib
	for f in $(CORE_SCRIPTS); do \
		install -m 0755 bin/$$f $(BINDIR)/$$f; \
	done
	ln -sf win-browser $(BINDIR)/wslview
	cp -R config/. $(DATADIR)/config/
	cp -R env/. $(DATADIR)/env/
	install -m 0644 lib/wslutil-paths.sh $(DATADIR)/lib/wslutil-paths.sh
	install -m 0644 VERSION $(DATADIR)/VERSION

uninstall:
	for f in $(CORE_SCRIPTS) wslview; do \
		rm -f $(BINDIR)/$$f; \
	done
	rm -rf $(DATADIR)/config $(DATADIR)/env $(DATADIR)/lib
	rm -f $(DATADIR)/VERSION
	# do NOT remove $(DATADIR)/bin (shims) or $(DATADIR) itself

check-deps:
	@missing=0; \
	for c in yq crudini; do \
		if ! command -v $$c >/dev/null 2>&1; then \
			echo "missing: $$c"; missing=1; \
		else \
			echo "ok: $$c"; \
		fi; \
	done; \
	exit $$missing
```

Create `VERSION` with a single line, e.g. `2026.07.11`.

- [ ] **Step 4: Re-run tests — expect pass**

Run: `./tests/run_tests.sh test_make_install.bats`  
Expected: PASS

Also manually:  
`make install PREFIX=/tmp/wsu && /tmp/wsu/bin/wslutil --help`  
(After Task 3 wires path helper into `wslutil`; until then `--help` may still work via old dirname logic.)

- [ ] **Step 5: Commit**

```bash
git add Makefile VERSION tests/test_make_install.bats
git commit -m "$(cat <<'EOF'
Add Makefile install/uninstall/check-deps and VERSION.

EOF
)"
```

---

### Task 3: Wire path helper into `wslutil` + shellenv

**Files:**
- Modify: `bin/wslutil`
- Modify: `env/shellenv.bash`
- Create or modify: bats covering shellenv PATH / no `WSLUTIL_DIR`

- [ ] **Step 1: Write failing shellenv expectations**

Add to `tests/test_paths.bats` (or new `tests/test_shellenv.bats`):

```bash
@test "shellenv does not export WSLUTIL_DIR and prepends shimdir" {
  skip_if_not_wsl  # or mock: only check emitted script text
  export XDG_DATA_HOME="$TEST_TEMP_DIR/xdg-data"
  run bash -c "
    export PATH='$BATS_TEST_DIRNAME/../bin':\"\$PATH\"
    wslutil shellenv 2>/dev/null | head -n 20
  "
  # After implementation, prefer testing the sourced snippet:
  # output must not contain 'export WSLUTIL_DIR' or 'WSLUTIL_DIR='
  # and must mention shimdir path
  [[ ! "$output" =~ WSLUTIL_DIR= ]]
  [[ "$output" =~ wslutil/bin ]]
}
```

Adjust once `wslutil shellenv` stops printing `WSLUTIL_DIR=…` as the first line.

- [ ] **Step 2: Run — expect fail**

Expected: FAIL (current shellenv still sets `WSLUTIL_DIR` / PATH to install bin)

- [ ] **Step 3: Update `bin/wslutil`**

At top (after `set -euo pipefail`), source path helper via the bootstrap snippet from Task 1. Replace:

```bash
WSLUTIL_DIR="$(dirname "$(dirname "$0")")"
```

with:

```bash
_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
if [[ -f "$_wsu_bin/../lib/wslutil-paths.sh" ]]; then
  source "$_wsu_bin/../lib/wslutil-paths.sh"
elif [[ -f "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh" ]]; then
  source "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh"
else
  echo "wslutil: path helper not found" >&2
  exit 1
fi
WSLUTIL_DATADIR="$(wslutil_resolve_datadir "${BASH_SOURCE[0]}")"
```

Use `WSLUTIL_DATADIR` only as a **local script variable** (never export). Update `shellenv_command`:

```bash
shellenv_command() {
  SHELLENV=$(basename "$SHELL")
  local envfile="${WSLUTIL_DATADIR}/env/shellenv.${SHELLENV}"
  if [[ -f "$envfile" ]]; then
    # do not print WSLUTIL_DIR=
    cat "$envfile"
  else
    echo "ERROR: Shellenv file not found for ${SHELLENV}" >&2
    exit 1
  fi
}
```

Update local subcommand path:

```bash
local_command="${_wsu_bin}/wslutil-$1"
```

`--version`: if `"${WSLUTIL_DATADIR}/VERSION"` exists, print it; else if checkout `.git` beside datadir (checkout layout), keep git date/hash; else `wslutil unknown`.

`upgrade`: if `[[ -d "${WSLUTIL_DATADIR}/.git" ]]` (checkout) → git pull; else echo “installed via package/make; upgrade with your package manager or reinstall” and exit 1.

Dispatch `config` → `wslutil-config` (Task 5 will add the script; for now ensure help lists it).

- [ ] **Step 4: Update `env/shellenv.bash`**

Remove PATH prepend of `${WSLUTIL_DIR}/bin`. Replace with:

```bash
_wsu_shimdir="${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin"
mkdir -p "${_wsu_shimdir}"
if [[ ! ":$PATH:" == *":${_wsu_shimdir}:"* ]]; then
  export PATH="${_wsu_shimdir}:${PATH}"
fi
unset _wsu_shimdir
```

Keep `WIN_*` / interop logic otherwise unchanged. Do not reference `WSLUTIL_DIR`.

- [ ] **Step 5: Run tests + manual check**

Run: `./tests/run_tests.sh test_paths.bats`  
Manual: `eval "$(./bin/wslutil shellenv)"` → `echo $WSLUTIL_DIR` empty; `echo $PATH` starts with shimdir.

- [ ] **Step 6: Commit**

```bash
git add bin/wslutil env/shellenv.bash tests/
git commit -m "$(cat <<'EOF'
Resolve data root via path helper; shellenv prepends shimdir only.

EOF
)"
```

---

### Task 4: `wslutil setup --shims` / `--system` + shimdir

**Files:**
- Modify: `bin/wslutil-setup`
- Modify: `tests/test_wslutil_setup.bats`

- [ ] **Step 1: Write failing tests**

```bash
@test "setup --shims writes links only to XDG shimdir" {
  export XDG_DATA_HOME="$TEST_TEMP_DIR/xdg-data"
  # factory yml with one winrun entry pointing at win-run
  create_test_config "$TEST_TEMP_DIR/share/wslutil/config/wslutil.yml" $'winrun:\n  - notepad.exe\nwinexe: []\n'
  # Arrange packaged-like or checkout-like layout that setup can resolve
  # ... invoke setup --shims --dry-run or real with mocked Windows lookup
  run env HOME="$TEST_TEMP_DIR" XDG_DATA_HOME="$XDG_DATA_HOME" "$WSLUTIL_SETUP" --shims
  [ "$status" -eq 0 ]
  [ -L "$XDG_DATA_HOME/wslutil/bin/notepad.exe" ]
  [ ! -e "$TEST_TEMP_DIR/bin/notepad.exe" ]
}

@test "setup --help documents --shims and --system" {
  run "$WSLUTIL_SETUP" --help
  [[ "$output" =~ --shims ]]
  [[ "$output" =~ --system ]]
}
```

Adapt to how setup currently builds winexe (may need a winexe entry with a real `/mnt/c/...` path or mock). Prefer testing winrun → `win-run` absolute target under shimdir.

- [ ] **Step 2: Run — expect fail**

Expected: FAIL (links still go to `$WSLUTIL_DIR/bin`; no `--shims` flag)

- [ ] **Step 3: Implement setup changes**

1. Source path helper; set `DATADIR="$(wslutil_resolve_datadir …)"` and `SHIMDIR="$(wslutil_shimdir)"`.
2. Flags: `--shims`, `--system`, default (both). Keep `--dry-run`, `-c/--config`.
3. `create_symlink_to_winrun` / `create_direct_symlink`: target `$SHIMDIR/$name`; `mkdir -p "$SHIMDIR"`. Winrun link target = absolute path to `win-run` next to this setup script (`$_wsu_bin/win-run`), not a relative `win-run` inside shimdir.
4. Config discovery for shims:
   - If user `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/wslutil.yml` exists → use it (and still allow `-c`).
   - Else factory `"$DATADIR/config/wslutil.yml"` (packaged) or `"$DATADIR/config/wslutil.yml"` (checkout: datadir is repo root, so `config/wslutil.yml`).
5. `--system`: only the `/etc/wsl.conf` + Windows `.wslconfig` / `.wslgconfig` merges (existing merge logic). If `WIN_USERPROFILE` unset, bootstrap minimal `WIN_*` needed for those merges (call into same cmd.exe/set cache approach as shellenv, or require shellenv with a clear error — prefer self-bootstrap for `--shims` path expansion; for `--system` same).
6. Default `setup` = shims then system.
7. `--shims` must not call sudo.

- [ ] **Step 4: Update existing setup bats** that assumed links under `WSLUTIL_DIR/bin` to expect shimdir instead.

- [ ] **Step 5: Run setup + path tests — expect pass**

Run: `./tests/run_tests.sh test_wslutil_setup.bats test_paths.bats`

- [ ] **Step 6: Commit**

```bash
git add bin/wslutil-setup tests/test_wslutil_setup.bats
git commit -m "$(cat <<'EOF'
Point setup shims at XDG shimdir; add --shims and --system flags.

EOF
)"
```

---

### Task 5: `wslutil config init`

**Files:**
- Create: `bin/wslutil-config`
- Modify: `bin/wslutil` help text if needed
- Create: `tests/test_wslutil_config.bats`
- Modify: `Makefile` — add `wslutil-config` to `CORE_SCRIPTS`

- [ ] **Step 1: Failing tests**

```bash
@test "config init copies missing factory files into XDG config" {
  export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
  run "$BATS_TEST_DIRNAME/../bin/wslutil" config init
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/wslutil/wslutil.yml" ]
}

@test "config init does not overwrite unless --force" {
  export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"
  mkdir -p "$XDG_CONFIG_HOME/wslutil"
  echo 'winexe: []' > "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
  run "$BATS_TEST_DIRNAME/../bin/wslutil" config init
  [ "$status" -eq 0 ]
  grep -q 'winexe: \[\]' "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
}
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement `bin/wslutil-config`**

```bash
#!/usr/bin/bash
set -euo pipefail
# source path helper (same bootstrap as wslutil)
# datadir=$(wslutil_resolve_datadir ...)
# src="$datadir/config"  # both layouts: datadir/config
# dest="${XDG_CONFIG_HOME:-$HOME/.config}/wslutil"
# init [--force]: copy files that exist in src and (missing in dest or --force)
```

Wire dispatcher: `wslutil config …` already looks for `wslutil-config` if `$1=config` — verify `local_command` uses remaining args (`config` → script `wslutil-config` with `init`).

Current dispatcher: `wslutil-$1` with `$1` = first arg. So `wslutil config init` → runs `wslutil-config init`. Good.

- [ ] **Step 4: Tests pass + commit**

```bash
git add bin/wslutil-config tests/test_wslutil_config.bats
git commit -m "$(cat <<'EOF'
Add wslutil config init to seed user config from factory defaults.

EOF
)"
```

---

### Task 6: `win-run` datadir + test helper cleanup

**Files:**
- Modify: `bin/win-run` (replace `${WSLUTIL_DIR:-$(dirname…)}/config/win-run.yml` with datadir resolve)
- Modify: `tests/test_helpers.bash` — stop requiring exported `WSLUTIL_DIR` where possible; set `PATH` to checkout `bin` instead

- [ ] **Step 1: Grep for `WSLUTIL_DIR` and replace call sites in runtime scripts** (`bin/*`, `env/*`). Leave docs for Task 7.

- [ ] **Step 2: Run full test suite**

Run: `./tests/run_tests.sh`  
Expected: PASS (fix or skip remaining WSL-only failures as today)

- [ ] **Step 3: Commit**

```bash
git add bin/win-run tests/test_helpers.bash
git commit -m "$(cat <<'EOF'
Resolve win-run factory config via path helper; trim WSLUTIL_DIR from tests.

EOF
)"
```

---

### Task 7: `install.sh` + docs

**Files:**
- Modify: `install.sh`
- Modify: `README.md`, `DETAILS.md`, `CLAUDE.md` / `AGENTS.md` only where they document `WSLUTIL_DIR` / install (surgical)

- [ ] **Step 1: Rewrite `install.sh` as thin wrapper**

Behavior:
1. Optional clone to a build dir (or use current dir if already a checkout).
2. `make install PREFIX="${PREFIX:-$HOME/.local}"`
3. Print next steps: ensure `$PREFIX/bin` on PATH; `eval "$(wslutil shellenv)"`; `wslutil setup --shims`; `wslutil doctor`.

Do not append old `~/.wslutil/bin` PATH hacks that assume mutable checkout bin for shims.

- [ ] **Step 2: Update README Quick Start** to show:

```bash
make install PREFIX=$HOME/.local
# ensure ~/.local/bin on PATH
eval "$(wslutil shellenv)"
wslutil setup --shims
```

Keep curl|sh as calling updated `install.sh`.

- [ ] **Step 3: Manual success criteria from spec**

```bash
make install PREFIX=/tmp/wsu
PATH=/tmp/wsu/bin:$PATH wslutil --help
PATH=/tmp/wsu/bin:$PATH wslutil setup --shims   # links only under XDG shimdir
PATH=/tmp/wsu/bin:$PATH eval "$(wslutil shellenv)"; declare -p WSLUTIL_DIR 2>&1 | grep -q 'not found' || ! declare -p WSLUTIL_DIR
# checkout still works:
PATH=/path/to/repo/bin:$PATH wslutil --help
```

- [ ] **Step 4: Commit**

```bash
git add install.sh README.md DETAILS.md CLAUDE.md AGENTS.md
git commit -m "$(cat <<'EOF'
Point install docs and install.sh at make install + setup --shims.

EOF
)"
```

---

## Spec coverage checklist

| Spec item | Task |
|-----------|------|
| `make install` PREFIX + DESTDIR layout | 2 |
| uninstall spares shimdir | 2 |
| `make check-deps` | 2 |
| No `WSLUTIL_DIR` / resolve from script | 1, 3, 6 |
| shellenv shimdir PATH only | 3 |
| `setup --shims` / `--system` / default | 4 |
| `config init` | 5 |
| upgrade / VERSION | 3 |
| install.sh + docs | 7 |
| wslview as install-time link | 2 |
| Homebrew formula | out of scope |

---

## Self-review notes

- No `make install-shims` (removed per review).
- Helper lives in `lib/` checkout and `share/wslutil/lib/` when packaged — bootstrap tries both.
- `WSLUTIL_DATADIR` is a local variable name in scripts only; never exported.
