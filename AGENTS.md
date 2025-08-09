# AGENTS.md - Development Guidelines for wsl-utils

## Test & Build Commands
- Run all tests: `tests/run_tests.sh`
- Run single test: `tests/run_tests.sh test_option_parsing.bats`
- Run with verbose: `tests/run_tests.sh -v`
- Test requirements: `bats` (Bash Automated Testing System), `yq` (YAML processor)

## Code Style & Conventions

### Bash Scripts
- Use `#!/bin/bash` shebang
- Set strict mode: `set -euo pipefail`
- Use UPPER_CASE for environment variables and constants
- Use snake_case for local variables and functions
- Quote all variable expansions: `"$variable"`
- Use `[[ ]]` for conditionals, not `[ ]`

### Error Handling
- Always check command success with `set -e` or explicit checks
- Use `>&2` for error messages: `echo "Error: message" >&2`
- Exit with non-zero codes on failure
- Provide helpful error messages with context

### Path Handling
- Use `wslpath -w` for WSL-to-Windows path conversion
- Use absolute paths in scripts: `"$(dirname "$(dirname "$0")")"`
- Check file existence before operations: `[[ -f "$file" ]]`

### Configuration
- YAML files use 2-space indentation
- Environment variable substitution: `${WIN_PROGRAMFILES}`
- Config hierarchy: global → user (user config takes precedence)

### Documentation
- Include ASCII art headers in main scripts
- Provide `--help` options with usage examples
- Use inline comments for complex logic only
- Document environment variables and dependencies