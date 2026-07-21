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

    # Merge .exes maps left-to-right; later file wins per key (whole entry object, not deep merge)
    yq eval-all '. as $item ireduce ({}; .exes = ((.exes // {}) + ($item.exes // {})))' "${files[@]}"
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

export -f wslutil_exes_warn_legacy
