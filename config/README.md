# Configuration Settings

Factory config lives under `config/` in a checkout, or `${PREFIX}/share/wslutil/config/` after `make install`. User overrides go in `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/`.

## `wslutil setup exes` and `win-run`

**File:** `wslutil.yml` (factory + user merge-by-name)

Defines Windows executables under an `exes` map. Used by both `wslutil setup exes` (PATH symlinks) and `win-run` (path/options resolution). See [DETAILS.md](../DETAILS.md#windows-executable-configuration-wslutilyml) for the full schema.

## `wslutil setup windows`

**Files:** `wslconfig`, `wslgconfig`

Merged into the Windows user profile with `crudini`:

- `wslconfig` → `${WIN_USERPROFILE}/.wslconfig`
- `wslgconfig` → `${WIN_USERPROFILE}/.wslgconfig`

Factory files are processed first; user files in `~/.config/wslutil/` override by section/key.

## `wslutil setup linux`

**File:** `wsl.conf`

Merged into `/etc/wsl.conf` via `sudo wslutil-setup-linux` (requires `crudini` and root). Factory `wsl.conf` is processed first; user `~/.config/wslutil/wsl.conf` is merged on top.

## Dependencies

`wslutil doctor` checks for `crudini`, which is required for `setup windows` and `setup linux`.
