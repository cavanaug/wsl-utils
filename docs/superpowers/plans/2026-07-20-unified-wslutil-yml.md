# Unified `wslutil.yml` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace split `wslutil.yml` (`winexe`/`winrun`) + `win-run.yml` (`aliases`) with one name-keyed `exes` map, factory+user merge-by-name, shared by `setup exes` and `win-run`.

**Architecture:** New `lib/wslutil-exes-config.sh` loads/merges config and answers mode/path/options queries. `wslutil-setup` iterates merged `exes` to create/remove shimdir links. `win-run` reads path/options from the same helper. Hard cut — no dual-read of old schemas.

**Tech Stack:** Bash, BATS, yq, envsubst, GNU Make

**Spec:** `docs/superpowers/specs/2026-07-20-unified-wslutil-yml-design.md`

## Global Constraints

- Canonical file: `wslutil.yml` only; delete `win-run.yml`
- Schema: `exes.<name>.{mode,path?,options?}` with `mode` ∈ `direct|shim|none`
- User override: factory then user; user key replaces **whole** entry
- `-c` / `--config`: that file only (no merge)
- `mode: none`: remove `$SHIMDIR/<name>` if present
- No auto-rewrite of existing user `win-run.yml` (warn only)
- Safe envsubst vars only: `${WIN_WINDIR} ${WIN_PROGRAMFILES} ${WIN_PROGRAMFILES_X86} ${WIN_USERPROFILE} ${WIN_LOCALAPPDATA} ${WIN_APPDATA}`

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-exes-config.sh` | Resolve paths, merge `exes`, query mode/path/options, expand `path`, warn on legacy `win-run.yml` |
| `bin/win-run` | Source helper; `resolve_alias` / `get_alias_options` use `exes.*` |
| `bin/wslutil-setup` | Source helper; process merged map; remove links for `mode: none` |
| `config/wslutil.yml` | Factory defaults in new schema |
| `config/win-run.yml` | Delete (tracked or untracked) |
| `bin/wslutil-config` | Stop expecting `win-run.yml`; init still copies remaining factory files |
| `Makefile` | Ensure new lib installs under `share/wslutil/lib/` (already `cp -R` pattern — verify) |
| `tests/test_exes_config.bats` | New: merge / query / `-c` / legacy warn |
| `tests/test_alias_resolution.bats` | New schema fixtures |
| `tests/test_wslutil_setup.bats` | New schema + `mode: none` removes link |
| `tests/test_integration.bats` | New schema; stop mutating factory `config/win-run.yml` |
| `tests/test_helpers.bash` | `create_test_alias_config` → `exes` map |
| `tests/test_wslutil_config.bats` | No `win-run.yml`; `exes:` not `winexe:` |
| `tests/test_security.bats` | Fixture uses `exes` |
| `README.md`, `DETAILS.md`, `CLAUDE.md`, `AGENTS.md`, `config/README.md`, `tests/README.md` | User-facing schema docs |

---

### Task 1: Config helper — failing tests first

**Files:**
- Create: `tests/test_exes_config.bats`
- Modify: `tests/test_helpers.bash` (helper for writing `exes` fixtures)

**Interfaces:**
- Produces (expected by later tasks): sourceable functions in `lib/wslutil-exes-config.sh`:
  - `wslutil_exes_envsubst_vars` — echo the envsubst allowlist string
  - `wslutil_exes_expand(path)` — envsubst safe vars → stdout
  - `wslutil_exes_load_merged(custom_config_or_empty, datadir, xdg_config_home)` — prints merged YAML of `.exes` map to stdout (or full doc with only `exes:` — see Step 3 note)
  - `wslutil_exes_mode(merged_yaml_file, name)` → `direct|shim|none|` (empty if missing)
  - `wslutil_exes_path(merged_yaml_file, name)` → path or empty
  - `wslutil_exes_options(merged_yaml_file, name)` → options or empty
  - `wslutil_exes_warn_legacy(xdg_config_home)` — warn on stderr if `win-run.yml` exists; return 0

- [ ] **Step 1: Update test helper for new schema**

Replace `create_test_alias_config` in `tests/test_helpers.bash`:

```bash
create_test_alias_config() {
    local config_file="$1"

    cat > "$config_file" << 'EOF'
exes:
  testcmd:
    mode: none
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: null
  testcmd-with-opts:
    mode: none
    path: ${WIN_WINDIR}/System32/ipconfig.exe
    options: "/all"
  testping:
    mode: none
    path: ${WIN_WINDIR}/System32/ping.exe
    options: "-n 2"
EOF
}
```

- [ ] **Step 2: Write failing helper tests**

Create `tests/test_exes_config.bats`:

```bash
#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    skip_if_no_yq
    # Will fail until lib exists
    source "$CHECKOUT_ROOT/lib/wslutil-exes-config.sh" 2>/dev/null || true
}

teardown() {
    cleanup_test_env
}

@test "exes merge: user entry replaces factory entry for same name" {
    local factory="$TEST_TEMP_DIR/factory.yml"
    local user="$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    cat > "$factory" << 'EOF'
exes:
  shared.exe:
    mode: direct
  only-factory.exe:
    mode: shim
EOF
    cat > "$user" << 'EOF'
exes:
  shared.exe:
    mode: none
    path: ${WIN_WINDIR}/System32/cmd.exe
  only-user.exe:
    mode: shim
EOF

    run wslutil_exes_load_merged "" "$TEST_TEMP_DIR" "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    # Write merged to temp for queries — or load_merged writes a file; prefer:
    # wslutil_exes_load_merged prints YAML with top-level exes:
    echo "$output" > "$TEST_TEMP_DIR/merged.yml"

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "shared.exe"
    [ "$output" = "none" ]

    run wslutil_exes_path "$TEST_TEMP_DIR/merged.yml" "shared.exe"
    [[ "$output" == *'${WIN_WINDIR}/System32/cmd.exe'* ]] || [[ "$output" == *'/System32/cmd.exe'* ]]

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "only-factory.exe"
    [ "$output" = "shim" ]

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "only-user.exe"
    [ "$output" = "shim" ]
}

@test "exes -c uses only custom file" {
    local factory="$TEST_TEMP_DIR/config/wslutil.yml"
    mkdir -p "$TEST_TEMP_DIR/config"
    cat > "$factory" << 'EOF'
exes:
  from-factory.exe:
    mode: direct
EOF
    local custom="$TEST_TEMP_DIR/custom.yml"
    cat > "$custom" << 'EOF'
exes:
  from-custom.exe:
    mode: shim
EOF
    # Also plant a user file that must be ignored when -c is set
    cat > "$XDG_CONFIG_HOME/wslutil/wslutil.yml" << 'EOF'
exes:
  from-user.exe:
    mode: none
EOF

    run wslutil_exes_load_merged "$custom" "$TEST_TEMP_DIR" "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    echo "$output" > "$TEST_TEMP_DIR/merged.yml"

    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-custom.exe"
    [ "$output" = "shim" ]
    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-factory.exe"
    [ "$output" = "" ]
    run wslutil_exes_mode "$TEST_TEMP_DIR/merged.yml" "from-user.exe"
    [ "$output" = "" ]
}

@test "exes expand applies only safe WIN_* vars" {
    export WIN_WINDIR="/mnt/c/Windows"
    export MALICIOUS="/tmp/evil"
    run wslutil_exes_expand '${WIN_WINDIR}/System32/x.exe ${MALICIOUS}'
    [ "$status" -eq 0 ]
    [[ "$output" == "/mnt/c/Windows/System32/x.exe "* ]] || [[ "$output" == "/mnt/c/Windows/System32/x.exe \${MALICIOUS}" ]] || [[ "$output" == *'/mnt/c/Windows/System32/x.exe'* ]]
    [[ "$output" != *"/tmp/evil"* ]]
}

@test "exes warn_legacy mentions win-run.yml when present" {
    touch "$XDG_CONFIG_HOME/wslutil/win-run.yml"
    run wslutil_exes_warn_legacy "$XDG_CONFIG_HOME"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "win-run.yml" ]] || [[ "$stderr" =~ "win-run.yml" ]]
}
```

Note for implementer: if `run` captures only stdout, call `wslutil_exes_warn_legacy` and assert via redirect, e.g. `run bash -c 'wslutil_exes_warn_legacy "$0" 2>&1' "$XDG_CONFIG_HOME"`.

- [ ] **Step 3: Run tests — expect fail (missing lib)**

Run: `./tests/run_tests.sh test_exes_config.bats`

Expected: FAIL (cannot source lib / command not found).

- [ ] **Step 4: Commit red tests**

```bash
git add tests/test_exes_config.bats tests/test_helpers.bash
git commit -m "$(cat <<'EOF'
test: add failing exes config merge/query coverage

EOF
)"
```

---

### Task 2: Implement `lib/wslutil-exes-config.sh`

**Files:**
- Create: `lib/wslutil-exes-config.sh`
- Modify: `Makefile` if lib install list is explicit (verify `cp -R lib` / share path includes new file)
- Test: `tests/test_exes_config.bats`

**Interfaces:**
- Consumes: yq, envsubst
- Produces: functions listed in Task 1

- [ ] **Step 1: Implement the library**

Create `lib/wslutil-exes-config.sh`:

```bash
# lib/wslutil-exes-config.sh — load/merge/query unified wslutil.yml exes map
# shellcheck shell=bash

wslutil_exes_envsubst_vars() {
    echo '${WIN_WINDIR} ${WIN_PROGRAMFILES} ${WIN_PROGRAMFILES_X86} ${WIN_USERPROFILE} ${WIN_LOCALAPPDATA} ${WIN_APPDATA}'
}

wslutil_exes_expand() {
    local raw="${1:-}"
    # shellcheck disable=SC2016
    echo "$raw" | envsubst "$(wslutil_exes_envsubst_vars)"
}

wslutil_exes_warn_legacy() {
    local xdg_config_home="${1:-${XDG_CONFIG_HOME:-$HOME/.config}}"
    local legacy="$xdg_config_home/wslutil/win-run.yml"
    if [[ -f "$legacy" ]]; then
        echo "wslutil: legacy $legacy found; move aliases into wslutil.yml under exes: (see docs)" >&2
    fi
    return 0
}

# Print merged YAML document: { exes: { ... } }
# Args: custom_config (empty = factory+user), datadir, xdg_config_home
wslutil_exes_load_merged() {
    local custom="${1:-}"
    local datadir="${2:?datadir required}"
    local xdg_config_home="${3:-${XDG_CONFIG_HOME:-$HOME/.config}}"

    if ! command -v yq >/dev/null 2>&1; then
        echo "exes: {}"
        return 0
    fi

    local files=()
    if [[ -n "$custom" ]]; then
        [[ -f "$custom" ]] || { echo "exes: {}"; return 0; }
        files=("$custom")
    else
        local factory="$datadir/config/wslutil.yml"
        local user="$xdg_config_home/wslutil/wslutil.yml"
        [[ -f "$factory" ]] && files+=("$factory")
        [[ -f "$user" ]] && files+=("$user")
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "exes: {}"
        return 0
    fi

    # Merge .exes maps left-to-right; later wins per key (whole object)
    yq eval-all '
      . as $doc ireduce({exes: {}}; .exes = (.exes * ($doc.exes // {})))
    ' "${files[@]}"
}

wslutil_exes_mode() {
    local merged_file="${1:?}"
    local name="${2:?}"
    yq eval ".exes.\"$name\".mode // \"\"" "$merged_file" 2>/dev/null | sed 's/^null$//'
}

wslutil_exes_path() {
    local merged_file="${1:?}"
    local name="${2:?}"
    local p
    p=$(yq eval ".exes.\"$name\".path // \"\"" "$merged_file" 2>/dev/null)
    [[ "$p" == "null" ]] && p=""
    echo "$p"
}

wslutil_exes_options() {
    local merged_file="${1:?}"
    local name="${2:?}"
    local o
    o=$(yq eval ".exes.\"$name\".options // \"\"" "$merged_file" 2>/dev/null)
    [[ "$o" == "null" ]] && o=""
    echo "$o"
}

# List exe names (keys) from a merged YAML file, one per line
wslutil_exes_names() {
    local merged_file="${1:?}"
    yq eval '.exes | keys | .[]' "$merged_file" 2>/dev/null || true
}
```

Adjust the `yq eval-all` expression if the installed yq dialect differs (`yq --version`). Prefer mikefarah yq v4. If reduce syntax fails, use:

```bash
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' ...
```

but only merge the `exes` key (do not clobber unrelated top-level keys if any). Spec only requires `exes`.

- [ ] **Step 2: Run tests — expect pass**

Run: `./tests/run_tests.sh test_exes_config.bats`

Expected: PASS (fix merge assertion / yq expression if needed until green).

- [ ] **Step 3: Verify Makefile installs lib**

```bash
grep -n 'lib' Makefile
```

If install already copies `lib/` into `$(DATADIR)/lib` or `share/wslutil/lib`, no change. Otherwise add the new file to the install list matching how `wslutil-paths.sh` is installed.

- [ ] **Step 4: Commit**

```bash
git add lib/wslutil-exes-config.sh Makefile
git commit -m "$(cat <<'EOF'
feat: add shared wslutil.yml exes load/merge helper

EOF
)"
```

---

### Task 3: Migrate factory `config/wslutil.yml`; remove `win-run.yml`

**Files:**
- Modify: `config/wslutil.yml`
- Delete: `config/win-run.yml` (if present tracked or untracked)
- Modify: `tests/test_wslutil_config.bats`
- Modify: `tests/test_make_install.bats` if it asserts `win-run.yml`

**Interfaces:**
- Consumes: schema from spec
- Produces: factory file readable by `wslutil_exes_load_merged`

- [ ] **Step 1: Rewrite factory config**

Replace `config/wslutil.yml` contents with the new map (preserve the same executables and comments intent):

```yaml
exes:
  ########################################
  # direct — symlink to Windows exe (no win-run overhead)
  ########################################
  cmd.exe:
    mode: direct
  powerShell.exe:
    mode: direct
  rundll32.exe:
    mode: direct
  ipconfig.exe:
    mode: direct
  net.exe:
    mode: direct
  netsh.exe:
    mode: direct
  systeminfo.exe:
    mode: direct
  taskkill.exe:
    mode: direct
  tasklist.exe:
    mode: direct
  code:
    mode: direct
    path: ${WIN_USERPROFILE}/AppData/Local/Programs/Microsoft VS Code/bin/code
  code-insiders:
    mode: direct
    path: ${WIN_USERPROFILE}/AppData/Local/Programs/Microsoft VS Code Insiders/bin/code-insiders
  brave.exe:
    mode: direct
    path: ${WIN_USERPROFILE}/AppData/Local/BraveSoftware/Brave-Browser/Application/brave.exe
  winget.exe:
    mode: direct
  gsudo.exe:
    mode: direct
  ########################################
  # shim — symlink to win-run (path convert + UTF-8)
  ########################################
  curl.exe:
    mode: shim
  subst.exe:
    mode: shim
  reg.exe:
    mode: shim
  regedit.exe:
    mode: shim
  taskmgr.exe:
    mode: shim
  wsl.exe:
    mode: shim
  notepad.exe:
    mode: shim
  notepad++.exe:
    mode: shim
  wt.exe:
    mode: shim
  devmgmt.msc:
    mode: shim
```

Link name is the map key (`code` not `code.exe`) — matches today's basename-from-path behavior for those VS Code entries.

- [ ] **Step 2: Delete `config/win-run.yml`**

```bash
rm -f config/win-run.yml
```

- [ ] **Step 3: Update config init tests**

In `tests/test_wslutil_config.bats`:

- Remove assertion `[ -f "$XDG_CONFIG_HOME/wslutil/win-run.yml" ]`
- Change `winexe: []` fixtures / greps to `exes: {}` or `exes:` / `cmd.exe` as appropriate for `--force` overwrite check (`grep -q 'cmd.exe'`)

- [ ] **Step 4: Run config + make-install tests**

Run: `./tests/run_tests.sh test_wslutil_config.bats test_make_install.bats`

Expected: PASS (or fix install assertions if they listed `win-run.yml`).

- [ ] **Step 5: Commit**

```bash
git add config/wslutil.yml tests/test_wslutil_config.bats tests/test_make_install.bats
git rm -f config/win-run.yml 2>/dev/null || true
git commit -m "$(cat <<'EOF'
feat: migrate factory wslutil.yml to unified exes map

EOF
)"
```

---

### Task 4: Wire `win-run` to the helper

**Files:**
- Modify: `bin/win-run`
- Modify: `tests/test_alias_resolution.bats`
- Modify: `tests/test_integration.bats`
- Modify: `tests/test_path_conversion.bats` (if it embeds `aliases:`)

**Interfaces:**
- Consumes: `wslutil_exes_load_merged`, `wslutil_exes_path`, `wslutil_exes_options`, `wslutil_exes_expand`, `wslutil_exes_warn_legacy`
- Produces: unchanged `resolve_alias` / `get_alias_options` signatures for bats

- [ ] **Step 1: Update alias/integration fixtures to `exes:`**

In every test YAML that used:

```yaml
aliases:
  name:
    path: ...
    options: ...
```

use:

```yaml
exes:
  name:
    mode: none
    path: ...
    options: ...
```

Change paths from `win-run.yml` to `wslutil.yml` where tests write user config.

**Critical:** `tests/test_integration.bats` "config hierarchy" must **not** write into `$CHECKOUT_ROOT/config/…`. Use a temp datadir:

```bash
local fake_datadir="$TEST_TEMP_DIR/datadir"
mkdir -p "$fake_datadir/config"
cat > "$fake_datadir/config/wslutil.yml" << 'EOF'
exes:
  hierarchy-test:
    mode: none
    path: ${WIN_WINDIR}/System32/global.exe
    options: "global"
EOF
# Point win-run at fake datadir by exporting a test hook OR
# source lib and call load_merged directly for hierarchy asserts.
```

Prefer testing hierarchy via `wslutil_exes_load_merged` + `resolve_alias` after setting `DATADIR` if win-run allows override; if `DATADIR` is fixed at source time, add optional `WSLUTIL_DATADIR` override at top of win-run:

```bash
DATADIR="${WSLUTIL_DATADIR:-$(wslutil_resolve_datadir "${BASH_SOURCE[0]}")}"
```

Only add this override if needed for tests (small, test-friendly).

- [ ] **Step 2: Source helper and rewrite resolve functions in `bin/win-run`**

After sourcing `wslutil-paths.sh`, source `wslutil-exes-config.sh` the same checkout/packaged way.

Replace `resolve_alias` / `get_alias_options` bodies:

```bash
resolve_alias() {
    local cmd="$1"
    wslutil_exes_warn_legacy "${XDG_CONFIG_HOME:-$HOME/.config}"

    if ! command -v yq >/dev/null 2>&1; then
        echo "$cmd"
        return
    fi

    local merged
    merged="$(mktemp)"
    wslutil_exes_load_merged "${CUSTOM_CONFIG:-}" "$DATADIR" "${XDG_CONFIG_HOME:-$HOME/.config}" >"$merged"

    local alias_path
    alias_path="$(wslutil_exes_path "$merged" "$cmd")"
    rm -f "$merged"

    if [[ -n "$alias_path" ]]; then
        alias_path="$(wslutil_exes_expand "$alias_path")"
        alias_path=$(wslpath -w "$alias_path" 2>/dev/null || echo "$alias_path")
        echo "$alias_path"
        return
    fi
    echo "$cmd"
}

get_alias_options() {
    local cmd="$1"
    if ! command -v yq >/dev/null 2>&1; then
        return
    fi
    local merged
    merged="$(mktemp)"
    wslutil_exes_load_merged "${CUSTOM_CONFIG:-}" "$DATADIR" "${XDG_CONFIG_HOME:-$HOME/.config}" >"$merged"
    local alias_options
    alias_options="$(wslutil_exes_options "$merged" "$cmd")"
    rm -f "$merged"
    if [[ -n "$alias_options" ]]; then
        wslutil_exes_expand "$alias_options"
    fi
}
```

Update help text: config paths are `wslutil.yml`, schema shows `exes:`.

Optional polish (not required): cache merged file per process to avoid double mktemp — YAGNI unless tests show slowness.

- [ ] **Step 3: Run alias + integration + path_conversion**

Run: `./tests/run_tests.sh test_alias_resolution.bats test_integration.bats test_path_conversion.bats`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add bin/win-run tests/test_alias_resolution.bats tests/test_integration.bats tests/test_path_conversion.bats
git commit -m "$(cat <<'EOF'
feat: resolve win-run paths from unified wslutil.yml

EOF
)"
```

---

### Task 5: Wire `wslutil-setup` exes processing

**Files:**
- Modify: `bin/wslutil-setup`
- Modify: `tests/test_wslutil_setup.bats`
- Modify: `tests/test_security.bats` (winexe fixture → exes)

**Interfaces:**
- Consumes: `wslutil_exes_load_merged`, `wslutil_exes_names`, `wslutil_exes_mode`, `wslutil_exes_path`, `wslutil_exes_expand`, `wslutil_exes_warn_legacy`
- Reuses: existing `create_symlink_to_winrun`, `create_direct_symlink` (adapt args)

- [ ] **Step 1: Rewrite setup tests for `exes` schema**

Examples of replacements in `tests/test_wslutil_setup.bats`:

```bash
# old
create_test_config "$file" 'winexe:
  - cmd.exe
winrun:
  - notepad.exe
'

# new
create_test_config "$file" 'exes:
  cmd.exe:
    mode: direct
  notepad.exe:
    mode: shim
'
```

Change log expectations from `Processing winrun entries` / `Processing winexe entries` to something like `Processing exes entries` / `Creating shim symlink` / `Creating direct symlink` — match whatever log strings you implement.

Add a new test:

```bash
@test "wslutil-setup exes removes shimdir link when mode is none" {
    setup_test_env  # or rely on file setup()
    mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin"
    local shimdir="${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin"
    # ensure XDG_DATA_HOME under TEST_TEMP_DIR in this test's setup
    ln -s "$CHECKOUT_ROOT/bin/win-run" "$shimdir/stale.exe"

    create_test_config "$XDG_CONFIG_HOME/wslutil/wslutil.yml" 'exes:
  stale.exe:
    mode: none
'

    # Need factory empty or only stale — with merge, factory may re-add keys.
    # Use -c so only this file applies:
    run "$WSLUTIL_SETUP" exes -c "$XDG_CONFIG_HOME/wslutil/wslutil.yml"
    [ "$status" -eq 0 ]
    [ ! -e "$shimdir/stale.exe" ]
}
```

Ensure `setup_test_env` (or this test) sets `XDG_DATA_HOME="$TEST_TEMP_DIR/.local/share"`.

Update "missing win-run" checkout test to also copy `lib/wslutil-exes-config.sh`.

- [ ] **Step 2: Replace `select_shim_config_file` + `process_winutil_config`**

Source `wslutil-exes-config.sh` next to other libs in `wslutil-setup`.

Replace process flow:

```bash
process_shims() {
    bootstrap_win_env_if_needed
    wslutil_exes_warn_legacy "${XDG_CONFIG_HOME:-$HOME/.config}"

    local merged
    merged="$(mktemp)"
    wslutil_exes_load_merged "${CUSTOM_CONFIG_FILE:-}" "$DATADIR" "${XDG_CONFIG_HOME:-$HOME/.config}" >"$merged"

    log_info "=== Phase: Shim Configuration ==="
    log_info "Using shim directory: $SHIMDIR"
    process_exes_config "$merged"
    rm -f "$merged"
}

process_exes_config() {
    local merged_file="$1"
    if [[ $DRY_RUN -ne 1 ]]; then
        mkdir -p "$SHIMDIR"
    fi
    log_info "Processing exes entries..."
    local name mode path
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        mode="$(wslutil_exes_mode "$merged_file" "$name")"
        path="$(wslutil_exes_path "$merged_file" "$name")"
        case "$mode" in
        shim)
            create_symlink_to_winrun "$name" || true
            ;;
        direct)
            if [[ -n "$path" ]]; then
                create_direct_symlink "$(wslutil_exes_expand "$path")" "$name" || true
            else
                create_direct_symlink "$name" "$name" || true
            fi
            ;;
        none)
            remove_shimdir_link "$name" || true
            ;;
        *)
            log_warning "exes.$name: invalid or missing mode '$mode' (skipping)"
            ;;
        esac
    done < <(wslutil_exes_names "$merged_file")
}

remove_shimdir_link() {
    local name="$1"
    local target_link="$SHIMDIR/$name"
    if [[ -e "$target_link" || -L "$target_link" ]]; then
        log_info "Removing symlink (mode: none): $name"
        if [[ $DRY_RUN -eq 1 ]]; then
            log_info "[DRY-RUN] Would remove: $target_link"
            return 0
        fi
        rm -f "$target_link"
        log_success "Removed: $target_link"
    fi
}
```

Adapt `create_direct_symlink` to accept optional explicit symlink name as `$2` (map key), so `path` basename need not equal key — when `$2` set, use it as `symlink_name`. If basename of `path` ≠ name, `log_warning` once per spec.

Remove old `select_shim_config_file` (logic lives in `wslutil_exes_load_merged`). Keep `-c` parsing setting `CUSTOM_CONFIG_FILE`.

- [ ] **Step 3: Run setup + security tests**

Run: `./tests/run_tests.sh test_wslutil_setup.bats test_security.bats`

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add bin/wslutil-setup tests/test_wslutil_setup.bats tests/test_security.bats
git commit -m "$(cat <<'EOF'
feat: drive setup exes from unified wslutil.yml map

EOF
)"
```

---

### Task 6: Docs and agent guides

**Files:**
- Modify: `README.md`, `DETAILS.md`, `CLAUDE.md`, `AGENTS.md`, `config/README.md`, `tests/README.md`
- Modify: `bin/win-run` / `bin/wslutil-setup` help if any leftover `winexe`/`win-run.yml` strings

- [ ] **Step 1: Replace schema docs**

Document:

- Single file `wslutil.yml` with `exes.<name>.mode|path|options`
- Factory + `~/.config/wslutil/wslutil.yml` merge-by-name
- `mode: none` = no PATH link (+ removes prior link on `setup exes`)
- Migration table from old `winexe`/`winrun`/`aliases`
- Remove all `win-run.yml` / `direct_links` / `shims` (stale DETAILS) instructions

Keep `config/README.md` accurate about which files `setup windows` / `setup linux` still use.

- [ ] **Step 2: Grep for leftovers**

```bash
rg -n 'win-run\.yml|winexe:|winrun:|aliases:|direct_links|shims:' \
  README.md DETAILS.md CLAUDE.md AGENTS.md config/ bin/ tests/ \
  --glob '!docs/superpowers/**'
```

Expected: no hits in user-facing/runtime paths (historical plans under `docs/superpowers/` may keep old names).

- [ ] **Step 3: Full test suite**

Run: `./tests/run_tests.sh`

Expected: PASS (skip-only tests OK).

- [ ] **Step 4: Commit**

```bash
git add README.md DETAILS.md CLAUDE.md AGENTS.md config/README.md tests/README.md
git commit -m "$(cat <<'EOF'
docs: document unified wslutil.yml exes schema

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Single `wslutil.yml`, drop `win-run.yml` | 3, 6 |
| Name-keyed `exes` map with mode/path/options | 3 |
| Factory + user merge by name; whole-entry replace | 1–2 |
| `-c` = that file only | 1–2, 4–5 |
| `direct` / `shim` / `none` behaviors | 5 |
| `mode: none` removes shimdir link | 5 |
| Shared helper for setup + win-run | 2, 4, 5 |
| Hard cut old schemas | 3–5 |
| Warn on legacy user `win-run.yml`, no auto-migrate | 2, 4–5 |
| Docs + tests | 1, 3–6 |
| No change to windows/linux setup / UTF-8 path convert | 5–6 (out of scope) |

## Placeholder / consistency self-review

- Function names stable across tasks: `wslutil_exes_*`
- Custom config vars: `CUSTOM_CONFIG` (win-run) vs `CUSTOM_CONFIG_FILE` (setup) — keep existing names; pass into `wslutil_exes_load_merged` as first arg
- No TBD/TODO left in steps
