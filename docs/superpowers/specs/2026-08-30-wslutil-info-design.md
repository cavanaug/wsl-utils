# `wslutil info` — read-only WSL environment report

**Date:** 2026-08-30  
**Status:** Approved  
**Related:** `bin/wslutil` dispatcher, `bin/wslutil-doctor` (health checks, not an inventory)

## Problem

`wsl.exe` does not answer the questions people actually have: package and WSLg versions as a set, live networking mode, where `.wslconfig` / `.wslgconfig` live on the Windows filesystem, or where a distro’s `ext4.vhdx` is stored. Config files are intent after a restart; `wslinfo` is what is running now. Those two disagree after edits, and there is no one command that prints both.

`wslutil doctor` is a pass/fail health check. It must not become this inventory.

## Goals

- One read-only command: `wslutil info` (binary `wslutil-info`).
- Default report for **this** running distro plus **host-global** facts.
- `--distro NAME` swaps only the distro block.
- Human output by default; `--json` is the same tree.
- Runtime from `wslinfo` whenever it can answer. Config is labeled as written intent and is never used as a stand-in for a missing runtime value.
- Config files: show only keys that **differ from Microsoft defaults** (plus a small always-show-if-present set).
- Distro VHD path from the Windows registry (what `wsl.exe --list` hides). Do not start distros. Do not mount VHDs.

## Non-goals

- `wsl-info` as a second public name.
- Mutating operations (relocate VHD, import/register, `wsl --mount`). Those are later `wslutil` subcommands, not this spec.
- CLI sections (`info versions`, `info network`). One dump, two blocks.
- Dumping every documented `.wslconfig` key with its default.
- Computing host RAM/CPU to decide whether `memory` / `processors` / `swap` match the formula defaults.
- Changing `wslutil doctor`.
- Listing every distro in the default report.

## Decisions

| Topic | Choice |
|-------|--------|
| Public name | `wslutil info` only (`bin/wslutil-info`). Same dual invocation as `doctor`. |
| Later mutations | More `wslutil` subcommands; no `wsl-tool` / `wsl-info` product names |
| Default view | Host block + distro block for `$WSL_DISTRO_NAME` |
| Other distros | `--distro NAME` only |
| Stopped other distro | Registry + `wsl.exe -l -v` + VHD path. `wsl.conf` unavailable. Never start, never mount. |
| Running other distro | Same, plus `\\wsl.localhost\NAME\etc\wsl.conf` if readable |
| Runtime vs config | `wslinfo` is runtime. File keys are configured. Pair them only for `networkingMode`. |
| Config verbosity | Non-default keys only |
| Output | Human default; `--json` same data |
| Partial failure | Field `unavailable` / JSON `null` (or a small `available: false` object). Exit 0. |

## CLI

```text
wslutil info [--json] [--distro NAME]
wslutil-info [--json] [--distro NAME]
```

| Args | Behavior |
|------|----------|
| none | Human report, this distro |
| `--json` | Same tree on stdout |
| `--distro NAME` | Distro block is `NAME`. Host block unchanged. |
| `--help` | Usage, exit 0 |
| unknown flag or unknown distro | stderr, exit 1 (unknown distro: print `wsl.exe -l -v` names) |

Dispatcher already runs `wslutil-info` for `wslutil info`. Makefile adds `wslutil-info` to `CORE_SCRIPTS`. Add `info` to the hardcoded usage / `--help` list in `bin/wslutil` next to `doctor` (otherwise it only appears under auto-discovered extras).

## Report shape

Two blocks. No section subcommands.

```text
== Host ==
  Versions …
  Runtime …
  .wslconfig …
  .wslgconfig …

== Distro: <name> (current) ==
  state / wsl 1|2 / default / vhd / defaultUid
  /etc/wsl.conf …
```

`--distro` other than current omits `(current)` and may mark `wsl.conf` unavailable.

### Host — versions

Sources: `wslinfo --version` and `wsl.exe --version` piped through `win-utf8`.

| Field | Source |
|-------|--------|
| WSL | `wslinfo --version` (authoritative). Also the `WSL version:` line from `wsl.exe --version`. |
| Kernel | `wsl.exe --version` |
| WSLg | `wsl.exe --version` |
| MSRDC | `wsl.exe --version` |
| Direct3D | `wsl.exe --version` |
| DXCore | `wsl.exe --version` |
| Windows | `wsl.exe --version` |

If the two WSL version strings disagree, print both and mark a mismatch. Do not invent a version from a config file.

### Host — runtime

Sources: `wslinfo` only (`--networking-mode`, `--vm-id`, `--msal-proxy-path`). On current WSL this is the full `wslinfo` surface.

| Field | Rule |
|-------|------|
| `networkingMode` | Live value: `nat` / `mirrored` / `bridged` / `virtioproxy` / `none` / `wsl1` |
| `configured` | `.wslconfig` `[wsl2] networkingMode` if set, else `unset (default nat)` |
| `vmId` | `wslinfo --vm-id` |
| `msalProxyPath` | `wslinfo --msal-proxy-path` |

If `wslinfo` is missing or a flag fails, that field is `unavailable`. Do not fill it from `.wslconfig`.

This runtime `networkingMode` pair is **always** shown. It is not subject to the non-default config filter.

### Host — `.wslconfig` / `.wslgconfig`

Paths: `$WIN_USERPROFILE/.wslconfig` and `.wslgconfig` (Windows path via `wslpath -w`, WSL path as used). Bootstrap `WIN_*` with `win-env` when unset, same as setup.

For each file: windows path, WSL path, exists. Then the filtered key list, or `(all defaults)` if missing or nothing differs.

**`.wslgconfig`:** keys are `[system-distro-env]` environment variables. Unset is the default. Every key present in the file is an override — print them all. Missing/empty → `(all defaults)`.

**`.wslconfig` non-default filter:** see [Config filter](#config-filter).

### Distro block

Default name: `$WSL_DISTRO_NAME`. `--distro NAME` must match a name from `wsl.exe -l -v` (UTF-16 via `win-utf8`). Matching is as `wsl.exe` reports it.

| Field | Source |
|-------|--------|
| name | requested / current |
| current | yes iff name equals `$WSL_DISTRO_NAME` |
| default | yes iff `wsl.exe -l -v` marks it default (`*`) |
| state | Running / Stopped from `wsl.exe -l -v` |
| wsl (1 or 2) | `wsl.exe -l -v` and/or registry `Version` |
| vhd | `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\{guid}\BasePath` + `\ext4.vhdx` (Windows and WSL paths) |
| defaultUid | registry `DefaultUid` |
| wsl.conf | see below |

Registry reads: PowerShell `-NoProfile` (project convention).

**`wsl.conf`:**

- Current distro: `/etc/wsl.conf`, filtered keys.
- Other distro **already running:** `\\wsl.localhost\NAME\etc\wsl.conf` (via `wslpath` if needed). If unreadable, `unavailable` with reason.
- Other distro **stopped:** do not start it, do not mount the VHD. `wsl.conf: unavailable (distro not running)`.

## Config filter

Apply to `.wslconfig` `[wsl2]` / `[experimental]` and to `/etc/wsl.conf` sections.

1. Known key, value equals documented default → omit.
2. Known key, value differs → show `key = value` and the default.
3. Unknown key → always show.
4. After filtering, nothing left → `(all defaults)`.

**Booleans:** compare case-insensitively as true (`true` / `yes` / `1`) vs false (`false` / `no` / `0`).

**`networkingMode`:** compare case-insensitively to `nat`.

**Always show if present** (default is a formula, an expanded path, or distro-specific — we do not compute it):

`.wslconfig`: `memory`, `processors`, `swap`, `swapFile`, `kernel`, `kernelModules`, `kernelCommandLine`  
`wsl.conf`: `[network] hostname`, `[user] default`, `[boot] command`, `[boot] systemd`

When showing those, print the documented formula or “custom path / distro default” as `default: …`.

### Documented defaults (v1 table)

`.wslconfig` `[wsl2]`: `localhostForwarding=true`, `safeMode=false`, `guiApplications=true`, `debugConsole=false`, `maxCrashDumpCount=10`, `nestedVirtualization=true`, `vmIdleTimeout=60000`, `dnsProxy=true`, `networkingMode=nat`, `firewall=true`, `dnsTunneling=true`, `autoProxy=true`, `defaultVhdSize=1099511627776` (also accept `1TB`).

`.wslconfig` `[experimental]`: `autoMemoryReclaim=dropCache`, `sparseVhd=false`, `bestEffortDnsParsing=false`, `dnsTunnelingIpAddress=10.255.255.254`, `initialAutoProxyTimeout=1000`, `hostAddressLoopback=false`. `ignoredPorts` default is unset — if present, show.

`wsl.conf`: `[automount]` `enabled=true`, `mountFsTab=true`, `root=/mnt/`; `[network]` `generateHosts=true`, `generateResolvConf=true`; `[interop]` `enabled=true`, `appendWindowsPath=true`; `[boot]` `protectBinfmt=true`; `[gpu]` `enabled=true`; `[time]` `useWindowsTimezone=true`. `[automount] options` default unset — if present, show.

Other sections/keys: unknown → always show.

## JSON

Same tree. Scalars that could not be read are `null`. A whole subsection that is not applicable uses an object:

```json
{
  "host": {
    "versions": {
      "wsl": "2.7.12.0",
      "wslExe": "2.7.12.0",
      "mismatch": false,
      "kernel": "6.18.33.2-2",
      "wslg": "1.0.73.2",
      "msrdc": "1.2.7214",
      "direct3d": "1.611.1-81528511",
      "dxcore": "10.0.26100.1-240331-1435.ge-release",
      "windows": "10.0.26200.9106"
    },
    "runtime": {
      "networkingMode": "mirrored",
      "configuredNetworkingMode": "mirrored",
      "vmId": "{…}",
      "msalProxyPath": "…"
    },
    "wslconfig": {
      "windowsPath": "C:\\Users\\foo\\.wslconfig",
      "wslPath": "/mnt/c/Users/foo/.wslconfig",
      "exists": true,
      "sections": { "wsl2": { "guiApplications": { "value": "false", "default": "true" } } }
    },
    "wslgconfig": {
      "windowsPath": "C:\\Users\\foo\\.wslgconfig",
      "wslPath": "/mnt/c/Users/foo/.wslgconfig",
      "exists": true,
      "sections": { "system-distro-env": { "WESTON_RDP_HI_DPI_SCALING": "true" } }
    }
  },
  "distro": {
    "name": "Ubuntu",
    "current": true,
    "default": true,
    "state": "Running",
    "wslVersion": 2,
    "vhd": { "windowsPath": "C:\\…\\ext4.vhdx", "wslPath": "/mnt/c/…/ext4.vhdx" },
    "defaultUid": 1000,
    "wslconf": {
      "available": true,
      "path": "/etc/wsl.conf",
      "exists": true,
      "sections": { "interop": { "appendWindowsPath": { "value": "false", "default": "true" } } }
    }
  }
}
```

When `wsl.conf` is not readable:

```json
"wslconf": { "available": false, "reason": "distro not running" }
```

`.wslgconfig` values have no `default` wrapper (presence means override). `.wslconfig` / `wsl.conf` non-default keys use `{ "value", "default" }`. Always-show-if-present keys use the same shape; `default` is the formula string.

Stdout is only the report (human or JSON). Unavailable sources are field values in that report, not extra stderr noise. Stderr is for usage errors and unknown `--distro` only.

## Errors

| Case | Exit | stdout / stderr |
|------|------|-----------------|
| `--help` | 0 | usage |
| Unknown flag | 1 | usage on stderr |
| Unknown `--distro` | 1 | error + distro names on stderr |
| Missing `wslinfo` / `wsl.exe` / registry / `WIN_USERPROFILE` / file | 0 | that field unavailable; rest of report printed |
| Missing `crudini` | 0 | paths shown; config body `unavailable (need crudini)` |
| Not in WSL | same as other `wslutil-*` when invoked via dispatcher (dispatcher already checks) | |

Never: `wsl.exe -d NAME` to probe a stopped distro. Never: `wsl.exe --mount` on a VHD.

## Implementation notes

- `bin/wslutil-info` is a bash script in the existing style (`set -euo pipefail`, `wslutil_resolve_datadir` only if needed).
- Reuse `win-utf8` for `wsl.exe` output. Reuse `win-env` to bootstrap `WIN_USERPROFILE` when unset. Reuse `crudini` (already a doctor dependency).
- PowerShell registry query: `-NoProfile`.
- JSON: emit with `yq` (already a project dependency). If `yq` is missing, `--json` exits 1 with an error; human mode does not require `yq`. Do not hand-roll nested JSON.
- Per-section collectors internally are fine; they are not CLI sections.

## Testing (BATS)

- Non-default filter fixtures: omit key set to default; keep key that differs; keep unknown key; keep `memory=4GB`; empty file → no keys.
- `--json` contains `host` and `distro` objects (fixture or live smoke).
- Unknown `--distro` → exit 1.
- Live `wslutil info --json` smoke: runs, parses as JSON. Do not snapshot this machine’s versions.

## Out of scope (follow-ups)

- Relocate / import / register distros.
- Mounting a stopped distro VHD to read `wsl.conf`.
- `wsl-info` alias.
- Computing 50% of host RAM to omit `memory` when it matches.
- Expanding `wslinfo` if Microsoft adds flags — pick them up as extra runtime fields when `--help` grows.
