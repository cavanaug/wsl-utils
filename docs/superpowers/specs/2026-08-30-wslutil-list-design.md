# `wslutil list` — table of all registered WSL distros

**Date:** 2026-08-30  
**Status:** Approved  
**Related:** `bin/wslutil` dispatcher, `docs/superpowers/specs/2026-08-30-wslutil-info-design.md` (deep dump of host + one distro; not this command)

## Problem

`wsl.exe -l -v` is a thin NAME / STATE / VERSION table. It does not show the OS pretty name, the live hostname, a `wsl.conf` hostname override, or where the distro lives on the Windows disk. `wslutil info` answers those for **one** distro plus host-global facts. There is no command that lists **every** registered distro with the extra columns.

## Goals

- One read-only command: `wslutil list` (binary `wslutil-list`).
- Table of **all** distros that `wsl.exe -l -v` reports (not `--all` / system distros).
- Always: name, default marker, state, WSL 1/2.
- Running only: `/etc/os-release` `PRETTY_NAME`, live hostname; `wsl.conf` `[network] hostname` in parentheses when it differs.
- `--location` adds the Windows `BasePath` folder (directory that contains the VHD, not the `.vhdx` file).
- Human table by default; `--json` is the same rows.
- Never start a distro. Never mount a VHD.
- Standalone: do **not** source or call `lib/wslutil-info.sh` / `wslutil-info`. Duplicate the small `-l -v` parse and Lxss `BasePath` read here.

## Non-goals

- Deep config dump (that is `wslutil info`).
- `--distro NAME` filter, column pickers, or `wsl --list --all` (system distros).
- Relocate / import / register / `wsl --mount`.
- Showing the `.vhdx` file path (info does that; list `--location` is the folder).
- Sharing collectors with `wslutil info`.
- Changing `wslutil doctor` or `wslutil info`.

## Decisions

| Topic | Choice |
|-------|--------|
| Public name | `wslutil list` only (`bin/wslutil-list`). Same dual invocation as `doctor` / `info`. |
| Relation to info | Companion table. Separate binary and lib. |
| Default rows | Whatever `wsl.exe -l -v` prints (UTF-16 via `win-utf8`). Same order. |
| Type | `PRETTY_NAME` from `/etc/os-release`. Running only. |
| Hostname | Live kernel hostname. If `wsl.conf` `[network] hostname` is set and differs, human `live (configured)`; JSON `hostnameConfigured` is that override, else `null`. |
| Location | Opt-in `--location`. Windows `BasePath` folder from Lxss. Not collected unless the flag is set. |
| JSON | Same rows as the human table. `location` key only with `--location`. |
| Start distros | Never. No `wsl.exe -d NAME`. No `wsl --mount`. File reads only. |
| Partial failure | Cell `-` / JSON `null`. Exit 0. |
| Empty inventory | `wsl.exe` missing or parse yields no distros → exit 1. |

## CLI

```text
wslutil list [--json] [--location]
wslutil-list [--json] [--location]
```

| Args | Behavior |
|------|----------|
| none | Human table |
| `--location` | Extra `LOCATION` column (Windows `BasePath`) |
| `--json` | Same rows as JSON array on stdout |
| `--json --location` | JSON objects include `location` |
| `--help` | Usage, exit 0 |
| unknown flag | usage on stderr, exit 1 |

Dispatcher already runs `wslutil-list` for `wslutil list`. Makefile adds `wslutil-list` to `CORE_SCRIPTS`. Add `list` to the hardcoded usage / `--help` list in `bin/wslutil` next to `doctor` / `info` (otherwise it only appears under auto-discovered extras).

## Table

```text
  NAME      STATE    WSL  TYPE                   HOSTNAME
* Ubuntu    Running  2    Ubuntu 24.04.2 LTS     mybox
  debian    Stopped  2    -                      -
  alpine    Running  2    Alpine Linux v3.20     alpine (devbox)
```

With `--location`:

```text
  NAME      STATE    WSL  TYPE                   HOSTNAME              LOCATION
* Ubuntu    Running  2    Ubuntu 24.04.2 LTS     mybox                 C:\Users\foo\AppData\Local\Packages\...\LocalState
  debian    Stopped  2    -                      -                     C:\Users\foo\WSL\debian
```

| Column | Rule |
|--------|------|
| prefix | `*` in column 0 if this is the default distro; space otherwise |
| `NAME` | as `wsl.exe -l -v` reports it (may contain spaces) |
| `STATE` | `Running` / `Stopped` (and any other state `wsl.exe` prints, verbatim) |
| `WSL` | `1` or `2` from the VERSION column; `-` if missing or not a number |
| `TYPE` | `PRETTY_NAME`; `-` if stopped or unreadable |
| `HOSTNAME` | live hostname; `live (configured)` when override differs; `-` if stopped or unreadable |
| `LOCATION` | Windows `BasePath`; only if `--location`; `-` if the registry row is missing |

Stdout is only the table (or JSON). Align columns with spaces.

## Data collection

Inventory: one `wsl.exe -l -v` piped through `win-utf8`. Skip the header (`NAME` / `STATE`). `*` in column 0 means default. Names may contain spaces — parse as the default `wsl.exe -l -v` table (NAME, STATE, VERSION).

**Never start a distro.** Do not call `wsl.exe -d NAME`. Do not `wsl --mount`. A distro that stops between the list and a file read must fail closed (type/hostname `-`), not boot as a side effect.

If `$WSL_DISTRO_NAME` is unset, treat every row as “other running” and use `wsl.localhost` paths (do not guess).

For **Running** rows, read files:

| Field | This distro (`$WSL_DISTRO_NAME`) | Other running |
|-------|----------------------------------|---------------|
| Type | `/etc/os-release` `PRETTY_NAME` | `\\wsl.localhost\NAME\etc\os-release` |
| Live hostname | `/proc/sys/kernel/hostname` | `\\wsl.localhost\NAME\proc\sys\kernel\hostname` |
| Configured hostname | `/etc/wsl.conf` `[network] hostname` | same path via `wsl.localhost` |

Resolve `\\wsl.localhost\NAME\…` with `wslpath -u`. If that fails, try `/mnt/wsl.localhost/NAME/…`. If the path is unreadable, that field is `-` / `null`. Strip quotes from `PRETTY_NAME`. Strip the trailing newline from `/proc/sys/kernel/hostname`.

`wsl.conf` hostname: `crudini --get` on `[network]` `hostname`. Missing file, missing key, or missing `crudini` → treat as unset (no parenthetical; JSON `hostnameConfigured` `null`). Do not fail the row.

`--location` only: one PowerShell `-NoProfile` pass over `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` for `DistributionName` + `BasePath`. Match name as `wsl.exe` reports it. Print `BasePath` as the Windows folder (WSL1 and Docker-style distros still have one). Missing row or PowerShell failure → that cell `-` / `null`; still print the table (exit 0). Without `--location`, do not query the registry.

`--json` requires `yq` (project convention). Human mode does not. Emit with `yq eval -o json`. Do not hand-roll nested JSON.

Helpers allowed: `win-utf8`, `wslpath`, `crudini`, `yq`, PowerShell `-NoProfile`. Not allowed: sourcing `lib/wslutil-info.sh`.

Command names used by collectors must be overridable for BATS (`WSLUTIL_LIST_WSL`, `WSLUTIL_LIST_WIN_UTF8`, `WSLUTIL_LIST_POWERSHELL`, etc.).

## JSON

Array of objects, same row order as the table.

```json
[
  {
    "name": "Ubuntu",
    "default": true,
    "state": "Running",
    "wslVersion": 2,
    "type": "Ubuntu 24.04.2 LTS",
    "hostname": "mybox",
    "hostnameConfigured": null
  },
  {
    "name": "alpine",
    "default": false,
    "state": "Running",
    "wslVersion": 2,
    "type": "Alpine Linux v3.20",
    "hostname": "alpine",
    "hostnameConfigured": "devbox"
  },
  {
    "name": "debian",
    "default": false,
    "state": "Stopped",
    "wslVersion": 2,
    "type": null,
    "hostname": null,
    "hostnameConfigured": null
  }
]
```

`--location` adds `"location"` per object (`null` if the registry row is missing). Without `--location`, omit the key entirely.

`hostnameConfigured` is the `wsl.conf` value **only when it differs** from live (case-sensitive string compare after trim). Otherwise `null`.

Unavailable scalars are `null`, not `"-"`. `wslVersion` is a JSON number (`1` or `2`), or `null` if the VERSION column is missing or not a number.

## Errors

| Case | Exit | stdout / stderr |
|------|------|-----------------|
| `--help` | 0 | usage on stdout |
| Unknown flag | 1 | usage on stderr |
| `--json` but no `yq` | 1 | error on stderr |
| Missing `wsl.exe` or parse yields zero distros | 1 | error on stderr |
| Single field fails (os-release, hostname, `wsl.conf`, registry row) | 0 | that cell `-` / `null`; rest of the row prints |
| Stopped distro | 0 | type/hostname `-` / `null` |
| `--location` but PowerShell/registry fails | 0 | `LOCATION` `-` / `null`; table still prints |
| Not in WSL | dispatcher already rejects | |

Stdout is only the report. No stderr chatter for unavailable cells. Never start a distro as error recovery.

## Implementation notes

- `bin/wslutil-list` is a bash script in the existing style (`set -euo pipefail`).
- Pure parse/format/read helpers live in `lib/wslutil-list.sh` so BATS can source them without Windows.
- Reuse `win-utf8` for `wsl.exe` output.
- PowerShell calls use `-NoProfile`.
- JSON: `yq eval -o json`. Missing `yq` + `--json` → exit 1.

## Testing (BATS)

- Parse `-l -v` fixture: default `*`, names with spaces, Running vs Stopped, WSL 1 vs 2.
- `PRETTY_NAME` from an os-release fixture (quoted and unquoted).
- Hostname: same → human `mybox`, JSON `hostnameConfigured` `null`; different → human `alpine (devbox)`, JSON `hostnameConfigured` `"devbox"`.
- Stopped row: type/hostname `-` / `null`; fake `wsl.exe` records argv — never `-d`.
- `--location` adds the column / JSON key; without it, neither appears; no PowerShell when the flag is off.
- `--json` parses as an array of objects with the keys above.
- Unknown flag → exit 1.
- Do not snapshot this machine’s live distro list.

## Out of scope (follow-ups)

- `wsl --list --all` / system distros.
- Filtering by name or state.
- Relocate / import / register.
- Sharing code with `wslutil info`.
- Mounting a stopped VHD to read `os-release` / `wsl.conf`.
