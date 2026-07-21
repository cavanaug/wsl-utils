# Unify Windows exe config into `wslutil.yml`

**Date:** 2026-07-20  
**Status:** Approved  
**Related:** `2026-07-14-setup-subcommand-split-design.md` (`setup exes`), `2026-07-11-prefix-install-design.md` (shimdir)

## Problem

Two YAML files describe overlapping Windows executable configuration:

| File | Consumer | Role today |
|------|----------|------------|
| `wslutil.yml` (`winexe` / `winrun`) | `wslutil setup exes` | Which names get PATH symlinks (direct vs via `win-run`) |
| `win-run.yml` (`aliases`) | `win-run` | Full path + optional default options for runtime resolution |

The same apps often appear in both (e.g. Brave path as `winexe` and again as an alias). User override rules also disagree: `setup exes` **replaces** factory with user `wslutil.yml` if present; `win-run` **merges** factory + user aliases with user winning per name. Factory `config/win-run.yml` is effectively a test stub; useful aliases live in `~/.config/wslutil/win-run.yml`.

## Goals

- Single factory/user config file: `wslutil.yml`.
- One schema covering PATH link mode, optional path, and optional options.
- Consistent factory + user **merge by name**.
- Support path/options-only entries (no PATH link), matching today’s alias-without-shim case.
- Shared load/merge helper used by `setup exes` and `win-run`.
- Hard-cut old `winexe` / `winrun` / `aliases` / `win-run.yml` schemas.

## Non-goals

- Auto-rewrite of existing `~/.config/wslutil/win-run.yml` (warn + document only).
- Field-level merge within an entry (user entry replaces the whole factory entry for that name).
- Changing UTF-8 / argument path-conversion behavior inside `win-run`.
- Changes to `setup windows` / `setup linux` / INI merges.
- Homebrew or packaging beyond shipping the new factory file.

## Decisions

| Topic | Choice |
|-------|--------|
| Canonical file | `wslutil.yml` (drop `win-run.yml`) |
| Schema shape | Name-keyed map under `exes:` |
| User override | Merge by name: factory then user; user key replaces whole entry |
| PATH link | Optional via `mode`: `direct` \| `shim` \| `none` |
| Stale links | `setup exes` **removes** `$SHIMDIR/<name>` when merged `mode` is `none` |
| `-c` / `--config` | That file only — no factory+user merge |
| Migration | Hard cut; document porting; no silent auto-write of user config |

## Schema

**Factory:** `$DATADIR/config/wslutil.yml`  
**User:** `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/wslutil.yml`

```yaml
exes:
  <name>:
    mode: direct | shim | none   # required
    path: <string>               # optional; envsubst of safe WIN_*
    options: <string> | null     # optional; prepended by win-run only
```

| `mode` | PATH link (`setup exes`) | Runtime |
|--------|--------------------------|---------|
| `direct` | `$SHIMDIR/<name>` → Windows exe | No `win-run` |
| `shim` | `$SHIMDIR/<name>` → `win-run` | Path convert + UTF-8; uses `path` / `options` if set |
| `none` | No link; **remove** existing `$SHIMDIR/<name>` if present | `win-run <name>` only; prefers `path` when set |

**Link name:** always the map key `<name>`. When `path` is set, its basename should match `<name>` (warn if not; still link as `<name>`).

**Missing `path`:** unchanged discovery — Windows PATH cache / `Get-Command` during `setup exes` for `direct`; bare command name for `win-run` when no path in config.

### User config example

```yaml
# ~/.config/wslutil/wslutil.yml — deltas only
exes:
  notepad++.exe:
    mode: shim
    path: ${WIN_PROGRAMFILES}/Notepad++/notepad++.exe
  mytool.exe:
    mode: none
    path: ${WIN_USERPROFILE}/tools/mytool.exe
    options: "--quiet"
  # Disable a factory PATH link without deleting factory:
  cmd.exe:
    mode: none
```

## Config resolution

1. If `-c` / `--config FILE` → load that file only.
2. Else load factory `wslutil.yml`, then if user `wslutil.yml` exists, merge: for each key under `exes`, user value replaces factory value for that key. Keys only in user are added. Keys only in factory are kept.

Applies identically to `wslutil setup exes` and `win-run`.

## Consumers

### `wslutil setup exes`

1. Resolve merged config (above).
2. For each `exes` entry:
   - `direct` → create/update direct symlink to resolved Windows path.
   - `shim` → create/update symlink to `win-run`.
   - `none` → remove `$SHIMDIR/<name>` if it exists; do not create.
3. Do not delete unrelated files in shimdir.
4. Unresolvable `direct` (no `path` and not found) → warn and skip (same spirit as today).

### `win-run`

1. Same config resolution / merge (shared helper).
2. Resolve command path from `exes.<cmd>.path` when set (after `WIN_*` expansion); else keep bare cmd / existing path logic.
3. Prepend `exes.<cmd>.options` when set.
4. Path conversion on arguments and UTF-8 output handling unchanged.
5. Invoking via a `shim` PATH link still enters `win-run` with basename `<name>`.

### Shared helper

New lib (e.g. `lib/wslutil-exes-config.sh`) sourced by `wslutil-setup` and `win-run`:

- Resolve config paths (`-c` vs factory + user)
- Load + merge `exes` map (yq)
- Safe `WIN_*` expansion on `path`
- Query helpers: mode / path / options for a name

## Migration

| Old | New |
|-----|-----|
| `winexe: [cmd.exe]` | `exes.cmd.exe.mode: direct` |
| `winexe: ["${…}/brave.exe"]` | `exes.brave.exe: { mode: direct, path: "${…}/brave.exe" }` |
| `winrun: [notepad.exe]` | `exes.notepad.exe.mode: shim` |
| `aliases.foo.path` / `options` | `exes.foo: { mode: none, path, options }` (or `shim`/`direct` if a PATH link is desired) |
| `config/win-run.yml` | Remove; fold any real entries into factory `wslutil.yml` |
| `~/.config/wslutil/win-run.yml` | Manual port; if present, `win-run` / `setup exes` may warn once that aliases should move into `wslutil.yml` |

Hard cut: do not dual-read old `winexe` / `winrun` / `aliases` schemas.

## Docs & tests

- Update factory `config/wslutil.yml`; delete `config/win-run.yml`.
- Update bats: alias resolution, setup exes, integration, helpers; cover merge-by-name and `mode: none` link removal.
- Update README, DETAILS, CLAUDE/AGENTS, `config/README.md` (fix stale `direct_links` / `shims` wording).

## Success criteria

1. One factory file drives both PATH links and `win-run` path/options.
2. User `~/.config/wslutil/wslutil.yml` is a small delta file merged by name.
3. `mode: none` both skips creating a link and removes a prior link for that name.
4. No remaining readers of `win-run.yml` or `winexe`/`winrun`/`aliases` keys.
5. Existing path-conversion / UTF-8 behavior of `win-run` unchanged aside from config source.
