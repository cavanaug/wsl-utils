# `wslutil info` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add read-only `wslutil info` (`bin/wslutil-info`) that prints host WSL facts plus one distro block (default: this instance).

**Architecture:** Pure filter/classify logic lives in `lib/wslutil-info.sh` so BATS can source it without Windows. `bin/wslutil-info` parses flags, calls collectors (injectable command names), prints human or `yq eval -o json`. Runtime comes from `wslinfo`; config files are filtered to non-default keys; distro VHD path comes from the Lxss registry. Never start a distro and never `wsl --mount`.

**Tech Stack:** Bash, BATS, crudini, mikefarah `yq eval`, `win-utf8`, `win-env`, PowerShell `-NoProfile`

**Spec:** `docs/superpowers/specs/2026-08-30-wslutil-info-design.md`

## Global Constraints

- Public name is `wslutil info` only (binary `wslutil-info`). No `wsl-info`.
- Stdout is only the report (human or JSON). Usage / unknown `--distro` go to stderr, exit 1.
- Missing sources → field `unavailable` / JSON `null` (or `wslconf.available: false`). Exit 0.
- Never fill a `wslinfo` field from a config file.
- Never `wsl.exe -d NAME` to probe. Never `wsl.exe --mount`.
- `--json` requires `yq`; human mode does not. Missing `yq` + `--json` → exit 1.
- PowerShell calls use `-NoProfile`.
- `wsl.exe` output goes through `win-utf8`.
- Do not change `wslutil doctor` scoring behavior.

---

## File map

| File | Responsibility |
|------|----------------|
| `lib/wslutil-info.sh` | Defaults table, omit/keep, INI filter, collectors, human + JSON emit |
| `bin/wslutil-info` | CLI (`--json`, `--distro`, `--help`), source lib, exit codes |
| `Makefile` | Install `wslutil-info` + `lib/wslutil-info.sh` |
| `bin/wslutil` | List `info` in usage / `--help`; exclude it from Extra Subcommands |
| `tests/test_wslutil_info.bats` | Filter unit tests + CLI tests with fake `wslinfo` / `wsl.exe` |
| `tests/test_make_install.bats` | Assert installed binary + lib |
| `README.md` | One row + one example for `wslutil info` |

---

### Task 1: Non-default config filter

**Files:**
- Create: `lib/wslutil-info.sh`
- Create: `tests/test_wslutil_info.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `wslutil_info_documented_default kind section key` — stdout default or formula; exit 1 if unknown key
  - `wslutil_info_always_show kind section key` — exit 0 if always show when present
  - `wslutil_info_should_omit kind section key value` — exit 0 omit, 1 keep
  - `kind` is `wslconfig` or `wslconf` (`.wslgconfig` is not filtered here)

- [ ] **Step 1: Write failing filter tests**

Create `tests/test_wslutil_info.bats`:

```bash
#!/usr/bin/env bats

load test_helpers

setup() {
    setup_test_env
    # shellcheck source=/dev/null
    source "$BATS_TEST_DIRNAME/../lib/wslutil-info.sh"
}

teardown() {
    cleanup_test_env
}

@test "omit guiApplications=true (default)" {
    run wslutil_info_should_omit wslconfig wsl2 guiApplications true
    [ "$status" -eq 0 ]
}

@test "keep guiApplications=false" {
    run wslutil_info_should_omit wslconfig wsl2 guiApplications false
    [ "$status" -eq 1 ]
}

@test "omit networkingMode=NAT case-insensitively" {
    run wslutil_info_should_omit wslconfig wsl2 networkingMode NAT
    [ "$status" -eq 0 ]
}

@test "keep memory=4GB even though default is a formula" {
    run wslutil_info_should_omit wslconfig wsl2 memory 4GB
    [ "$status" -eq 1 ]
}

@test "keep unknown key" {
    run wslutil_info_should_omit wslconfig wsl2 totallyNewKey 1
    [ "$status" -eq 1 ]
}

@test "omit appendWindowsPath=true; keep false" {
    run wslutil_info_should_omit wslconf interop appendWindowsPath true
    [ "$status" -eq 0 ]
    run wslutil_info_should_omit wslconf interop appendWindowsPath false
    [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run tests — expect missing function**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL (`source` or `wslutil_info_should_omit: command not found`)

- [ ] **Step 3: Implement filter**

Create `lib/wslutil-info.sh`:

```bash
# lib/wslutil-info.sh — helpers for wslutil-info (safe to source from tests)

wslutil_info_norm_bool() {
    local v="${1,,}"
    case "$v" in
    true | yes | 1) echo true ;;
    false | no | 0) echo false ;;
    *) echo "$1" ;;
    esac
}

wslutil_info_always_show() {
    local kind="$1" section="$2" key="$3"
    case "$kind:$section:$key" in
    wslconfig:wsl2:memory | wslconfig:wsl2:processors | wslconfig:wsl2:swap | \
        wslconfig:wsl2:swapFile | wslconfig:wsl2:kernel | wslconfig:wsl2:kernelModules | \
        wslconfig:wsl2:kernelCommandLine) return 0 ;;
    wslconf:network:hostname | wslconf:user:default | wslconf:boot:command | \
        wslconf:boot:systemd) return 0 ;;
    *) return 1 ;;
    esac
}

# stdout: documented default or formula string. Return 1 if key is unknown.
wslutil_info_documented_default() {
    local kind="$1" section="$2" key="$3"
    case "$kind:$section:$key" in
    wslconfig:wsl2:localhostForwarding) echo true ;;
    wslconfig:wsl2:safeMode) echo false ;;
    wslconfig:wsl2:guiApplications) echo true ;;
    wslconfig:wsl2:debugConsole) echo false ;;
    wslconfig:wsl2:maxCrashDumpCount) echo 10 ;;
    wslconfig:wsl2:nestedVirtualization) echo true ;;
    wslconfig:wsl2:vmIdleTimeout) echo 60000 ;;
    wslconfig:wsl2:dnsProxy) echo true ;;
    wslconfig:wsl2:networkingMode) echo nat ;;
    wslconfig:wsl2:firewall) echo true ;;
    wslconfig:wsl2:dnsTunneling) echo true ;;
    wslconfig:wsl2:autoProxy) echo true ;;
    wslconfig:wsl2:defaultVhdSize) echo 1099511627776 ;;
    wslconfig:wsl2:memory) echo "50% of host RAM" ;;
    wslconfig:wsl2:processors) echo "host logical CPUs" ;;
    wslconfig:wsl2:swap) echo "25% of memory, rounded up to nearest GB" ;;
    wslconfig:wsl2:swapFile) echo '%Temp%\swap.vhdx' ;;
    wslconfig:wsl2:kernel) echo "Microsoft inbox kernel" ;;
    wslconfig:wsl2:kernelModules) echo "inbox modules VHD" ;;
    wslconfig:wsl2:kernelCommandLine) echo "(none)" ;;
    wslconfig:experimental:autoMemoryReclaim) echo dropCache ;;
    wslconfig:experimental:sparseVhd) echo false ;;
    wslconfig:experimental:bestEffortDnsParsing) echo false ;;
    wslconfig:experimental:dnsTunnelingIpAddress) echo 10.255.255.254 ;;
    wslconfig:experimental:initialAutoProxyTimeout) echo 1000 ;;
    wslconfig:experimental:hostAddressLoopback) echo false ;;
    wslconf:automount:enabled) echo true ;;
    wslconf:automount:mountFsTab) echo true ;;
    wslconf:automount:root) echo /mnt/ ;;
    wslconf:network:generateHosts) echo true ;;
    wslconf:network:generateResolvConf) echo true ;;
    wslconf:interop:enabled) echo true ;;
    wslconf:interop:appendWindowsPath) echo true ;;
    wslconf:boot:protectBinfmt) echo true ;;
    wslconf:gpu:enabled) echo true ;;
    wslconf:time:useWindowsTimezone) echo true ;;
    wslconf:network:hostname) echo "Windows hostname" ;;
    wslconf:user:default) echo "distro default user" ;;
    wslconf:boot:command) echo "(none)" ;;
    wslconf:boot:systemd) echo "distro default" ;;
    *) return 1 ;;
    esac
}

# 0 = omit (equals default), 1 = keep
wslutil_info_should_omit() {
    local kind="$1" section="$2" key="$3" value="$4"
    if wslutil_info_always_show "$kind" "$section" "$key"; then
        return 1
    fi
    local def
    if ! def="$(wslutil_info_documented_default "$kind" "$section" "$key")"; then
        return 1
    fi
    local nv nd
    nv="$(wslutil_info_norm_bool "$value")"
    nd="$(wslutil_info_norm_bool "$def")"
    if [[ "$key" == "networkingMode" ]]; then
        [[ "${nv,,}" == "${nd,,}" ]] && return 0
        return 1
    fi
    if [[ "$key" == "defaultVhdSize" ]]; then
        [[ "$nv" == "$nd" || "${nv^^}" == "1TB" ]] && return 0
        return 1
    fi
    [[ "$nv" == "$nd" ]] && return 0
    return 1
}
```

`ignoredPorts` and `[automount] options` have no documented default in this function → unknown → keep. That matches the spec.

- [ ] **Step 4: Run tests — expect pass**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-info.sh tests/test_wslutil_info.bats
git commit -m "$(cat <<'EOF'
feat: add wslutil-info non-default config filter

EOF
)"
```

---

### Task 2: CLI skeleton, install, dispatcher help

**Files:**
- Create: `bin/wslutil-info`
- Modify: `Makefile` (`CORE_SCRIPTS` + `install -m 0644 lib/wslutil-info.sh`)
- Modify: `bin/wslutil` usage / `--help` / extras exclusion
- Modify: `tests/test_make_install.bats` (assert `bin/wslutil-info` and lib)
- Modify: `tests/test_wslutil_info.bats` (CLI tests)

**Interfaces:**
- Consumes: `lib/wslutil-info.sh` (source only; no new functions required yet)
- Produces: `wslutil-info --help` exit 0; unknown flag exit 1 on stderr; `wslutil info --help` via dispatcher

- [ ] **Step 1: Add CLI tests**

Append to `tests/test_wslutil_info.bats`:

```bash
@test "wslutil-info --help exits 0 and mentions --json and --distro" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "--json" ]]
    [[ "$output" =~ "--distro" ]]
}

@test "wslutil-info unknown flag exits 1" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --bogus
    [ "$status" -eq 1 ]
}

@test "wslutil info --help dispatches" {
    run "$BATS_TEST_DIRNAME/../bin/wslutil" info --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "--json" ]]
}
```

In `tests/test_make_install.bats`, inside `"make install PREFIX places bin and share/wslutil"`, add:

```bash
    [ -x "$PREFIX/bin/wslutil-info" ]
    [ -f "$PREFIX/share/wslutil/lib/wslutil-info.sh" ]
```

- [ ] **Step 2: Run — expect fail (no binary)**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL on `--help` / dispatch

- [ ] **Step 3: Implement CLI + install + help**

`bin/wslutil-info` (full file for this task; later tasks add collection calls after parse):

```bash
#!/usr/bin/bash
# wslutil-info - Read-only WSL environment report
set -euo pipefail

_wsu_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$_wsu_bin/../lib/wslutil-paths.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../lib/wslutil-paths.sh"
    # shellcheck source=/dev/null
    source "$_wsu_bin/../lib/wslutil-info.sh"
elif [[ -f "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh" ]]; then
    # shellcheck source=/dev/null
    source "$_wsu_bin/../share/wslutil/lib/wslutil-paths.sh"
    # shellcheck source=/dev/null
    source "$_wsu_bin/../share/wslutil/lib/wslutil-info.sh"
else
    echo "wslutil-info: path helper not found" >&2
    exit 1
fi

show_help() {
    cat <<EOF
Usage: wslutil-info [--json] [--distro NAME]

Read-only report of the WSL host and one distro (default: this instance).

Options:
  --json         Machine-readable JSON on stdout
  --distro NAME  Fill the distro block for NAME instead of this instance
  --help         Show this help and exit
EOF
}

JSON=0
DISTRO=""
while [[ $# -gt 0 ]]; do
    case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --json)
        JSON=1
        shift
        ;;
    --distro)
        if [[ $# -lt 2 ]]; then
            echo "wslutil-info: --distro requires a name" >&2
            show_help >&2
            exit 1
        fi
        DISTRO="$2"
        shift 2
        ;;
    --distro=*)
        DISTRO="${1#--distro=}"
        shift
        ;;
    *)
        echo "wslutil-info: unknown option: $1" >&2
        show_help >&2
        exit 1
        ;;
    esac
done

# Task 3 fills in collection + print. Until then, --json without yq still errors.
if [[ "$JSON" -eq 1 ]] && ! command -v yq >/dev/null 2>&1; then
    echo "wslutil-info: --json requires yq" >&2
    exit 1
fi

echo "wslutil-info: not implemented" >&2
exit 1
```

`chmod +x bin/wslutil-info`

Makefile: add `wslutil-info` to `CORE_SCRIPTS` (after `wslutil-doctor` is fine). Add:

```make
	install -m 0644 lib/wslutil-info.sh $(DATADIR)/lib/wslutil-info.sh
```

`bin/wslutil` — three edits:

1. Bare usage: `{doctor|info|shellenv|setup|upgrade}`
2. `--help` subcommands, after doctor:

```bash
    echo "  info       Show WSL host and distro facts (read-only)"
```

3. Extra exclusion: `grep -E -v '(doctor|info|shellenv|setup|upgrade)'` in **both** the `--help` extras grep and keep the unknown-command usage line in sync:

```bash
        echo "Usage: $(basename $0) [options] {doctor|info|shellenv|setup|upgrade}"
```

(there are two usage strings with that brace list — update both)

- [ ] **Step 4: Run CLI + install tests**

Run: `./tests/run_tests.sh test_wslutil_info.bats`  
Run: `./tests/run_tests.sh test_make_install.bats`

Expected: help/dispatch PASS. The stub still exits 1 with no args — do **not** add a no-args success test until Task 3.

- [ ] **Step 5: Commit**

```bash
git add bin/wslutil-info bin/wslutil Makefile tests/test_wslutil_info.bats tests/test_make_install.bats
git commit -m "$(cat <<'EOF'
feat: add wslutil info CLI skeleton and install

EOF
)"
```

---

### Task 3: Host versions + runtime (injectable commands)

**Files:**
- Modify: `lib/wslutil-info.sh` (collect + human print)
- Modify: `bin/wslutil-info` (call collect/print instead of stub)
- Modify: `tests/test_wslutil_info.bats`

**Interfaces:**
- Consumes: CLI `JSON` / `DISTRO` from Task 2
- Produces:
  - Commands overridable: `WSLUTIL_INFO_WSLINFO` (default `wslinfo`), `WSLUTIL_INFO_WSL` (default `wsl.exe`), `WSLUTIL_INFO_WIN_UTF8` (default `$ _wsu_bin/win-utf8` or `win-utf8`)
  - `wslutil_info_collect_versions` — sets `INFO_VER_WSL INFO_VER_WSL_EXE INFO_VER_KERNEL INFO_VER_WSLG INFO_VER_MSRDC INFO_VER_D3D INFO_VER_DXCORE INFO_VER_WINDOWS` (`""` means unavailable)
  - `wslutil_info_collect_runtime` — sets `INFO_RT_NET INFO_RT_VMID INFO_RT_MSAL`
  - `wslutil_info_print_human_host_versions` / `wslutil_info_print_human_runtime` write to stdout

- [ ] **Step 1: Tests with fakebin**

Append:

```bash
make_fakebin() {
    FAKEBIN="$TEST_TEMP_DIR/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/wslinfo" <<'EOF'
#!/bin/bash
case "$1" in
--version) echo "2.7.12.0" ;;
--networking-mode) echo "mirrored" ;;
--vm-id) echo "{11111111-2222-3333-4444-555555555555}" ;;
--msal-proxy-path) echo "/mnt/c/fake/msal" ;;
*) exit 1 ;;
esac
EOF
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    cat <<'VER'
WSL version: 2.7.12.0
Kernel version: 6.18.33.2-2
WSLg version: 1.0.73.2
MSRDC version: 1.2.7214
Direct3D version: 1.611.1-81528511
DXCore version: 10.0.26100.1-240331-1435.ge-release
Windows version: 10.0.26200.9106
VER
    exit 0
fi
exit 1
EOF
    chmod +x "$FAKEBIN/wslinfo" "$FAKEBIN/wsl.exe"
}

@test "human report prints wslinfo version and networkingMode" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSLUTIL_INFO_SKIP_DISTRO=1
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "2.7.12.0" ]]
    [[ "$output" =~ "mirrored" ]]
    [[ "$output" =~ "1.0.73.2" ]]
}
```

`WSLUTIL_INFO_SKIP_CONFIG=1` and `WSLUTIL_INFO_SKIP_DISTRO=1` are test hooks: when set, skip those blocks so this test does not need registry/crudini. Implement them in `bin/wslutil-info`.

- [ ] **Step 2: Run — expect fail (stub still exits 1)**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL `not implemented` or status 1

- [ ] **Step 3: Collectors + human host print**

Add to `lib/wslutil-info.sh`:

```bash
wslutil_info_cmd_wslinfo() { echo "${WSLUTIL_INFO_WSLINFO:-wslinfo}"; }
wslutil_info_cmd_wsl() { echo "${WSLUTIL_INFO_WSL:-wsl.exe}"; }
wslutil_info_cmd_win_utf8() {
    if [[ -n "${WSLUTIL_INFO_WIN_UTF8:-}" ]]; then
        echo "$WSLUTIL_INFO_WIN_UTF8"
        return
    fi
    local b="${_wsu_bin:-}"
    if [[ -n "$b" && -x "$b/win-utf8" ]]; then
        echo "$b/win-utf8"
    else
        echo "win-utf8"
    fi
}

wslutil_info_collect_versions() {
    INFO_VER_WSL=""
    INFO_VER_WSL_EXE=""
    INFO_VER_KERNEL=""
    INFO_VER_WSLG=""
    INFO_VER_MSRDC=""
    INFO_VER_D3D=""
    INFO_VER_DXCORE=""
    INFO_VER_WINDOWS=""
    local wi ws u8
    wi="$(wslutil_info_cmd_wslinfo)"
    ws="$(wslutil_info_cmd_wsl)"
    u8="$(wslutil_info_cmd_win_utf8)"
    if command -v "$wi" >/dev/null 2>&1 || [[ -x "$wi" ]]; then
        INFO_VER_WSL="$("$wi" --version 2>/dev/null | tr -d '\r' || true)"
    fi
    local ver
    if ver="$("$ws" --version 2>/dev/null | "$u8" 2>/dev/null || true)"; then
        INFO_VER_WSL_EXE="$(printf '%s\n' "$ver" | awk -F': ' '/^WSL version:/ {print $2; exit}')"
        INFO_VER_KERNEL="$(printf '%s\n' "$ver" | awk -F': ' '/^Kernel version:/ {print $2; exit}')"
        INFO_VER_WSLG="$(printf '%s\n' "$ver" | awk -F': ' '/^WSLg version:/ {print $2; exit}')"
        INFO_VER_MSRDC="$(printf '%s\n' "$ver" | awk -F': ' '/^MSRDC version:/ {print $2; exit}')"
        INFO_VER_D3D="$(printf '%s\n' "$ver" | awk -F': ' '/^Direct3D version:/ {print $2; exit}')"
        INFO_VER_DXCORE="$(printf '%s\n' "$ver" | awk -F': ' '/^DXCore version:/ {print $2; exit}')"
        INFO_VER_WINDOWS="$(printf '%s\n' "$ver" | awk -F': ' '/^Windows version:/ {print $2; exit}')"
    fi
}

wslutil_info_collect_runtime() {
    INFO_RT_NET=""
    INFO_RT_VMID=""
    INFO_RT_MSAL=""
    local wi
    wi="$(wslutil_info_cmd_wslinfo)"
    if ! command -v "$wi" >/dev/null 2>&1 && [[ ! -x "$wi" ]]; then
        return 0
    fi
    INFO_RT_NET="$("$wi" --networking-mode 2>/dev/null | tr -d '\r' || true)"
    INFO_RT_VMID="$("$wi" --vm-id 2>/dev/null | tr -d '\r' || true)"
    INFO_RT_MSAL="$("$wi" --msal-proxy-path 2>/dev/null | tr -d '\r' || true)"
}

wslutil_info_or_unavail() {
    if [[ -n "${1:-}" ]]; then
        printf '%s' "$1"
    else
        printf 'unavailable'
    fi
}

wslutil_info_print_human_host_versions() {
    printf '== Host ==\n'
    printf 'Versions\n'
    printf '  WSL:       %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WSL:-}")"
    if [[ -n "${INFO_VER_WSL:-}" && -n "${INFO_VER_WSL_EXE:-}" && "${INFO_VER_WSL}" != "${INFO_VER_WSL_EXE}" ]]; then
        printf '  WSL (exe): %s  (mismatch)\n' "$INFO_VER_WSL_EXE"
    fi
    printf '  Kernel:    %s\n' "$(wslutil_info_or_unavail "${INFO_VER_KERNEL:-}")"
    printf '  WSLg:      %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WSLG:-}")"
    printf '  MSRDC:     %s\n' "$(wslutil_info_or_unavail "${INFO_VER_MSRDC:-}")"
    printf '  Direct3D:  %s\n' "$(wslutil_info_or_unavail "${INFO_VER_D3D:-}")"
    printf '  DXCore:    %s\n' "$(wslutil_info_or_unavail "${INFO_VER_DXCORE:-}")"
    printf '  Windows:   %s\n' "$(wslutil_info_or_unavail "${INFO_VER_WINDOWS:-}")"
}

wslutil_info_print_human_runtime() {
    printf 'Runtime\n'
    printf '  networkingMode:  %s\n' "$(wslutil_info_or_unavail "${INFO_RT_NET:-}")"
    printf '  configured:      %s\n' "${INFO_RT_NET_CFG:-unset (default nat)}"
    printf '  vmId:            %s\n' "$(wslutil_info_or_unavail "${INFO_RT_VMID:-}")"
    printf '  msalProxyPath:   %s\n' "$(wslutil_info_or_unavail "${INFO_RT_MSAL:-}")"
}
```

Replace the stub at the end of `bin/wslutil-info` with:

```bash
wslutil_info_collect_versions
wslutil_info_collect_runtime
# INFO_RT_NET_CFG filled in Task 4; until then leave unset → "unset (default nat)"

if [[ "$JSON" -eq 1 ]]; then
    echo "wslutil-info: --json not implemented" >&2
    exit 1
fi

wslutil_info_print_human_host_versions
wslutil_info_print_human_runtime
if [[ "${WSLUTIL_INFO_SKIP_CONFIG:-0}" != 1 ]]; then
    : # Task 4
fi
if [[ "${WSLUTIL_INFO_SKIP_DISTRO:-0}" != 1 ]]; then
    : # Task 5
fi
exit 0
```

Empty `INFO_RT_NET_CFG` is OK for this task; Task 4 sets it from `.wslconfig`.

- [ ] **Step 4: Run tests**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: PASS including fakebin human report. Filter tests still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-info.sh bin/wslutil-info tests/test_wslutil_info.bats
git commit -m "$(cat <<'EOF'
feat: collect WSL versions and wslinfo runtime in wslutil info

EOF
)"
```

---

### Task 4: Config files + non-default filter + configured networkingMode

**Files:**
- Modify: `lib/wslutil-info.sh`
- Modify: `bin/wslutil-info` (bootstrap `WIN_USERPROFILE`, print config blocks)
- Modify: `tests/test_wslutil_info.bats`

**Interfaces:**
- Consumes: `wslutil_info_should_omit`, `wslutil_info_documented_default`
- Produces:
  - `wslutil_info_filter_ini_file kind path` — prints lines `section<TAB>key<TAB>value<TAB>default` for kept keys (kind `wslconfig` or `wslconf`). Missing file → no lines.
  - `wslutil_info_filter_wslgconfig path` — prints `system-distro-env<TAB>key<TAB>value` for every key present
  - Sets `INFO_RT_NET_CFG` to the live `[wsl2] networkingMode` value or empty
  - `wslutil_info_print_human_config` 

Requires `crudini` to parse. If missing, print `unavailable (need crudini)` for the body.

- [ ] **Step 1: Filter-file + human config tests**

```bash
@test "filter_ini_file omits default guiApplications and keeps false" {
    skip_if_no_crudini() { command -v crudini >/dev/null || skip "need crudini"; }
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    local f="$TEST_TEMP_DIR/.wslconfig"
    cat >"$f" <<'EOF'
[wsl2]
guiApplications=true
memory=4GB
EOF
    run wslutil_info_filter_ini_file wslconfig "$f"
    [ "$status" -eq 0 ]
    [[ "$output" != *"guiApplications"* ]]
    [[ "$output" =~ "memory" ]]
    [[ "$output" =~ "4GB" ]]
}

@test "human report shows .wslconfig path and non-default memory" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_DISTRO=1
    export WIN_USERPROFILE="$TEST_TEMP_DIR/winhome"
    mkdir -p "$WIN_USERPROFILE"
    cat >"$WIN_USERPROFILE/.wslconfig" <<'EOF'
[wsl2]
networkingMode=mirrored
memory=4GB
guiApplications=true
EOF
    command -v crudini >/dev/null 2>&1 || skip "need crudini"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "4GB" ]]
    [[ "$output" != *"guiApplications"* ]]
    [[ "$output" =~ "configured:" ]]
    [[ "$output" =~ "mirrored" ]]
}
```

Define `make_fakebin` once (Task 3); do not duplicate if already present.

- [ ] **Step 2: Run — expect fail (no filter_ini_file)**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL

- [ ] **Step 3: Implement INI filter + print**

```bash
wslutil_info_filter_ini_file() {
    local kind="$1" path="$2"
    [[ -f "$path" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    local section key value def
    while IFS= read -r section; do
        [[ -n "$section" ]] || continue
        while IFS= read -r key; do
            [[ -n "$key" ]] || continue
            value="$(crudini --get "$path" "$section" "$key" 2>/dev/null || true)"
            if wslutil_info_should_omit "$kind" "$section" "$key" "$value"; then
                continue
            fi
            def="$(wslutil_info_documented_default "$kind" "$section" "$key" 2>/dev/null || echo "")"
            printf '%s\t%s\t%s\t%s\n' "$section" "$key" "$value" "$def"
        done < <(crudini --get "$path" "$section" 2>/dev/null || true)
    done < <(crudini --get "$path" 2>/dev/null || true)
}

wslutil_info_filter_wslgconfig() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    command -v crudini >/dev/null 2>&1 || return 0
    local key value
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        value="$(crudini --get "$path" "system-distro-env" "$key" 2>/dev/null || true)"
        printf 'system-distro-env\t%s\t%s\n' "$key" "$value"
    done < <(crudini --get "$path" "system-distro-env" 2>/dev/null || true)
}

wslutil_info_print_human_ini_block() {
    local title="$1" winpath="$2" wslpath="$3" kind="$4" path="$5"
    printf '%s\n' "$title"
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ ! -e "$path" ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if ! command -v crudini >/dev/null 2>&1; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    local lines
    lines="$(wslutil_info_filter_ini_file "$kind" "$path")"
    if [[ -z "$lines" ]]; then
        printf '  (all defaults)\n'
        return 0
    fi
    local lastsec="" section key value def
    while IFS=$'\t' read -r section key value def; do
        if [[ "$section" != "$lastsec" ]]; then
            printf '  [%s]\n' "$section"
            lastsec="$section"
        fi
        if [[ -n "$def" ]]; then
            printf '    %s = %s  (default: %s)\n' "$key" "$value" "$def"
        else
            printf '    %s = %s\n' "$key" "$value"
        fi
    done <<<"$lines"
}

wslutil_info_print_human_wslg() {
    local winpath="$1" wslpath="$2" path="$3"
    printf '.wslgconfig\n'
    printf '  windows: %s\n' "$winpath"
    printf '  wsl:     %s\n' "$wslpath"
    if [[ ! -e "$path" ]]; then
        printf '  exists:  no\n'
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  exists:  yes\n'
    if ! command -v crudini >/dev/null 2>&1; then
        printf '  unavailable (need crudini)\n'
        return 0
    fi
    local lines
    lines="$(wslutil_info_filter_wslgconfig "$path")"
    if [[ -z "$lines" ]]; then
        printf '  (all defaults)\n'
        return 0
    fi
    printf '  [system-distro-env]\n'
    local _s key value
    while IFS=$'\t' read -r _s key value; do
        printf '    %s = %s\n' "$key" "$value"
    done <<<"$lines"
}
```

In `bin/wslutil-info`, after sourcing libs, if `WIN_USERPROFILE` is unset and `WSLUTIL_INFO_SKIP_CONFIG` is not 1, source `wslutil-setup-common.sh` (same checkout vs packaged path as paths helper) and call `bootstrap_win_env_if_needed`.

After `collect_runtime`, set configured networking:

```bash
INFO_RT_NET_CFG=""
if [[ "${WSLUTIL_INFO_SKIP_CONFIG:-0}" != 1 && -n "${WIN_USERPROFILE:-}" && -f "$WIN_USERPROFILE/.wslconfig" ]] && command -v crudini >/dev/null 2>&1; then
    INFO_RT_NET_CFG="$(crudini --get "$WIN_USERPROFILE/.wslconfig" wsl2 networkingMode 2>/dev/null || true)"
fi
```

`wslutil_info_print_human_runtime` already uses `INFO_RT_NET_CFG` with fallback `unset (default nat)`. If `INFO_RT_NET_CFG` is set, print that value (not the fallback).

Replace the Task 3 config skip placeholder with:

```bash
if [[ "${WSLUTIL_INFO_SKIP_CONFIG:-0}" != 1 ]]; then
    local_wslc="${WIN_USERPROFILE:-}/.wslconfig"
    local_wslg="${WIN_USERPROFILE:-}/.wslgconfig"
    win_wslc="unavailable"
    win_wslg="unavailable"
    if [[ -n "${WIN_USERPROFILE:-}" ]]; then
        win_wslc="$(wslpath -w "$local_wslc" 2>/dev/null || echo "$local_wslc")"
        win_wslg="$(wslpath -w "$local_wslg" 2>/dev/null || echo "$local_wslg")"
    fi
    wslutil_info_print_human_ini_block ".wslconfig" "$win_wslc" "$local_wslc" wslconfig "$local_wslc"
    wslutil_info_print_human_wslg "$win_wslg" "$local_wslg" "$local_wslg"
fi
```

If `WIN_USERPROFILE` is still empty, print `.wslconfig` / `.wslgconfig` with `exists: no` / paths `unavailable`.

- [ ] **Step 4: Run tests**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-info.sh bin/wslutil-info tests/test_wslutil_info.bats
git commit -m "$(cat <<'EOF'
feat: show non-default .wslconfig and .wslgconfig in wslutil info

EOF
)"
```

---

### Task 5: Distro block, `--distro`, registry VHD path

**Files:**
- Modify: `lib/wslutil-info.sh`
- Modify: `bin/wslutil-info`
- Modify: `tests/test_wslutil_info.bats`

**Interfaces:**
- Consumes: `DISTRO` from CLI; `WSLUTIL_INFO_WSL`; `WSLUTIL_INFO_WIN_UTF8`
- Produces:
  - `WSLUTIL_INFO_LXSS` — if set, read that TSV file instead of PowerShell (`name<TAB>basePath<TAB>version<TAB>defaultUid` per line). Strip a `\\?\` prefix from basePath if present.
  - `wslutil_info_list_distros` — parses `wsl.exe -l -v` into lines `name<TAB>state<TAB>version<TAB>default` (`default` is `yes`/`no`)
  - `wslutil_info_resolve_distro` — given requested name or `$WSL_DISTRO_NAME`; unknown → return 1
  - `wslutil_info_print_human_distro`
  - `wsl.conf` via `/etc/wsl.conf` if current; else if state is Running, `$WIN_USERPROFILE` not needed — try `"$(wslpath -u '\\wsl.localhost\'"$name"'/etc/wsl.conf' 2>/dev/null || echo "")"`. Stopped + not current → `INFO_WSLCONF_REASON="distro not running"`
  - Must not invoke `"$ws" -d` or `--mount`

- [ ] **Step 1: Tests**

Extend fake `wsl.exe` from `make_fakebin` so `-l -v` / `--list` `--verbose` work. Easiest: replace the fake with a dispatcher:

```bash
    cat >"$FAKEBIN/wsl.exe" <<'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    cat <<'VER'
WSL version: 2.7.12.0
Kernel version: 6.18.33.2-2
WSLg version: 1.0.73.2
MSRDC version: 1.2.7214
Direct3D version: 1.611.1-81528511
DXCore version: 10.0.26100.1-240331-1435.ge-release
Windows version: 10.0.26200.9106
VER
    exit 0
fi
if [[ "$1" == "-l" || "$1" == "--list" ]]; then
    # UTF-8 is fine; tests set WSLUTIL_INFO_WIN_UTF8=cat
    cat <<'LST'
  NAME      STATE           VERSION
* Ubuntu    Running         2
  Debian    Stopped         2
LST
    exit 0
fi
echo "unexpected: $*" >&2
exit 1
EOF
```

Append tests:

```bash
@test "unknown --distro exits 1 and lists names" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro NoSuchDistro
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Ubuntu" || "$stderr" =~ "Ubuntu" ]]
}

@test "distro block includes VHD path from Lxss TSV" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\AppData\\Local\\Packages\\Ubuntu\\LocalState\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ext4.vhdx" ]]
    [[ "$output" =~ "Ubuntu" ]]
    [[ "$output" =~ "Running" ]]
}

@test "stopped other distro does not call wsl.exe -d" {
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Debian\tC:\\wsldisks\\Debian\t2\t1000\nUbuntu\tC:\\u\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --distro Debian
    [ "$status" -eq 0 ]
    [[ "$output" =~ "distro not running" ]]
    [[ "$output" != *"-d Debian"* ]]
}
```

BATS `run` merges stderr into `$output` by default unless `run --separate-stderr` (bats 1.5+). Assert on `$output` for the unknown-distro names. Do not use `$stderr` unless you pass `--separate-stderr`.

Fix the unknown-distro test to:

```bash
    [[ "$output" =~ "Ubuntu" ]]
```

and print names on stderr **and** they will show in `$output` with default `run`. Spec says stderr — implementers must `echo ... >&2`. Default BATS still captures it.

- [ ] **Step 2: Run — expect fail**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL unknown `--distro` (currently “unknown option” or success stub) and missing VHD line

- [ ] **Step 3: Implement list / registry / print**

Parse `wsl.exe -l -v`: skip header (`NAME` / `STATE`). `*` in column 0 means default. Names may contain spaces — use `awk` with the default `wsl.exe -l -v` table (NAME, STATE, VERSION). The fake matches that layout.

```bash
wslutil_info_list_distros() {
    local ws u8 raw
    ws="$(wslutil_info_cmd_wsl)"
    u8="$(wslutil_info_cmd_win_utf8)"
    raw="$("$ws" -l -v 2>/dev/null | "$u8" 2>/dev/null || true)"
    printf '%s\n' "$raw" | awk '
        BEGIN { IGNORECASE=1 }
        NR==1 && /NAME/ { next }
        {
            def="no"
            if ($1=="*") { def="yes"; $1="" ; sub(/^ +/, "") }
            name=$1; state=$(NF-1); ver=$NF
            # if name has no spaces this is enough for v1 (Ubuntu, Debian, Ubuntu-24.04)
            print name "\t" state "\t" ver "\t" def
        }'
}

wslutil_info_lxss_lookup() {
    # stdout: basePath<TAB>version<TAB>uid  for exact name match
    local want="$1" line n b v u
    if [[ -n "${WSLUTIL_INFO_LXSS:-}" && -f "$WSLUTIL_INFO_LXSS" ]]; then
        while IFS=$'\t' read -r n b v u; do
            if [[ "$n" == "$want" ]]; then
                b="${b#\\\\?\\}"
                printf '%s\t%s\t%s\n' "$b" "$v" "$u"
                return 0
            fi
        done <"$WSLUTIL_INFO_LXSS"
        return 1
    fi
    local ps out
    ps="$(command -v powershell.exe 2>/dev/null || true)"
    [[ -n "$ps" ]] || return 1
    out="$("$ps" -NoProfile -Command "Get-ChildItem HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Lxss | ForEach-Object { \$n = \$_.GetValue('DistributionName'); if (\$n) { \$n + [char]9 + \$_.GetValue('BasePath') + [char]9 + \$_.GetValue('Version') + [char]9 + \$_.GetValue('DefaultUid') } }" 2>/dev/null | "$(wslutil_info_cmd_win_utf8)" || true)"
    while IFS=$'\t' read -r n b v u; do
        if [[ "$n" == "$want" ]]; then
            b="${b#\\\\?\\}"
            printf '%s\t%s\t%s\n' "$b" "$v" "$u"
            return 0
        fi
    done <<<"$out"
    return 1
}
```

In `bin/wslutil-info`, after host print:

```bash
if [[ "${WSLUTIL_INFO_SKIP_DISTRO:-0}" != 1 ]]; then
    mapfile -t _info_dlist < <(wslutil_info_list_distros)
    target="${DISTRO:-${WSL_DISTRO_NAME:-}}"
    if [[ -z "$target" ]]; then
        printf '== Distro ==\n  unavailable (WSL_DISTRO_NAME unset)\n'
    else
        found=0
        for row in "${_info_dlist[@]}"; do
            IFS=$'\t' read -r dname dstate dver ddef <<<"$row"
            if [[ "$dname" == "$target" ]]; then
                found=1
                break
            fi
        done
        if [[ "$found" -eq 0 ]]; then
            echo "wslutil-info: unknown distro: $target" >&2
            echo "Available:" >&2
            for row in "${_info_dlist[@]}"; do
                IFS=$'\t' read -r dname _rest <<<"$row"
                echo "  $dname" >&2
            done
            exit 1
        fi
        # lookup lxss, print block, wsl.conf rules as spec
        wslutil_info_print_human_distro "$target" "$dstate" "$dver" "$ddef"
    fi
fi
```

Add `wslutil_info_print_human_distro` to `lib/wslutil-info.sh`:

```bash
wslutil_info_print_human_distro() {
    local name="$1" state="$2" ver="$3" def="$4"
    local cur=""
    [[ "$name" == "${WSL_DISTRO_NAME:-}" ]] && cur=" (current)"
    local base uid lxver vhd_win vhd_wsl
    base=""; uid=""; lxver=""
    if lx="$(wslutil_info_lxss_lookup "$name")"; then
        IFS=$'\t' read -r base lxver uid <<<"$lx"
    fi
    vhd_win=""
    vhd_wsl=""
    if [[ -n "$base" ]]; then
        vhd_win="${base}\\ext4.vhdx"
        vhd_wsl="$(wslpath -u "$vhd_win" 2>/dev/null || true)"
    fi
    printf '== Distro: %s%s ==\n' "$name" "$cur"
    printf '  state:      %s\n' "$state"
    printf '  wsl:        %s\n' "$ver"
    printf '  default:    %s\n' "$def"
    printf '  vhd:        %s\n' "$(wslutil_info_or_unavail "$vhd_win")"
    printf '  defaultUid: %s\n' "$(wslutil_info_or_unavail "$uid")"

    local confpath="" reason=""
    if [[ "$name" == "${WSL_DISTRO_NAME:-}" ]]; then
        confpath="/etc/wsl.conf"
        wslutil_info_print_human_ini_block "wsl.conf" "$confpath" "$confpath" wslconf "$confpath"
        return 0
    fi
    if [[ "${state,,}" == "running" ]]; then
        confpath="$(wslpath -u "\\\\wsl.localhost\\${name}\\etc\\wsl.conf" 2>/dev/null || true)"
        if [[ -n "$confpath" && -r "$confpath" ]]; then
            wslutil_info_print_human_ini_block "wsl.conf" "$confpath" "$confpath" wslconf "$confpath"
            return 0
        fi
        reason="unreadable"
    else
        reason="distro not running"
    fi
    printf '  wsl.conf:   unavailable (%s)\n' "$reason"
}
```

Set JSON globals in the same function (or the caller) when Task 6 lands: `INFO_DISTRO_NAME`, `INFO_DISTRO_STATE`, `INFO_DISTRO_VHD_WIN`, `INFO_WSLCONF_REASON`, etc. Task 5 only needs human print.

- [ ] **Step 4: Run tests**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-info.sh bin/wslutil-info tests/test_wslutil_info.bats
git commit -m "$(cat <<'EOF'
feat: add distro block and --distro to wslutil info

EOF
)"
```

---

### Task 6: `--json`, live smoke, README

**Files:**
- Modify: `lib/wslutil-info.sh` (`wslutil_info_emit_json`)
- Modify: `bin/wslutil-info` (call emit instead of human when `JSON=1`)
- Modify: `tests/test_wslutil_info.bats`
- Modify: `README.md` (command table + one example)
- Modify: `tests/README.md` (one bullet for `test_wslutil_info.bats`)

**Interfaces:**
- Consumes: all `INFO_*` globals and distro locals already collected
- Produces: JSON tree per spec (`host.versions`, `host.runtime`, `host.wslconfig`, `host.wslgconfig`, `distro`). Empty strings → `null` via `yq`. `wslconf.available` false with `reason` when skipped.

- [ ] **Step 1: JSON tests**

`--json` without `yq` already exits 1 in Task 2’s CLI parse. Do not add a PATH-hiding test.

```bash
@test "--json has host and distro keys" {
    command -v yq >/dev/null 2>&1 || skip "need yq"
    make_fakebin
    export WSLUTIL_INFO_WSLINFO="$FAKEBIN/wslinfo"
    export WSLUTIL_INFO_WSL="$FAKEBIN/wsl.exe"
    export WSLUTIL_INFO_WIN_UTF8="cat"
    export WSLUTIL_INFO_SKIP_CONFIG=1
    export WSL_DISTRO_NAME="Ubuntu"
    export WSLUTIL_INFO_LXSS="$TEST_TEMP_DIR/lxss.tsv"
    printf 'Ubuntu\tC:\\Users\\foo\\LocalState\t2\t1000\n' >"$WSLUTIL_INFO_LXSS"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    echo "$output" | yq eval '.host.versions.wsl' - | grep -q '2.7.12.0'
    echo "$output" | yq eval '.host.runtime.networkingMode' - | grep -q 'mirrored'
    echo "$output" | yq eval '.distro.name' - | grep -q 'Ubuntu'
}

@test "live wslutil info --json parses" {
    skip_if_not_wsl
    command -v yq >/dev/null 2>&1 || skip "need yq"
    run "$BATS_TEST_DIRNAME/../bin/wslutil-info" --json
    [ "$status" -eq 0 ]
    echo "$output" | yq eval '.host' - >/dev/null
    echo "$output" | yq eval '.distro' - >/dev/null
}
```

- [ ] **Step 2: Run — expect `--json not implemented`**

Run: `./tests/run_tests.sh test_wslutil_info.bats`

Expected: FAIL on `--json has host and distro keys`

- [ ] **Step 3: Emit JSON with `yq eval -n -o json`**

Build a temp YAML file (quote strings with `yq eval --arg`):

```bash
wslutil_info_emit_json() {
    local tmp
    tmp="$(mktemp)"
    yq eval -n --arg wsl "${INFO_VER_WSL}" \
        --arg wslexe "${INFO_VER_WSL_EXE}" \
        --arg kernel "${INFO_VER_KERNEL}" \
        --arg wslg "${INFO_VER_WSLG}" \
        --arg msrdc "${INFO_VER_MSRDC}" \
        --arg d3d "${INFO_VER_D3D}" \
        --arg dxcore "${INFO_VER_DXCORE}" \
        --arg win "${INFO_VER_WINDOWS}" \
        --arg net "${INFO_RT_NET}" \
        --arg netcfg "${INFO_RT_NET_CFG}" \
        --arg vmid "${INFO_RT_VMID}" \
        --arg msal "${INFO_RT_MSAL}" \
        '
        .host.versions.wsl = ($wsl | select(length > 0) // null) |
        .host.versions.wslExe = ($wslexe | select(length > 0) // null) |
        .host.versions.mismatch = (($wsl | length > 0) and ($wslexe | length > 0) and $wsl != $wslexe) |
        .host.versions.kernel = ($kernel | select(length > 0) // null) |
        .host.versions.wslg = ($wslg | select(length > 0) // null) |
        .host.versions.msrdc = ($msrdc | select(length > 0) // null) |
        .host.versions.direct3d = ($d3d | select(length > 0) // null) |
        .host.versions.dxcore = ($dxcore | select(length > 0) // null) |
        .host.versions.windows = ($win | select(length > 0) // null) |
        .host.runtime.networkingMode = ($net | select(length > 0) // null) |
        .host.runtime.configuredNetworkingMode = ($netcfg | select(length > 0) // null) |
        .host.runtime.vmId = ($vmid | select(length > 0) // null) |
        .host.runtime.msalProxyPath = ($msal | select(length > 0) // null) |
        .host.wslconfig = {"windowsPath": null, "wslPath": null, "exists": false, "sections": {}} |
        .host.wslgconfig = {"windowsPath": null, "wslPath": null, "exists": false, "sections": {}} |
        .distro = {"name": null}
        ' >"$tmp"

    yq eval -i \
        --arg wp "${INFO_WSLCONFIG_WIN:-}" --arg lp "${INFO_WSLCONFIG_WSL:-}" \
        --argjson ex "$( [[ "${INFO_WSLCONFIG_EXISTS:-0}" == 1 ]] && echo true || echo false )" \
        '.host.wslconfig.windowsPath = ($wp | select(length>0) // null) |
         .host.wslconfig.wslPath = ($lp | select(length>0) // null) |
         .host.wslconfig.exists = $ex' "$tmp"

    local section key value def _s
    while IFS=$'\t' read -r section key value def; do
        [[ -n "${section:-}" ]] || continue
        yq eval -i --arg s "$section" --arg k "$key" --arg v "$value" --arg d "$def" \
            '.host.wslconfig.sections[$s][$k] = {"value": $v, "default": $d}' "$tmp"
    done <<<"${INFO_WSLCONFIG_LINES:-}"

    yq eval -i \
        --arg wp "${INFO_WSLGCONFIG_WIN:-}" --arg lp "${INFO_WSLGCONFIG_WSL:-}" \
        --argjson ex "$( [[ "${INFO_WSLGCONFIG_EXISTS:-0}" == 1 ]] && echo true || echo false )" \
        '.host.wslgconfig.windowsPath = ($wp | select(length>0) // null) |
         .host.wslgconfig.wslPath = ($lp | select(length>0) // null) |
         .host.wslgconfig.exists = $ex' "$tmp"

    while IFS=$'\t' read -r _s key value; do
        [[ -n "${key:-}" ]] || continue
        yq eval -i --arg k "$key" --arg v "$value" \
            '.host.wslgconfig.sections["system-distro-env"][$k] = $v' "$tmp"
    done <<<"${INFO_WSLG_LINES:-}"

    yq eval -i \
        --arg n "${INFO_DISTRO_NAME:-}" \
        --argjson cur "$( [[ "${INFO_DISTRO_CURRENT:-0}" == 1 ]] && echo true || echo false )" \
        --argjson defl "$( [[ "${INFO_DISTRO_DEFAULT:-0}" == 1 ]] && echo true || echo false )" \
        --arg st "${INFO_DISTRO_STATE:-}" \
        --argjson ver "${INFO_DISTRO_VER:-null}" \
        --arg vhdw "${INFO_DISTRO_VHD_WIN:-}" --arg vhdl "${INFO_DISTRO_VHD_WSL:-}" \
        --argjson uid "${INFO_DISTRO_UID:-null}" \
        '.distro.name = ($n | select(length>0) // null) |
         .distro.current = $cur |
         .distro.default = $defl |
         .distro.state = ($st | select(length>0) // null) |
         .distro.wslVersion = $ver |
         .distro.vhd.windowsPath = ($vhdw | select(length>0) // null) |
         .distro.vhd.wslPath = ($vhdl | select(length>0) // null) |
         .distro.defaultUid = $uid' "$tmp"

    if [[ "${INFO_WSLCONF_AVAILABLE:-0}" == 1 ]]; then
        yq eval -i --arg p "${INFO_WSLCONF_PATH:-}" \
            '.distro.wslconf = {"available": true, "path": $p, "exists": true, "sections": {}}' "$tmp"
        while IFS=$'\t' read -r section key value def; do
            [[ -n "${section:-}" ]] || continue
            yq eval -i --arg s "$section" --arg k "$key" --arg v "$value" --arg d "$def" \
                '.distro.wslconf.sections[$s][$k] = {"value": $v, "default": $d}' "$tmp"
        done <<<"${INFO_WSLCONF_LINES:-}"
    else
        yq eval -i --arg r "${INFO_WSLCONF_REASON:-unavailable}" \
            '.distro.wslconf = {"available": false, "reason": $r}' "$tmp"
    fi

    yq eval -o json '.' "$tmp"
    rm -f "$tmp"
}
```

Wire `bin/wslutil-info`: collect **everything first** (versions, runtime, config paths, distro fields) into the same globals used by human print, then:

```bash
if [[ "$JSON" -eq 1 ]]; then
    wslutil_info_emit_json
    exit 0
fi
# existing human prints
```

Do not print human and JSON together. Collect before either emit so `--json` is not a second code path that re-queries.

If mikefarah `select(length > 0) // null` misbehaves on your yq version, empty-check in bash and pass the literal `null` with `yq eval -n 'null'` / `--argjson`.

README.md — add a table row after doctor:

```markdown
| `wslutil info` | Show WSL versions, live networking, config paths, distro VHD path |
```

And under Usage:

```bash
wslutil info                      # Host + this distro
wslutil info --json               # Same tree as JSON
wslutil info --distro Debian      # Host + named distro (no start/mount)
```

`tests/README.md` — add:

```markdown
- **`test_wslutil_info.bats`** - Tests for wslutil-info filter, CLI, and JSON
```

- [ ] **Step 4: Run all related tests**

Run: `./tests/run_tests.sh test_wslutil_info.bats`  
Run: `./tests/run_tests.sh test_make_install.bats`

Expected: PASS. Live JSON smoke passes on this WSL machine.

- [ ] **Step 5: Commit**

```bash
git add lib/wslutil-info.sh bin/wslutil-info tests/test_wslutil_info.bats README.md tests/README.md
git commit -m "$(cat <<'EOF'
feat: emit wslutil info JSON and document the command

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec item | Task |
|-----------|------|
| `wslutil info` / `wslutil-info` only | 2 |
| No default dump sections; two blocks | 3–5 |
| `--json` / `--distro` | 2, 5, 6 |
| Versions from `wslinfo` + `wsl.exe --version` + `win-utf8`; mismatch | 3 |
| Runtime from `wslinfo` only | 3 |
| Configured `networkingMode` pair | 4 |
| Non-default `.wslconfig` / `wsl.conf`; always-show formulas; `.wslgconfig` all keys | 1, 4, 5 |
| Registry VHD path; `--distro`; stopped → no start/mount | 5 |
| `yq` JSON; missing `yq` → exit 1 | 6 / 2 |
| Makefile + help list | 2 |
| doctor unchanged | (no task touches `bin/wslutil-doctor`) |
| Filter tests + unknown distro + live JSON smoke | 1, 5, 6 |
