# wsl-utils

A collection of command-line utilities designed to simplify and enhance the interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment.

## Quick Start

**One-line installation:**

```bash
curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh | sh
```

**Finish setup:**

```bash
export PATH="$HOME/.local/bin:$PATH"  # if ~/.local/bin is not already on PATH
wslutil --help
eval "$(wslutil shellenv)"    # Load Windows integration
wslutil setup exes            # Configure Windows executable shims
wslutil doctor                # Check system health
```

## Overview

`wsl-utils` provides two types of utilities:

- **`wslutil` commands**: Setup and configuration tools for the wsl-utils environment (interactive use)
- **`win-*` scripts**: Daily Windows integration utilities (command-line, scripting, automation)

### Core Features

- **Environment Setup:** Configure WSL-Windows interop variables
- **Health Checks:** Diagnose WSL setup issues with comprehensive checks
- **Windows Integration:** Execute Windows programs with automatic path conversion
- **Clipboard Access:** Full bidirectional clipboard support
- **Path Conversion:** Advanced WSL-to-Windows path handling
- **Extensible:** Add custom `wslutil-<name>` scripts

## Commands Overview

### `wslutil` - Setup & Configuration

| Command | Purpose |
|---------|---------|
| `wslutil doctor` | Run comprehensive health checks |
| `wslutil shellenv` | Output shell environment setup commands |
| `wslutil setup exes` | Create Windows executable shims |
| `wslutil setup windows` | Merge Windows WSL settings (optional) |
| `wslutil setup linux` | Merge `/etc/wsl.conf` via `sudo wslutil-setup-linux` (optional) |
| `wslutil upgrade` | Update wsl-utils via git pull |
| `wslutil uptime` | Show WSL distribution uptime (not VM uptime) |

**Usage:**

```bash
wslutil doctor                    # Check system health
eval "$(wslutil shellenv)"        # Set up environment
wslutil setup exes                # Create Windows exe shims
wslutil uptime                    # Show WSL distro uptime
```

### Script Categories

**`wslutil` scripts**: Commands for setup and configuration of the wslutil environment itself. These are typically run interactively during initial setup or maintenance (e.g., `wslutil doctor`, `wslutil setup`, `wslutil shellenv`).

**`win-*` scripts**: General-purpose utilities for daily Windows integration tasks. These are designed for command-line usage, scripting, and automation (e.g., `win-run`, `win-open`, `win-browser`, `win-copy`).

### Windows Integration Tools

| Command | Purpose | Example |
|---------|---------|---------|
| `win-run` | Execute Windows programs with automatic path conversion and encoding | `win-run notepad.exe ~/file.txt` |
| `win-open` | Open files/folders in Windows Explorer | `win-open .` |
| `win-browser` | Open URLs/files in Windows default browser | `win-browser https://example.com` |
| `wslview` | Compatibility symlink to `win-browser` (wslu interop) | `wslview https://example.com` |
| `win-copy` | Copy to Windows clipboard | `echo "text" \| win-copy` |
| `win-paste` | Paste from Windows clipboard | `win-paste > file.txt` |
| `win-utf8` | Convert Windows command output encoding | `cmd.exe /c dir \| win-utf8` |

**Usage Examples:**

```bash
# Execute Windows programs with automatic Linux path translation
win-run notepad.exe ~/myfile.txt        # Automatically converts to Windows path
win-run explorer.exe /mnt/c/Users       # Works with any Linux path

# Process Windows command output with proper encoding
win-run powershell.exe -Command "Get-Process" | grep chrome
win-run cmd.exe /c dir C:\ | head -10    # UTF-8 output, Unix line endings

# File operations  
win-open ~/Documents              # Open in Explorer
win-browser https://github.com    # Open in browser

# Clipboard workflows with automatic encoding handling
ls -la | win-copy                 # Copy to clipboard with proper UTF-8 encoding
win-paste | grep "important"      # Paste with Unix line endings, pipeline-ready
echo "Linux text" | win-copy      # Works seamlessly with Linux text
```

**Why these tools are Linux-friendly:**

- **`win-run`**: Automatically converts Linux paths to Windows paths and ensures UTF-8 output with Unix line endings
- **`win-copy`/`win-paste`**: Handle character encoding and convert DOS line endings to Unix format, making clipboard data pipeline-ready with Linux commands
- **`wslview`**: Install-time symlink to `win-browser`, so scripts written for [wslu](https://github.com/wslutilities/wslu)'s `wslview` work transparently with wsl-utils

## Installation Options

### Automated Installation (Recommended)

```bash
# Basic installation
curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh | sh

# Or from an existing checkout
make install PREFIX="$HOME/.local"
```

### Manual Installation

```bash
# Clone repository
git clone https://github.com/cavanaug/wsl-utils.git ~/.wslutil

# Install scripts and shared data
make -C ~/.wslutil install PREFIX="$HOME/.local"

# Ensure installed commands are on PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Set up environment integration
echo 'if command -v wslutil >/dev/null 2>&1; then eval "$(wslutil shellenv)"; fi' >> ~/.bashrc

# Create Windows executable shims
PATH="$HOME/.local/bin:$PATH" wslutil setup exes

# Reload shell
source ~/.bashrc
```

## Quick Reference

**Essential Commands:**

```bash
wslutil doctor                    # Health check
wslutil setup exes                # Configure Windows executable shims
win-run <windows-exe> [args]      # Run Windows programs
win-open <path>                   # Open in Explorer
```

**Common Workflows:**

```bash
# Copy current directory listing to clipboard
ls -la | win-copy

# Open current directory in Windows Explorer  
win-open .

# Edit a file with Windows Notepad
win-run notepad.exe ~/myfile.txt

# Search clipboard content
win-paste | grep "search-term"

# Check WSL distribution uptime (not the underlying VM)
wslutil uptime                    # Standard format
wslutil uptime --pretty           # Human-readable format
wslutil uptime --since            # Show when WSL distro started
```

## Configuration

Windows executable shims and `win-run` path/options share a single `wslutil.yml` config with an `exes` map (`mode: direct | shim | none`). Factory settings ship with wsl-utils; add deltas in `~/.config/wslutil/wslutil.yml`. See [DETAILS.md](DETAILS.md#windows-executable-configuration-wslutilyml) for schema, merge rules, and migration from old `winexe`/`winrun`/`win-run.yml` formats.

## Next Steps

- 📖 **[Detailed Documentation](DETAILS.md)** - Comprehensive configuration, advanced usage, and troubleshooting
- 🔧 **Run `wslutil doctor`** to verify your setup
- ⚙️ **Run `wslutil setup exes`** to configure Windows executable shims (optional: `wslutil setup windows`, `sudo wslutil-setup-linux`)
- 🧪 **Test integration** with `win-run notepad.exe` or `win-open .`

## Support

- 🐛 **Issues:** [GitHub Issues](https://github.com/cavanaug/wsl-utils/issues)
- 📚 **Documentation:** [DETAILS.md](DETAILS.md) for comprehensive information
- 💡 **Contributing:** See [DETAILS.md](DETAILS.md#contributing) for development guidelines

## License

MIT License - see [LICENSE](LICENSE) file for details.

