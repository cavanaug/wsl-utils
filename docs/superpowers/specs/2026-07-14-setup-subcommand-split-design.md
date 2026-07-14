# Split `wslutil setup` by privilege boundary

**Date:** 2026-07-14  
**Status:** Approved  
**Related:** `2026-07-11-prefix-install-design.md` (shimdir + `--shims`/`--system` flags)

## Problem

`wslutil setup` currently runs two phases by default:

1. **Exe links** (`winrun` / `winexe`) — user-writable XDG shim dir, no root
2. **Config merges** — mixes Windows user-profile files (no root) with `/etc/wsl.conf` (needs root)

That forces either a surprising sudo prompt mid-run, or a failed `/etc/wsl.conf` write when the user only wanted exe links. The existing `--shims` / `--system` flags separate the work but keep one binary and an easy-to-misuse default. Names like `wslconf` vs `wslconfig` are also easy to confuse.

## Goals

- Split setup into three clear, privilege-aligned actions.
- Nested CLI: `wslutil setup {exes|windows|linux}`.
- Keep user-level work in `wslutil-setup`; isolate the sudo path in `wslutil-setup-linux`.
- Hard-cut remove `setup` with no subcommand doing “everything,” and remove `--shims` / `--system`.
- Preserve non-interactive `setup exes` for install docs and future package `post_install`.

## Non-goals

- Renaming `SHIMDIR` / internal “shim” vocabulary in code.
- Changing `wslutil.yml` winexe/winrun schema.
- Homebrew/apt packaging beyond updating install tips.
- Changing `wslutil config` (user config seeding).

## Decisions

| Topic | Choice |
|-------|--------|
| Privilege split | Three actions: exes / windows / linux |
| Naming | `exes` (not “shims”), `windows`, `linux` |
| CLI shape | `wslutil setup <subcommand>` (not `setup-exes` top-level) |
| Implementation | `wslutil-setup` owns `exes` + `windows`; `wslutil-setup-linux` owns `/etc/wsl.conf` |
| Elevation | `wslutil-setup-linux` auto-re-execs with `sudo` when not root; documented form is `sudo wslutil-setup-linux` |
| Windows scope | One `windows` subcommand merges both `.wslconfig` and `.wslgconfig` |
| Compatibility | Hard cut — no deprecated wrapper that runs all three |

## CLI surface

| Invocation | Implemented by | Privilege | Writes |
|------------|----------------|-----------|--------|
| `wslutil setup exes` | `wslutil-setup` | user | winexe/winrun links under XDG data bin dir |
| `wslutil setup windows` | `wslutil-setup` | user | `$WIN_USERPROFILE/.wslconfig` and `.wslgconfig` |
| `wslutil setup linux` | `wslutil-setup` → execs `wslutil-setup-linux` | elevated | `/etc/wsl.conf` |
| `wslutil-setup-linux` | same script, direct | elevated | `/etc/wsl.conf` |

**Flags**

- `--dry-run` — all three subcommands
- `-c` / `--config FILE` — `exes` only (selects `wslutil.yml`)

**Errors**

- Bare `wslutil setup` (no subcommand) → usage error listing `exes|windows|linux`
- Unknown subcommand → usage error
- Missing `yq` (exes) or `crudini` (windows/linux) → clear error pointing at `wslutil doctor`

**Removed**

- Default “run both phases”
- `--shims`, `--system`
- Docs/examples that say `wslutil setup --shims` or bare `wslutil setup` as the full configure path

## File layout

```text
bin/wslutil-setup          # parse subcommand; implement exes + windows; forward linux
bin/wslutil-setup-linux    # merge /etc/wsl.conf only; sudo re-exec when not root
```

Shared helpers (`bootstrap_win_env_if_needed`, `merge_config_file`, path/datadir resolution) may live in `wslutil-setup` and be sourced by `wslutil-setup-linux`, or move to a small `lib/` file if duplication is awkward. Prefer the smallest split that avoids copying merge logic twice.

`Makefile` `CORE_SCRIPTS` gains `wslutil-setup-linux`.

## Behavior

### `setup exes` (former shim phase)

1. Bootstrap missing `WIN_*` via `win-env` when needed for path expansion.
2. Select config: `-c/--config` → else `~/.config/wslutil/wslutil.yml` → else factory `$DATADIR/config/wslutil.yml`.
3. Ensure XDG shim/bin dir exists.
4. Process `winrun[]` → symlink each name to installed `win-run`.
5. Process `winexe[]` → direct symlink to Windows executable (envsubst of safe `WIN_*`, programs cache, `Get-Command` fallback).
6. Never call sudo.

### `setup windows`

1. Bootstrap `WIN_*` (requires `WIN_USERPROFILE` for targets).
2. Require `crudini`.
3. Merge factory then user overlays:
   - `wslconfig` → `$WIN_USERPROFILE/.wslconfig`
   - `wslgconfig` → `$WIN_USERPROFILE/.wslgconfig`
4. Never call sudo. If `WIN_USERPROFILE` unset after bootstrap, warn and skip (same spirit as today).

### `setup linux` / `wslutil-setup-linux`

1. If not root: re-exec with `sudo` preserving arguments (including `--dry-run`), targeting this script (`wslutil-setup-linux`).
2. Require `crudini`.
3. Merge factory then user `wsl.conf` → `/etc/wsl.conf`.
4. Remind that some settings need a WSL restart.

Canonical elevated invocation for docs and humans: `sudo wslutil-setup-linux`.

Dispatch chain for the nested path:

```text
wslutil setup linux [--dry-run]
  → wslutil-setup linux [--dry-run]
  → exec wslutil-setup-linux [--dry-run]
  → if non-root: exec sudo … wslutil-setup-linux [--dry-run]
```

`WIN_*` is not required for the `/etc/wsl.conf` merge; prefer plain `sudo` (no need to preserve the caller environment for this path).

## Install / docs flow

```bash
make install PREFIX="$HOME/.local"
eval "$(wslutil shellenv)"
wslutil setup exes
# optional:
wslutil setup windows
sudo wslutil-setup-linux
```

Update: README, DETAILS, `install.sh` next-steps, AGENTS/CLAUDE setup mentions, prefix-install plan references that still say `--shims`/`--system` where they describe *current* intended UX (historical plan docs may stay; user-facing docs must change).

## Testing

Retarget `tests/test_wslutil_setup.bats` (and any help/doctor strings):

- Help documents `exes`, `windows`, `linux` (not `--shims`/`--system`).
- Bare `setup` exits non-zero with usage.
- `setup exes` / `--dry-run` covers winrun/winexe, variable expansion, cache, missing paths (existing cases).
- `setup windows --dry-run` merges only Windows profile targets; no `/etc` writes.
- `setup linux` / direct `wslutil-setup-linux`: dry-run path; non-root elevation behavior (assert sudo re-exec or skip under constrained CI with a test hook if needed).
- Preference of user vs factory configs unchanged in spirit.

## Out of scope reminders

- Do not invent a fourth command for `.wslgconfig` alone.
- Do not keep a “run all three” orchestrator.
- Do not require shellenv before `setup exes` / `setup windows` (self-bootstrap `WIN_*` as today).

## Success criteria

1. User can run `wslutil setup exes` without root and get working winexe/winrun links.
2. `wslutil setup windows` never touches `/etc`.
3. Only `wslutil-setup-linux` writes `/etc/wsl.conf`, and elevation is `sudo wslutil-setup-linux` (auto or explicit).
4. Old `setup --shims` / `--system` / bare full setup are gone from code, help, and user-facing docs.
5. Existing bats coverage for exe linking and INI merge still passes under the new subcommands.
