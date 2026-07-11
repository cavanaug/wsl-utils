# PREFIX install & packaging readiness

**Date:** 2026-07-11  
**Status:** Approved  
**North star:** `make install PREFIX=…` as the real installer; Homebrew/apt later call that Makefile (out of scope for this change).

## Problem

wsl-utils today assumes a mutable git checkout (typically `~/.wslutil`). `wslutil setup` writes Windows exe symlinks into the install `bin/`, `shellenv` prepends that tree to `PATH`, and `upgrade`/`--version` depend on `.git`. That layout fights versioned packages: a PREFIX/Homebrew install must not be mutated on setup, and upgrades must not be `git pull`.

## Goals

- Support standard `make install PREFIX=/usr/local` (and `DESTDIR` for staging).
- Separate **core** (packaged files) from **generated** (machine-local shims) and **user config**.
- Keep `wslutil setup --shims` non-interactive so a future Homebrew `post_install` can call it.
- Minimize `WSLUTIL_*` environment variables; do not require `WSLUTIL_DIR`.
- Preserve git-checkout workflow via layout detection.

## Non-goals

- Homebrew formula/tap implementation (later; should only need `make install PREFIX=#{prefix}` + caveats for `setup --shims`).
- apt/rpm packages.
- Running `setup --system` (or `wsl.exe -u root`) from install/post_install.
- Seeding `~/.config/wslutil` during `make install` or brew post_install.

## Layout

### Packaged (make install)

```text
$(DESTDIR)$(PREFIX)/bin/
  wslutil
  wslutil-doctor
  wslutil-setup
  wslutil-uptime
  win-run
  win-open
  win-browser
  win-copy
  win-paste
  win-utf8
  wslpath-drive

$(DESTDIR)$(PREFIX)/share/wslutil/
  config/          # factory defaults (wslutil.yml, wsl.conf, wslconfig, wslgconfig, …)
  env/             # shellenv.*
```

`PREFIX` defaults to `/usr/local`.

### Generated (not in PREFIX)

```text
${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin/
  # winexe direct links and winrun → win-run shims
```

Created/updated only by `wslutil setup --shims` (or full `setup`).

When `PREFIX=$HOME/.local`, factory data and the shim dir share the same app tree (`~/.local/share/wslutil/{config,env,bin}`). That is intentional and works with path resolution from `~/.local/bin`. **`make uninstall` must not delete the whole `share/wslutil` directory** — only packaged `config/` and `env/` (plus files under `$(PREFIX)/bin`). Leave `share/wslutil/bin` (shims) intact.

### User overlay (optional)

```text
${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/
  # seeded by `wslutil config init`, never by make/brew install
```

## Core vs generated

| Kind | Examples | Owner |
|------|----------|--------|
| Core scripts | `wslutil*`, `win-*`, `wslpath-drive` | Package / make install |
| Factory data | `share/wslutil/config`, `share/wslutil/env` | Package / make install |
| Generated shims | `cmd.exe`, `notepad.exe` → `win-run`, etc. | User XDG data dir via setup |
| User config | Custom `wslutil.yml`, aliases, etc. | `~/.config/wslutil` after `config init` |
| System merges | `/etc/wsl.conf`, Windows `.wslconfig` / `.wslgconfig` | Opt-in `setup --system` |

## Runtime path resolution

No `WSLUTIL_DIR` / `WSLUTIL_DATA`. Scripts resolve the data root from their own location:

1. If `$(dirname $0)/../share/wslutil` exists → packaged install (data root = that directory).
2. Else if `$(dirname $0)/../config` and `../env` exist → git checkout (data root = parent of `bin`).
3. Else → error with a clear message.

Shared as a small helper sourced by scripts (or an equivalent few-line function), not an exported env var.

### Environment variables

| Keep | Drop / do not add |
|------|-------------------|
| `WIN_*` from shellenv | `WSLUTIL_DIR` |
| `WSLUTIL_DEBUG` (existing) | `WSLUTIL_DATA`, `WSLUTIL_SHIM_DIR` |

Shim directory is always `${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin` (hardcoded convention in setup + shellenv).

## Commands

### shellenv

- Load `env/shellenv.*` from the resolved data root.
- Export `WIN_*` as today.
- Prepend **shim dir only** to `PATH` (not the install/checkout `bin/`).
- Do not export `WSLUTIL_DIR`.

Core binaries are expected on `PATH` via PREFIX (`/usr/local/bin`, future Homebrew prefix, etc.) or an explicit checkout `PATH` entry for developers.

### setup

| Invocation | Behavior |
|------------|----------|
| `wslutil setup --shims` | Non-interactive. Materialize winexe/winrun into shim dir. Prefer `~/.config/wslutil/wslutil.yml` if present; else factory `share/.../wslutil.yml`. Resolve `WIN_*` itself as needed (do not require a prior interactive shellenv). Idempotent. |
| `wslutil setup --system` | Opt-in: merge into `/etc/wsl.conf` and Windows `.wslconfig` / `.wslgconfig`. May use elevated mechanisms later; not called from package post_install. |
| `wslutil setup` | Full human path: shims + system. |

Future Homebrew (out of scope): `post_install` → `wslutil setup --shims` only; caveats mention `setup --system`.

### config init

- Copy missing factory files from share `config/` into `~/.config/wslutil/`.
- Do not overwrite existing files unless `--force`.
- Not run by `make install` or brew post_install.

### upgrade / --version

- `upgrade`: if checkout layout with `.git` → `git pull`; else print guidance to use the package manager / reinstall.
- `--version`: prefer a shipped `VERSION` (or equivalent) for packaged installs; fall back to git describe/date when in a checkout.

## Makefile

```text
PREFIX ?= /usr/local
DESTDIR ?=

make install     # core scripts + share/wslutil/{config,env} — never runs dep checks
make uninstall   # remove packaged bin scripts + share/wslutil/{config,env} only
                 # never rm -rf share/wslutil (would wipe shimdir when PREFIX=$HOME/.local)
make check-deps  # soft check for runtime tools (yq, crudini, …); warn and non-zero
                 # if missing, but not required by `install` (safe for DESTDIR staging)
```

No Makefile target runs setup. After install, the user (or a future package `post_install`) runs `wslutil setup --shims` directly.

`check-deps` may reuse or thin-wrap the same dependency list as `wslutil doctor` essentials; it must not require a live Windows/`WIN_*` environment to run (so it works in CI and staging). Full WSL health remains `wslutil doctor` after install.

## Migration

- `install.sh` becomes a thin wrapper: optional clone + `make install PREFIX=$HOME/.local` (or similar) + instruct user to run `wslutil setup --shims` and shellenv.
- Existing `~/.wslutil` checkouts keep working via checkout-layout detection.
- Stop writing winexe/winrun into package or checkout `bin/` (those go only to XDG shim dir).
- Gitignored generated `bin/*.exe` (etc.) remain local leftovers until cleaned; setup no longer targets that directory.

## Success criteria

1. `make install PREFIX=/tmp/wsu && PATH=/tmp/wsu/bin:$PATH wslutil --help` works and resolves share data under `/tmp/wsu/share/wslutil`.
2. `wslutil setup --shims` creates links only under `${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin`.
3. `eval "$(wslutil shellenv)"` does not export `WSLUTIL_DIR`.
4. A git checkout with `bin` on `PATH` still works without `make install`.

## Implementation notes (non-binding)

- Extract a shared `resolve_wslutil_datadir` helper used by `wslutil`, `wslutil-setup`, and `win-run` (alias config paths).
- Shim links to `win-run` should point at the installed `win-run` absolute path (or a stable PATH lookup), not a relative path inside the shim dir.
- `wslview` (if kept as a win-browser alias) should be either a small installed script or an install-time link under PREFIX — not a generated Windows shim.
