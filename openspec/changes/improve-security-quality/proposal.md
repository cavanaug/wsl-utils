# Change Proposal: improve-security-quality

## Why

A comprehensive code review identified 31 security, quality, performance, and architecture issues in the wsl-utils codebase. Critical vulnerabilities include command injection risks in PowerShell execution, unsafe use of `envsubst` allowing arbitrary command execution, race conditions in cache file operations, and unsafe eval of untrusted cache files. These issues pose significant security risks and could lead to data loss, privilege escalation, or system compromise.

## What Changes

**Critical Security Fixes (Immediate - Phase 1):**
- Fix command injection in PowerShell command construction (bin/win-run)
- Restrict envsubst variable expansion to prevent command injection (bin/wslutil-setup, bin/win-run)
- Eliminate race condition in WIN_ENV cache building (env/shellenv.bash)
- Add validation before sourcing cache files to prevent arbitrary code execution (env/shellenv.bash)

**High Priority Improvements (1-2 weeks - Phase 2):**
- Quote all PowerShell variables properly (bin/wslutil-setup, bin/win-paste)
- Add path traversal validation for user-provided paths (bin/win-run, bin/win-open, bin/win-browser)
- Sanitize log output to prevent log injection attacks (all scripts with logging)
- Fix unsafe command substitution patterns in loops (bin/wslutil, bin/wslutil-doctor)
- Fix unquoted array expansion issues (bin/win-browser, bin/win-open)

**Medium Priority Enhancements (1 month - Phase 3):**
- Improve error handling in git operations (bin/wslutil)
- Standardize error message formatting across all scripts
- Add input validation in main dispatcher (bin/wslutil)
- Create log files with restricted permissions (all scripts)
- Improve symlink validation robustness (bin/wslutil-setup)
- Optimize Windows executable cache building with parallelization (bin/wslutil-setup)
- Add validation of yq/crudini output (bin/wslutil-setup, bin/win-run)
- Create centralized configuration management library (new: lib/wslutil-common.sh)
- Add comprehensive unit tests for critical functions (tests/)

**Low Priority Refinements (Ongoing - Phase 4):**
- Extract duplicate UTF-8 encoding logic to shared library (bin/win-run, bin/win-utf8)
- Centralize PowerShell path configuration (all scripts)
- Replace magic numbers with named constants (bin/win-run, bin/ensure_utf8)
- Remove commented-out code blocks (env/shellenv.bash, config/wslutil.yml)
- Add file permission checks in installer (install.sh)
- Add timeout to blocking Windows operations (env/shellenv.bash)
- Centralize logging functionality (new: lib/wslutil-logging.sh)
- Add dependency version checks (new validation functions)
- Standardize shebang lines for portability (all scripts)
- Add GNU tools verification for compatibility (helper functions)
- Add integration tests for Windows interop (tests/)
- Add error condition tests (tests/)
- Optimize grep/sed pipelines (bin/wslutil-setup)

## Impact

**Affected Specs:**
This change creates new specifications as none currently exist:
- `security-hardening` - Security requirements for safe command execution, input validation, file permissions
- `error-handling` - Error handling patterns, validation, and user feedback
- `code-quality` - Code standards, testing requirements, maintainability
- `windows-integration` - Safe Windows command execution and path handling
- `performance` - Optimization patterns for cache building and command execution
- `architecture` - Shared libraries, centralized configuration, logging patterns

**Affected Code:**
- `bin/win-run` - Major security fixes, path validation, logging improvements
- `bin/wslutil` - Input validation, error handling improvements
- `bin/wslutil-setup` - Security fixes, performance optimizations, validation
- `bin/wslutil-doctor` - Command substitution fixes
- `bin/win-browser` - Array expansion fixes, path validation
- `bin/win-copy` - Log sanitization, security hardening
- `bin/win-paste` - Variable quoting, log sanitization
- `bin/win-open` - Path validation, array expansion fixes
- `env/shellenv.bash` - Critical race condition fix, validation improvements
- `install.sh` - Permission checks
- `config/wslutil.yml` - Cleanup of commented code
- **New files:**
  - `lib/wslutil-common.sh` - Centralized configuration management
  - `lib/wslutil-logging.sh` - Centralized logging functionality
  - `lib/wslutil-security.sh` - Security validation functions
  - `tests/test_security.bats` - Security test suite
  - `tests/test_error_handling.bats` - Error handling tests
  - `tests/test_integration_windows.bats` - Windows integration tests

**Breaking Changes:**
None - all fixes maintain backward compatibility while improving security and reliability.

**Migration Notes:**
- Log file permissions will be automatically updated to 600 on next run
- Cache files will be automatically regenerated with new validation on next shellenv call
- No user action required
