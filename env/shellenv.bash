# shellenv.bash — interactive convenience for wsl-utils
# Does not export WIN_* (those are optional; use: eval "$(win-env --export …)").
# Scripts must resolve Windows paths via defaults or win-env, not shell exports.

_wslutil_windir=${WIN_WINDIR:-/mnt/c/Windows}
if [[ ! -d $_wslutil_windir ]]; then
    echo "ERROR: Windows directory not found at ${_wslutil_windir}" >&2
    unset _wslutil_windir
    return 1 2>/dev/null || exit 1
fi
unset _wslutil_windir

_wslutil_shimdir="${XDG_DATA_HOME:-$HOME/.local/share}/wslutil/bin"
mkdir -p "$_wslutil_shimdir"
if [[ ! ":$PATH:" == *":$_wslutil_shimdir:"* ]]; then
    export PATH="${_wslutil_shimdir}:${PATH}"
fi
unset _wslutil_shimdir

export WSL_INTEROP=${WSL_INTEROP:-/run/WSL/1_interop}
if test ! -S ${WSL_INTEROP}; then
    echo "ERROR: WSL_INTEROP is not configured properly" >&2
    return 1 2>/dev/null || exit 1
fi

mkdir -p "${HOME}/.cache/wslutil"
mkdir -p "${HOME}/.local/state/wslutil"

# Locate win-env (same bindir as wslutil when installed)
_win_env=""
if command -v win-env >/dev/null 2>&1; then
    _win_env="$(command -v win-env)"
elif command -v wslutil >/dev/null 2>&1; then
    _cand="$(dirname "$(command -v wslutil)")/win-env"
    [[ -x "$_cand" ]] && _win_env="$_cand"
    unset _cand
fi

# Warm Windows env cache via win-env (no WIN_* exports into the shell)
if [[ -n "$_win_env" ]]; then
    _cache="${XDG_CACHE_HOME:-$HOME/.cache}/wslutil/env.win"
    if [[ ! -f "$_cache" ]]; then
        "$_win_env" --refresh || true
    elif [[ -n $(find "$_cache" -mmin +60 2>/dev/null) ]]; then
        ("$_win_env" --refresh) &>/dev/null &
    fi
    unset _cache
fi
unset _win_env

# Optional: expose convenience vars yourself, e.g.
#   eval "$(win-env --export USERPROFILE APPDATA LOCALAPPDATA ProgramFiles ProgramFiles_x86)"
