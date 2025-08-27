#!/bin/sh
#
# wsl-utils installation script
# This script automates the installation steps described in the README.md
# Compatible with POSIX sh - no bash-specific features
#

set -eu

# Logging functions (no colors for maximum compatibility)
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
    echo "[ERROR] $1"
}

# Hardcoded repository URL
DEFAULT_REPO_URL="https://github.com/cavanaug/wsl-utils.git"

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS] [REPOSITORY_URL]

Install wsl-utils from git repository to ~/.wslutil and set up shell integration.

Arguments:
  REPOSITORY_URL    Git repository URL (default: $DEFAULT_REPO_URL)

Options:
  --install-dir DIR    Install to custom directory (default: ~/.wslutil)
  --no-path           Skip adding to PATH
  --no-shellenv       Skip shell environment setup
  --shell SHELL       Target specific shell (currently only bash is supported)
  --dry-run           Show what would be done without making changes
  --help              Show this help message

Examples:
  $0                                          # Install from default repository
  $0 --no-path                               # Skip PATH setup
  $0 --shell bash --dry-run                  # Preview bash setup
  $0 https://github.com/user/fork.git       # Install from custom fork

If no repository URL is provided, uses the default repository.
If installation directory exists, will attempt to update or configure it.
EOF
}

# Parse command line arguments
INSTALL_DIR="$HOME/.wslutil"
REPOSITORY_URL=""
SETUP_PATH="true"
SETUP_SHELLENV="true"
TARGET_SHELL=""
DRY_RUN="false"

while [ $# -gt 0 ]; do
    case $1 in
    --install-dir)
        if [ -z "${2:-}" ]; then
            log_error "--install-dir option requires a directory argument"
            exit 1
        fi
        INSTALL_DIR="$2"
        shift 2
        ;;
    --no-path)
        SETUP_PATH="false"
        shift
        ;;
    --no-shellenv)
        SETUP_SHELLENV="false"
        shift
        ;;
    --shell)
        if [ -z "${2:-}" ]; then
            log_error "--shell option requires a shell name (currently only bash is supported)"
            exit 1
        fi
        if [ "$2" != "bash" ]; then
            log_error "Only bash is currently supported. Found: $2"
            exit 1
        fi
        TARGET_SHELL="$2"
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
        # First non-option argument is the repository URL
        if [ -z "$REPOSITORY_URL" ]; then
            REPOSITORY_URL="$1"
        else
            log_error "Unexpected argument: $1"
            exit 1
        fi
        shift
        ;;
    esac
done

# Check if running in WSL
if [ -z "${WSL_DISTRO_NAME:-}" ]; then
    log_warning "This script is designed for WSL environments"
    log_warning "Some features may not work correctly outside of WSL"
fi

# Detect current shell if not specified (only bash is supported)
if [ -z "$TARGET_SHELL" ]; then
    case "$SHELL" in
        */bash)
            TARGET_SHELL="bash"
            ;;
        *)
            TARGET_SHELL="bash"
            log_warning "Only bash is currently supported. Shell $SHELL detected, using bash configuration"
            ;;
    esac
fi

log_info "wsl-utils Installation Script"
log_info "============================="
log_info "Install directory: $INSTALL_DIR"
log_info "Target shell: $TARGET_SHELL"
log_info "Setup PATH: $SETUP_PATH"
log_info "Setup shell environment: $SETUP_SHELLENV"
log_info "Dry run: $DRY_RUN"

if [ "$DRY_RUN" = "true" ]; then
    log_info "Running in dry-run mode - no changes will be made"
fi

echo

# Set default repository URL if none provided
if [ -z "$REPOSITORY_URL" ]; then
    REPOSITORY_URL="$DEFAULT_REPO_URL"
fi

# Step 1: Clone repository (if URL provided and directory doesn't exist)
if [ -n "$REPOSITORY_URL" ]; then
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Directory $INSTALL_DIR already exists"
        log_info "Checking if it's a git repository..."
        
        if [ -d "$INSTALL_DIR/.git" ]; then
            log_info "Existing git repository found, updating..."
            if [ "$DRY_RUN" = "false" ]; then
                cd "$INSTALL_DIR"
                git pull
                log_success "Repository updated"
            else
                log_info "[DRY-RUN] Would update existing repository"
            fi
        else
            log_error "Directory exists but is not a git repository"
            log_error "Please remove $INSTALL_DIR or choose a different directory"
            exit 1
        fi
    else
        log_info "Cloning repository to $INSTALL_DIR..."
        if [ "$DRY_RUN" = "false" ]; then
            git clone "$REPOSITORY_URL" "$INSTALL_DIR"
            log_success "Repository cloned successfully"
        else
            log_info "[DRY-RUN] Would clone $REPOSITORY_URL to $INSTALL_DIR"
        fi
    fi
elif [ ! -d "$INSTALL_DIR" ]; then
    log_error "No repository URL provided and $INSTALL_DIR does not exist"
    log_error "Please provide a repository URL or ensure wsl-utils is already installed"
    exit 1
fi

# Verify installation directory contains expected files
if [ "$DRY_RUN" = "false" ] && [ ! -f "$INSTALL_DIR/bin/wslutil" ]; then
    log_error "Installation directory does not contain expected wslutil binary"
    log_error "Please check that $INSTALL_DIR contains a valid wsl-utils installation"
    exit 1
fi

# Step 2: Add to PATH (if requested)
if [ "$SETUP_PATH" = "true" ]; then
    # Only bash is supported
    SHELL_CONFIG="$HOME/.bashrc"
    PATH_LINE="export PATH=\"$INSTALL_DIR/bin:\$PATH\""

    log_info "Setting up PATH in $SHELL_CONFIG..."

    # Check if PATH is already set up
    if [ -f "$SHELL_CONFIG" ] && grep -q "$INSTALL_DIR/bin" "$SHELL_CONFIG"; then
        log_info "PATH already configured in $SHELL_CONFIG"
    else
        log_info "Adding $INSTALL_DIR/bin to PATH..."
        if [ "$DRY_RUN" = "false" ]; then
            # Create config file if it doesn't exist
            if [ ! -f "$SHELL_CONFIG" ]; then
                mkdir -p "$(dirname "$SHELL_CONFIG")"
                touch "$SHELL_CONFIG"
            fi

            # Add PATH line
            echo "" >> "$SHELL_CONFIG"
            echo "# Added by wsl-utils installer" >> "$SHELL_CONFIG"
            echo "$PATH_LINE" >> "$SHELL_CONFIG"
            log_success "PATH configured in $SHELL_CONFIG"
        else
            log_info "[DRY-RUN] Would add PATH line to $SHELL_CONFIG"
        fi
    fi
fi

# Step 3: Set up shell environment (if requested)
if [ "$SETUP_SHELLENV" = "true" ]; then
    # Only bash is supported
    SHELL_CONFIG="$HOME/.bashrc"
    SHELLENV_BLOCK='# Load wslutil environment variables if wslutil is available
if command -v wslutil >/dev/null 2>&1; then
  eval "$(wslutil shellenv)"
fi'

    log_info "Setting up shell environment in $SHELL_CONFIG..."

    # Check if shell environment is already set up
    if [ -f "$SHELL_CONFIG" ] && grep -q "wslutil shellenv" "$SHELL_CONFIG"; then
        log_info "Shell environment already configured in $SHELL_CONFIG"
    else
        log_info "Adding shell environment setup..."
        if [ "$DRY_RUN" = "false" ]; then
            # Create config file if it doesn't exist
            if [ ! -f "$SHELL_CONFIG" ]; then
                mkdir -p "$(dirname "$SHELL_CONFIG")"
                touch "$SHELL_CONFIG"
            fi

            # Add shell environment block
            echo "" >> "$SHELL_CONFIG"
            echo "# Added by wsl-utils installer" >> "$SHELL_CONFIG"
            echo "$SHELLENV_BLOCK" >> "$SHELL_CONFIG"
            log_success "Shell environment configured in $SHELL_CONFIG"
        else
            log_info "[DRY-RUN] Would add shell environment setup to $SHELL_CONFIG"
        fi
    fi
fi

# Final steps
echo
log_success "Installation completed successfully!"

if [ "$DRY_RUN" = "false" ]; then
    echo
    log_info "Next steps:"
    log_info "1. Restart your terminal or run: source $SHELL_CONFIG"
    log_info "2. Verify installation: wslutil --help"
    log_info "3. Run health check: wslutil doctor"
    log_info "4. Configure symlinks: wslutil setup"

    # Test if wslutil is accessible
    if command -v "$INSTALL_DIR/bin/wslutil" >/dev/null 2>&1; then
        echo
        log_success "wslutil is ready to use!"
        log_info "Try running: $INSTALL_DIR/bin/wslutil --help"
    fi
else
    echo
    log_info "Dry run completed. Run without --dry-run to perform installation."
fi