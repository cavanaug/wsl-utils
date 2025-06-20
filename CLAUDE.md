# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `wsl-utils`, a collection of command-line utilities that simplify interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment. The main entry point is `wslutil`, which acts as a dispatcher for various subcommands and helper scripts.

## Architecture

### Core Components

- **`wslutil`** (bin/wslutil): Main dispatcher script that handles subcommands and discovers external `wslutil-*` scripts
- **Subcommands**: Individual `wslutil-*` scripts (e.g., `wslutil-doctor`) that implement specific functionality
- **Windows Integration Helpers**: `win-*` scripts that provide direct integration with Windows features
- **Environment Setup**: Shell environment configuration via `env/shellenv.*` files
- **Configuration**: YAML-based configuration in `conf.yml` for Windows executable shimming

### Key Scripts

- `bin/wslutil`: Main entry point and command dispatcher
- `bin/wslutil-doctor`: Health check and diagnostic tool for WSL environment
- `bin/win-run`: Execute Windows commands with automatic path conversion
- `bin/win-browser`: Open files/URLs in Windows default browser
- `bin/win-copy`/`bin/win-paste`: Windows clipboard integration
- `bin/win-open`: Open files with Windows default applications
- `env/shellenv.bash`: Environment variable setup for Windows interop

### Environment Variables

The system relies on several environment variables set by `wslutil shellenv`:
- `WSLUTIL_DIR`: Installation directory
- `WIN_USERPROFILE`: Windows user profile path (converted to WSL format)
- `WIN_WINDIR`: Windows directory path (converted to WSL format)
- `WSL_INTEROP`: WSL interop socket path
- `WIN_ENV[]`: Associative array of Windows environment variables

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

## Development Notes

### Path Conversion
The `win-run` script automatically converts WSL paths to Windows format for any arguments that are existing files or directories using `wslpath -w`.

### Configuration Format
The `conf.yml` file defines Windows executables to be shimmed, categorized as:
- Direct links (no argument processing)
- Shims (processed through `win-run` for path conversion)

### Extensibility
Custom subcommands can be added by creating executable `wslutil-<name>` scripts in PATH. They will be automatically discovered and available as `wslutil <name>`.

### Shell Environment Detection
The system detects the current shell via `$SHELL` and loads the appropriate `env/shellenv.<shell>` file.