<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

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
- **Configuration**: YAML-based configuration in `conf.yml` for Windows executable symlink creation

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
- `WSLUTIL_DIR`: Installation directory (auto-detected from script location)
- `WSL_INTEROP`: WSL interop socket path (default: `/run/WSL/1_interop`)

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
The `conf.yml` file defines Windows executables for symlink creation by `wslutil setup`, categorized as:
- Direct links (no argument processing)
- Shims (processed through `win-run` for path conversion)

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
The `wslutil-setup` command processes `config/wslutil.yml` to create Windows executable symlinks:

**winexe entries**: Direct symlinks to Windows executables for performance
**winrun entries**: Symlinks to `win-run` script for path conversion and UTF-8 processing

The setup process:
1. Builds Windows executable cache from PATH using PowerShell
2. Falls back to `Get-Command` for executables not in PATH
3. Handles Windows line endings and path conversion automatically
4. Supports environment variable expansion (`${WIN_PROGRAMFILES}`, etc.)

### PowerShell Integration
All PowerShell calls use `-NoProfile` flag for:
- Faster execution (no profile loading)
- Consistent behavior across environments  
- Predictable scripting environment

### win-run Architecture
- **Alias Resolution**: YAML-based config hierarchy (global → user → custom)
- **Path Conversion**: Automatic WSL-to-Windows path conversion for files/directories
- **UTF-8 Processing**: Intelligent encoding detection and conversion (UTF-16LE to UTF-8)
- **Environment Variables**: Full expansion support in alias configurations

### User Configuration System
The system supports user-specific configurations in `~/.config/wslutil/`:

- **wslutil.yml**: User-specific Windows executable symlinks (winrun/winexe entries)
- **win-run.yml**: User-specific aliases and configurations
- **wsl.conf**: User WSL settings (merged into /etc/wsl.conf)
- **wslconfig**: User WSL2 settings (merged into Windows user profile)
- **wslgconfig**: User WSLg settings (merged into Windows user profile)

Configuration hierarchy: System configs processed first, then user configs override defaults.