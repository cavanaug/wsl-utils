# Implementation Tasks

## Phase 1: Critical Security Fixes (Immediate)

### 1. Command Injection Prevention
- [ ] 1.1 Fix PowerShell command injection in bin/win-run:476-487
- [ ] 1.2 Fix PowerShell command injection in bin/win-run:131-132
- [ ] 1.3 Add tests for command injection prevention
- [ ] 1.4 Verify all PowerShell executions use safe parameter passing

### 2. Restrict envsubst Variable Expansion
- [ ] 2.1 Restrict envsubst in bin/wslutil-setup:266
- [ ] 2.2 Restrict envsubst in bin/win-run:130
- [ ] 2.3 Restrict envsubst in bin/win-run:171
- [ ] 2.4 Add tests for safe environment variable expansion
- [ ] 2.5 Document allowed variables in comments

### 3. Fix Race Condition in Cache Building
- [ ] 3.1 Move file operations inside lock in env/shellenv.bash:70-72
- [ ] 3.2 Add atomic file creation checks
- [ ] 3.3 Test concurrent cache building with multiple processes
- [ ] 3.4 Add error handling for lock acquisition failures

### 4. Validate Cache Files Before Sourcing
- [ ] 4.1 Add validation function for cache file contents in env/shellenv.bash
- [ ] 4.2 Implement content checking before sourcing at line 117-119
- [ ] 4.3 Add integrity checking (optional: checksums)
- [ ] 4.4 Add tests for malicious cache file rejection
- [ ] 4.5 Document cache file format requirements

## Phase 2: High Priority Improvements (1-2 weeks)

### 5. Quote PowerShell Variables
- [ ] 5.1 Fix PowerShell variable quoting in bin/wslutil-setup:305-312
- [ ] 5.2 Fix PowerShell variable quoting in bin/win-paste:73
- [ ] 5.3 Add standard function for safe PowerShell command construction
- [ ] 5.4 Audit all PowerShell invocations for proper quoting

### 6. Path Traversal Validation
- [ ] 6.1 Create path validation function in lib/wslutil-security.sh
- [ ] 6.2 Add path validation to bin/win-run:424-437
- [ ] 6.3 Add path validation to bin/win-open:20-26
- [ ] 6.4 Add path validation to bin/win-browser:23-29
- [ ] 6.5 Add tests for path traversal attack prevention
- [ ] 6.6 Document allowed path boundaries

### 7. Sanitize Log Output
- [ ] 7.1 Create log sanitization function in lib/wslutil-logging.sh
- [ ] 7.2 Apply sanitization to bin/win-run:463
- [ ] 7.3 Apply sanitization to bin/win-browser:55
- [ ] 7.4 Apply sanitization to bin/win-copy:65-71
- [ ] 7.5 Apply sanitization to bin/win-paste:65-71
- [ ] 7.6 Add tests for log injection prevention
- [ ] 7.7 Add timestamp to all log entries

### 8. Fix Unsafe Command Substitution
- [ ] 8.1 Fix command substitution in bin/wslutil:87-91
- [ ] 8.2 Fix command substitution in bin/wslutil-doctor:80
- [ ] 8.3 Convert to array-based approach using readarray
- [ ] 8.4 Add tests for special characters in command output

### 9. Fix Unquoted Array Expansion
- [ ] 9.1 Fix BROWSER_ARGS expansion in bin/win-browser:57
- [ ] 9.2 Fix array expansion in bin/win-open:31
- [ ] 9.3 Convert string variables to arrays where appropriate
- [ ] 9.4 Add tests for arguments with spaces and special characters

## Phase 3: Medium Priority Enhancements (1 month)

### 10. Improve Git Error Handling
- [ ] 10.1 Remove subshell in bin/wslutil:37-41
- [ ] 10.2 Remove subshell in bin/wslutil:50-53
- [ ] 10.3 Add proper error propagation
- [ ] 10.4 Add directory existence checks before cd
- [ ] 10.5 Test error conditions

### 11. Standardize Error Messages
- [ ] 11.1 Create error function in lib/wslutil-common.sh
- [ ] 11.2 Audit all scripts for error message format
- [ ] 11.3 Update bin/wslutil to use standard format
- [ ] 11.4 Update bin/win-run to use standard format
- [ ] 11.5 Update bin/wslutil-setup to use standard format
- [ ] 11.6 Update all other scripts

### 12. Add Input Validation in Main Dispatcher
- [ ] 12.1 Add argument count check in bin/wslutil:61
- [ ] 12.2 Add helpful error message for missing arguments
- [ ] 12.3 Add tests for edge cases

### 13. Create Log Files with Restricted Permissions
- [ ] 13.1 Add permission setting in bin/win-run:451-463
- [ ] 13.2 Add permission setting to all scripts with logging
- [ ] 13.3 Create log directory with restricted permissions (700)
- [ ] 13.4 Test log file creation and permissions

### 14. Improve Symlink Validation
- [ ] 14.1 Add broken symlink detection in bin/wslutil-setup:232-235
- [ ] 14.2 Add broken symlink detection in bin/wslutil-setup:333-342
- [ ] 14.3 Add circular reference detection
- [ ] 14.4 Add tests for edge cases

### 15. Optimize Cache Building with Parallelization
- [ ] 15.1 Update PowerShell script in bin/wslutil-setup:368-397
- [ ] 15.2 Add parallel foreach with throttling
- [ ] 15.3 Benchmark performance improvement
- [ ] 15.4 Test for race conditions

### 16. Validate yq/crudini Output
- [ ] 16.1 Add validation wrapper for yq in bin/wslutil-setup:194
- [ ] 16.2 Add validation wrapper for yq in bin/win-run:126
- [ ] 16.3 Check for malformed YAML/INI output
- [ ] 16.4 Add error messages for parsing failures

### 17. Create Centralized Configuration Library
- [ ] 17.1 Create lib/wslutil-common.sh
- [ ] 17.2 Add source_wslutil_config function
- [ ] 17.3 Consolidate all WIN_* variable defaults
- [ ] 17.4 Update all scripts to source common library
- [ ] 17.5 Test configuration loading

### 18. Add Unit Tests for Critical Functions
- [ ] 18.1 Create tests/test_security.bats
- [ ] 18.2 Add tests for resolve_alias function
- [ ] 18.3 Add tests for ensure_utf8 function
- [ ] 18.4 Add tests for path conversion logic
- [ ] 18.5 Add tests for error handling paths
- [ ] 18.6 Achieve >80% coverage of critical paths

## Phase 4: Low Priority Refinements (Ongoing)

### 19. Extract UTF-8 Encoding Logic
- [ ] 19.1 Create lib/wslutil-utf8.sh
- [ ] 19.2 Extract common UTF-8 logic from bin/win-run
- [ ] 19.3 Extract common UTF-8 logic from bin/win-utf8
- [ ] 19.4 Update scripts to use shared library

### 20. Centralize PowerShell Path Configuration
- [ ] 20.1 Add POWERSHELL_EXE to lib/wslutil-common.sh
- [ ] 20.2 Update bin/win-run:178
- [ ] 20.3 Update bin/win-paste:73
- [ ] 20.4 Update bin/wslutil-setup:305
- [ ] 20.5 Update all other scripts

### 21. Replace Magic Numbers with Constants
- [ ] 21.1 Add CHUNK_SIZE constant in bin/win-run:195
- [ ] 21.2 Add CHUNK_SIZE constant in bin/ensure_utf8:6
- [ ] 21.3 Document rationale for chosen values

### 22. Remove Commented-Out Code
- [ ] 22.1 Remove commented code in env/shellenv.bash:138-166
- [ ] 22.2 Remove commented code in config/wslutil.yml:17,23-25,43-47
- [ ] 22.3 Add git commit notes explaining removals if needed

### 23. Add File Permission Checks in Installer
- [ ] 23.1 Add executable check in install.sh:196-200
- [ ] 23.2 Add ownership check
- [ ] 23.3 Add warning messages for permission issues

### 24. Add Timeout to Blocking Operations
- [ ] 24.1 Add timeout to Windows command in env/shellenv.bash:51-52
- [ ] 24.2 Add error handling for timeout cases
- [ ] 24.3 Test timeout behavior

### 25. Centralize Logging Functionality
- [ ] 25.1 Create lib/wslutil-logging.sh
- [ ] 25.2 Add wslutil_log function
- [ ] 25.3 Update all scripts to use centralized logging
- [ ] 25.4 Ensure consistent log format

### 26. Add Dependency Version Checks
- [ ] 26.1 Create check_dependencies function
- [ ] 26.2 Add yq version check
- [ ] 26.3 Add crudini version check (if used)
- [ ] 26.4 Add python3 version check (if used)
- [ ] 26.5 Call from wslutil-doctor

### 27. Standardize Shebang Lines
- [ ] 27.1 Audit all scripts for shebang consistency
- [ ] 27.2 Update to #!/usr/bin/env bash
- [ ] 27.3 Test on different systems

### 28. Add GNU Tools Verification
- [ ] 28.1 Create tool detection function
- [ ] 28.2 Add stat command detection
- [ ] 28.3 Add date command detection
- [ ] 28.4 Provide fallbacks for BSD versions

### 29. Add Integration Tests for Windows Interop
- [ ] 29.1 Create tests/test_integration_windows.bats
- [ ] 29.2 Add test for win-run with cmd.exe
- [ ] 29.3 Add test for win-open
- [ ] 29.4 Add test for win-browser
- [ ] 29.5 Add test for clipboard operations

### 30. Add Error Condition Tests
- [ ] 30.1 Create tests/test_error_handling.bats
- [ ] 30.2 Add test for nonexistent executable
- [ ] 30.3 Add test for invalid arguments
- [ ] 30.4 Add test for permission errors
- [ ] 30.5 Add test for network failures

### 31. Optimize grep/sed Pipelines
- [ ] 31.1 Replace pipeline in bin/wslutil-setup:194 with awk
- [ ] 31.2 Benchmark performance improvement
- [ ] 31.3 Test output equivalence

## Validation

- [ ] Run full BATS test suite and ensure all tests pass
- [ ] Run wslutil-doctor to verify system health
- [ ] Test on WSL1 and WSL2 environments
- [ ] Perform security audit of changes
- [ ] Update documentation for any new patterns
- [ ] Run openspec validate --strict
