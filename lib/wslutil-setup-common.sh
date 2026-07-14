# lib/wslutil-setup-common.sh — shared helpers for wslutil-setup (and future setup subcommands)
# Requires: $_wsu_bin set by caller before source; $DRY_RUN in caller scope for merge_config_file.

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "   ${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "  ${RED}[ERROR]${NC} $1"
}

bootstrap_win_env_if_needed() {
    export WIN_WINDIR="${WIN_WINDIR:-/mnt/c/Windows}"
    # Fill path vars needed for config envsubst from win-env cache (not shellenv)
    local need=0
    local v
    for v in WIN_USERPROFILE WIN_PROGRAMFILES WIN_PROGRAMFILES_X86 WIN_LOCALAPPDATA WIN_APPDATA; do
        if [[ -z "${!v:-}" ]]; then
            need=1
            break
        fi
    done
    [[ $need -eq 0 ]] && return 0

    log_info "Bootstrapping Windows environment variables via win-env"
    local win_env="${_wsu_bin}/win-env"
    if [[ ! -x "$win_env" ]]; then
        log_warning "win-env not found; path expansions may be skipped"
        return 0
    fi
    local env_out
    if ! env_out="$("$win_env" --export USERPROFILE APPDATA LOCALAPPDATA ProgramFiles ProgramFiles_x86 2>/dev/null)"; then
        log_warning "Could not bootstrap WIN_* via win-env; path expansions may be skipped"
        return 0
    fi
    set +u
    if ! eval "$env_out"; then
        set -u
        log_warning "Could not bootstrap WIN_* via win-env; path expansions may be skipped"
        return 0
    fi
    set -u
}

require_crudini() {
    if ! command -v crudini &>/dev/null; then
        log_error "crudini is required but not installed"
        log_error "Please install crudini and try again"
        log_error "Run 'wslutil doctor' to check for all required dependencies"
        exit 1
    fi
}

merge_config_file() {
    local source_file="$1"
    local target_file="$2"
    local description="$3"

    if [[ ! -f "$source_file" ]]; then
        log_warning "Source file not found: $source_file"
        return 1
    fi

    log_info "Merging $description: $source_file -> $target_file"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY-RUN] Would merge configuration into $target_file"
        return 0
    fi

    # Create target directory if it doesn't exist
    local target_dir
    target_dir=$(dirname "$target_file")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
        log_info "Created directory: $target_dir"
    fi

    # Create target file if it doesn't exist
    if [[ ! -f "$target_file" ]]; then
        touch "$target_file"
        log_info "Created target file: $target_file"
    fi

    crudini --merge "$target_file" <"$source_file"

    log_success "Successfully merged $description"
}
