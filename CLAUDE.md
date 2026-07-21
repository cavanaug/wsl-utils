# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `wsl-utils`, a collection of command-line utilities that simplify interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment. The main entry point is `wslutil`, which acts as a dispatcher for various subcommands and helper scripts.

## Architecture

### Core Components

- **`wslutil`** (bin/wslutil): Main dispatcher script that handles subcommands and discovers external `wslutil-*` scripts
- **Subcommands**: Individual `wslutil-*` scripts (e.g., `wslutil-doctor`, `wslutil-setup`) that implement specific functionality
- **Windows Integration Helpers**: `win-*` scripts that provide direct integration with Windows features
- **Environment Setup**: Shell environment configuration via `env/shellenv.*` files
- **Configuration**: YAML-based configuration in `config/wslutil.yml` for Windows executable shim creation

### Key Scripts

- `bin/wslutil`: Main entry point and command dispatcher
- `bin/wslutil-doctor`: Health check and diagnostic tool for WSL environment
- `bin/wslutil-uptime`: Display WSL distribution uptime (not VM uptime)
- `bin/win-run`: Execute Windows commands with automatic path conversion
- `bin/win-browser`: Open files/URLs in Windows default browser
- `bin/win-copy`/`bin/win-paste`: Windows clipboard integration
- `bin/win-open`: Open files with Windows default applications
- `env/shellenv.bash`: Environment variable setup for Windows interop

### Environment Variables

**Core System Variables:**
- `WSL_INTEROP`: WSL interop socket path (default: `/run/WSL/1_interop`)

Factory data is resolved from the command location: `${PREFIX}/share/wslutil` for `make install`, or the repository root when running from a checkout.

**Windows Environment Variables (set by `wslutil shellenv`):**
- `WIN_USERPROFILE`: Windows user profile path (converted to WSL format)
- `WIN_WINDIR`: Windows directory path (default: `/mnt/c/Windows`)
- `WIN_PROGRAMFILES`: Program Files directory (converted to WSL format)
- `WIN_PROGRAMFILES_X86`: Program Files (x86) directory
- `WIN_LOCALAPPDATA`: Local AppData directory
- `WIN_APPDATA`: Roaming AppData directory  
- `WIN_COMPUTERNAME`: Windows computer name
- `WIN_USERNAME`: Windows username
- `WIN_USERDOMAIN`: Windows user domain
- `WIN_HOMEPATH`: Combined HOMEDRIVE + HOMEPATH from Windows
- `WIN_ENV[]`: Associative array containing all Windows environment variables
  
  **⚠️ WARNING**: WIN_ENV is a Bash associative array with important limitations:
  - Not exported to subprocesses or scripts
  - Only available in current shell after `eval "$(wslutil shellenv)"`  
  - Use individual WIN_* variables for script compatibility

**Configuration Variables:**
- `XDG_CONFIG_HOME`: Config directory override (default: `~/.config`)
- `WSLUTIL_DEBUG`: When set, enables detailed logging to `~/.local/state/wslutil/*.log`

**Development Variables:**
- `BATS_TMPDIR`: Temporary directory for BATS tests (default: `/tmp`)
- `TMPDIR`: System temporary directory override

## Common Commands

### Health Check
```bash
wslutil doctor
```
Diagnoses WSL environment health, checks for required commands, files, and environment variables.

### Environment Setup
```bash
eval "$(wslutil shellenv)"
```
Sets up necessary environment variables for Windows interop. Should be added to shell startup files.

### Upgrade
```bash
wslutil upgrade
```
Updates wsl-utils by running `git pull` in the installation directory.

### Windows Integration
```bash
win-run <command> [args...]  # Execute Windows commands with path conversion
win-open <file>              # Open file with Windows default app
win-browser <url>            # Open URL in Windows default browser
```

### WSL Management
```bash
wslutil uptime               # Show WSL distribution uptime (not VM uptime)
```

## Development Notes

### Path Conversion
The `win-run` script automatically converts WSL paths to Windows format for any arguments that are existing files or directories using `wslpath -w`.

### Configuration Format
The `config/wslutil.yml` file defines Windows executables under an `exes` map for `wslutil setup exes` and `win-run`:
- `mode: direct` — direct symlink to Windows executable (no `win-run` overhead)
- `mode: shim` — symlink through `win-run` for path conversion and UTF-8 processing
- `mode: none` — no PATH link; `win-run` only (removes prior link on `setup exes`)

Factory and user `wslutil.yml` files are merged by name; user entries replace whole factory entries for matching keys.

### Extensibility
Custom subcommands can be added by creating executable `wslutil-<name>` scripts in PATH. They will be automatically discovered and available as `wslutil <name>`.

### Shell Environment Detection
The system detects the current shell via `$SHELL` and loads the appropriate `env/shellenv.<shell>` file.

## Testing

The project uses BATS (Bash Automated Testing System) for comprehensive testing.

### Running Tests
```bash
# Run all tests
./tests/run_tests.sh

# Run specific test file
./tests/run_tests.sh test_option_parsing.bats

# Run with verbose output
./tests/run_tests.sh -v
```

### Test Structure
- **test_option_parsing.bats**: Command-line option parsing tests
- **test_alias_resolution.bats**: Alias system and config hierarchy tests
- **test_path_conversion.bats**: Path conversion logic tests
- **test_integration.bats**: End-to-end functionality tests
- **test_wslutil_setup.bats**: Setup command and symlink creation tests

### Prerequisites
- BATS: `sudo apt install bats` or `brew install bats-core`
- yq: `sudo apt install yq` or `brew install yq`

## Configuration System Architecture

### wslutil-setup Symlink Management
The `wslutil-setup` command processes `config/wslutil.yml` `exes` entries to create Windows executable symlinks:

**`mode: direct`**: Direct symlinks to Windows executables for performance
**`mode: shim`**: Symlinks to `win-run` script for path conversion and UTF-8 processing
**`mode: none`**: Skip PATH link; remove existing shim if present

The setup process:
1. Loads factory + user `wslutil.yml` (merge-by-name), or a single file with `-c`
2. Builds Windows executable cache from PATH using PowerShell
3. Falls back to `Get-Command` for executables not in PATH
4. Handles Windows line endings and path conversion automatically
5. Supports environment variable expansion (`${WIN_PROGRAMFILES}`, etc.)

### PowerShell Integration
All PowerShell calls use `-NoProfile` flag for:
- Faster execution (no profile loading)
- Consistent behavior across environments  
- Predictable scripting environment

### win-run Architecture
- **Config resolution**: Shared `wslutil.yml` `exes` map (factory → user merge-by-name, or `-c` for one file)
- **Path Conversion**: Automatic WSL-to-Windows path conversion for files/directories
- **UTF-8 Processing**: Intelligent encoding detection and conversion (UTF-16LE to UTF-8)
- **Environment Variables**: Full expansion support in `path` and `options` fields

### User Configuration System
The system supports user-specific configurations in `~/.config/wslutil/`:

- **wslutil.yml**: User deltas for `exes` entries (merge-by-name with factory)
- **wsl.conf**: User WSL settings (merged into /etc/wsl.conf)
- **wslconfig**: User WSL2 settings (merged into Windows user profile)
- **wslgconfig**: User WSLg settings (merged into Windows user profile)

Configuration hierarchy: Factory configs processed first, then user configs override by name (for `wslutil.yml`) or merge sections (for INI files).