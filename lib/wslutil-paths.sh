# lib/wslutil-paths.sh — path helpers for wsl-utils (no exported WSLUTIL_* layout vars)
# Usage: source this file, then call functions below.
# Caller passes the path to the invoking script (usually "${BASH_SOURCE[0]}" or "$0").

wslutil_resolve_datadir() {
    local script_path="${1:?script path required}"
    local bindir
    bindir="$(cd "$(dirname "$script_path")" && pwd)"

    if [[ -d "$bindir/../share/wslutil/config" && -d "$bindir/../share/wslutil/env" ]]; then
        (cd "$bindir/../share/wslutil" && pwd)
        return 0
    fi
    if [[ -d "$bindir/../config" && -d "$bindir/../env" ]]; then
        (cd "$bindir/.." && pwd)
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
