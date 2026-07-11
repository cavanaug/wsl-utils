#!/bin/sh
#
# wsl-utils installation wrapper
# Compatible with POSIX sh - no bash-specific features

set -eu

DEFAULT_REPO_URL="https://github.com/cavanaug/wsl-utils.git"

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [REPOSITORY_URL]

Install wsl-utils with make install.

Arguments:
  REPOSITORY_URL       Git repository URL (default: $DEFAULT_REPO_URL)

Options:
  --prefix DIR         Install prefix (default: \${PREFIX:-\$HOME/.local})
  --install-dir DIR    Back-compatible alias for --prefix
  --source-dir DIR     Source checkout directory (default: \${WSLUTIL_SOURCE_DIR:-\$HOME/.wslutil})
  --dry-run            Show what would be done without making changes
  --help               Show this help message

Deprecated no-op options accepted for older install commands:
  --no-path, --no-shellenv, --shell SHELL

Examples:
  $0
  $0 --prefix "$HOME/.local"
  $0 --source-dir "$HOME/src/wsl-utils" --prefix /tmp/wsu
  $0 https://github.com/user/fork.git
EOF
}

detect_script_dir() {
    case "$0" in
    */*)
        dir=$(CDPATH= cd "$(dirname "$0")" 2>/dev/null && pwd) || return 1
        if [ -f "$dir/Makefile" ] && [ -d "$dir/bin" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        ;;
    esac
    return 1
}

PREFIX="${PREFIX:-${INSTALL_DIR:-$HOME/.local}}"
SOURCE_DIR="${WSLUTIL_SOURCE_DIR:-}"
SOURCE_FROM_SCRIPT="false"
REPOSITORY_URL=""
DRY_RUN="false"

if [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR=$(detect_script_dir || true)
    if [ -n "$SOURCE_DIR" ]; then
        SOURCE_FROM_SCRIPT="true"
    fi
fi
if [ -z "$SOURCE_DIR" ]; then
    SOURCE_DIR="$HOME/.wslutil"
fi

while [ $# -gt 0 ]; do
    case "$1" in
    --prefix)
        if [ -z "${2:-}" ]; then
            log_error "--prefix option requires a directory argument"
            exit 1
        fi
        PREFIX="$2"
        shift 2
        ;;
    --install-dir)
        if [ -z "${2:-}" ]; then
            log_error "--install-dir option requires a directory argument"
            exit 1
        fi
        PREFIX="$2"
        shift 2
        ;;
    --source-dir)
        if [ -z "${2:-}" ]; then
            log_error "--source-dir option requires a directory argument"
            exit 1
        fi
        SOURCE_DIR="$2"
        SOURCE_FROM_SCRIPT="false"
        shift 2
        ;;
    --no-path | --no-shellenv)
        log_warning "$1 is no longer needed; install.sh does not edit shell startup files"
        shift
        ;;
    --shell)
        if [ -z "${2:-}" ]; then
            log_error "--shell option requires a shell name"
            exit 1
        fi
        log_warning "--shell is no longer needed; install.sh does not edit shell startup files"
        shift 2
        ;;
    --dry-run)
        DRY_RUN="true"
        shift
        ;;
    --help)
        show_help
        exit 0
        ;;
    -*)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    *)
        if [ -z "$REPOSITORY_URL" ]; then
            REPOSITORY_URL="$1"
            shift
        else
            log_error "Unexpected argument: $1"
            exit 1
        fi
        ;;
    esac
done

if [ -z "$REPOSITORY_URL" ]; then
    REPOSITORY_URL="$DEFAULT_REPO_URL"
fi

log_info "wsl-utils installer"
log_info "Source directory: $SOURCE_DIR"
log_info "Install prefix: $PREFIX"
log_info "Repository URL: $REPOSITORY_URL"
log_info "Dry run: $DRY_RUN"
echo

if [ "$DRY_RUN" = "true" ]; then
    if [ -d "$SOURCE_DIR/.git" ] && [ "$SOURCE_FROM_SCRIPT" = "false" ]; then
        log_info "[DRY-RUN] Would update existing checkout: git -C \"$SOURCE_DIR\" pull"
    elif [ -e "$SOURCE_DIR" ]; then
        log_info "[DRY-RUN] Would use existing source directory: $SOURCE_DIR"
    else
        log_info "[DRY-RUN] Would clone: git clone \"$REPOSITORY_URL\" \"$SOURCE_DIR\""
    fi
    log_info "[DRY-RUN] Would install: make -C \"$SOURCE_DIR\" install PREFIX=\"$PREFIX\""
else
    if [ -d "$SOURCE_DIR/.git" ] && [ "$SOURCE_FROM_SCRIPT" = "false" ]; then
        log_info "Updating existing checkout..."
        git -C "$SOURCE_DIR" pull
    elif [ -e "$SOURCE_DIR" ]; then
        if [ ! -f "$SOURCE_DIR/Makefile" ] || [ ! -d "$SOURCE_DIR/bin" ]; then
            log_error "$SOURCE_DIR exists but does not look like a wsl-utils source checkout"
            exit 1
        fi
        log_info "Using existing source directory"
    else
        log_info "Cloning repository..."
        git clone "$REPOSITORY_URL" "$SOURCE_DIR"
    fi

    log_info "Installing with make..."
    make -C "$SOURCE_DIR" install PREFIX="$PREFIX"
    log_success "Installation completed successfully!"
fi

cat <<EOF

Next steps:
  1. Ensure $PREFIX/bin is on your PATH.
  2. Load Windows integration in your shell:
       eval "\$(wslutil shellenv)"
  3. Create Windows executable shims:
       wslutil setup --shims
  4. Verify your setup:
       wslutil doctor
EOF
