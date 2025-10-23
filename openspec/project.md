# Project Context

## Purpose
`wsl-utils` is a collection of command-line utilities that simplify interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment. The project provides seamless integration for common tasks like clipboard operations, file opening, browser launching, and Windows command execution with automatic path conversion.

## Tech Stack
- Bash shell scripting (primary language)
- YAML configuration (yq for parsing)
- PowerShell (for Windows integration)
- BATS (Bash Automated Testing System)
- Git Cliff (for changelog generation)

## Project Conventions

### Code Style
- Use 2-space indentation in shell scripts
- Function names use snake_case
- Global variables use UPPERCASE_WITH_UNDERSCORES
- Local variables use lowercase_with_underscores
- Prefix Windows-related environment variables with `WIN_`
- Use `#!/usr/bin/env bash` shebang for portability
- Always use `set -euo pipefail` for error handling in scripts
- Quote all variable expansions unless explicitly needed otherwise
- Use `[[ ]]` for conditionals instead of `[ ]`
- Prefer `$(command)` over backticks for command substitution

### Architecture Patterns
- **Dispatcher Pattern**: `wslutil` acts as main entry point, discovers and routes to `wslutil-*` subcommands
- **Layered Configuration**: System configs in `/etc/`, user configs in `~/.config/wslutil/`, custom test configs
- **Shim Pattern**: `win-run` acts as intelligent wrapper for Windows commands with automatic path conversion
- **Environment Encapsulation**: Windows environment variables cached and exposed via `WIN_*` variables
- **Auto-discovery**: Subcommands automatically discovered from PATH, no manual registration needed

### Testing Strategy
- BATS framework for all test suites
- Test files named `test_<feature>.bats`
- Helper functions in `test_helpers.bash`
- Unit tests for core functionality (path conversion, option parsing, alias resolution)
- Integration tests for end-to-end workflows
- Mock Windows commands and filesystem in test environment
- Run tests via `./tests/run_tests.sh`
- Use temporary directories (`$BATS_TMPDIR`) for test isolation

### Git Workflow
- Standard commit message format: `<type>: <description>`
- Use Git Cliff (cliff.toml) for automated changelog generation
- Keep CHANGELOG.md updated via `git cliff`
- No specific branching strategy documented (appears to use main branch)

## Domain Context
- **WSL Interop**: Understanding of WSL's `/run/WSL/*_interop` socket mechanism
- **Path Conversion**: WSL paths (`/mnt/c/...`) ⟷ Windows paths (`C:\...`) conversion via `wslpath`
- **UTF-8/UTF-16LE Encoding**: Windows PowerShell outputs UTF-16LE, requires conversion for WSL
- **Windows Environment Access**: Accessing Windows environment variables from WSL context
- **Executable Resolution**: Windows executable lookup via PowerShell's `Get-Command` and PATH caching

## Important Constraints
- Must work across different WSL distributions (WSL1 and WSL2)
- Must not rely on specific shell initialization (use `-NoProfile` with PowerShell)
- Path conversion must handle spaces and special characters correctly
- UTF-8 encoding must be enforced for all Windows command output
- Must be shell-agnostic where possible (bash, zsh compatibility)
- No hardcoded Windows paths (use environment variables or dynamic detection)
- Must work without root privileges for user-space operations

## External Dependencies
- **Required**: `wslpath`, `wslvar`, basic Unix utilities (`dirname`, `basename`, etc.)
- **Recommended**: `yq` (YAML parsing), `powershell.exe` (Windows integration)
- **Optional**: `git` (for upgrade command), `bats` (for testing)
- **Windows Side**: PowerShell 5.0+, standard Windows utilities (`cmd.exe`, `clip.exe`, etc.)
