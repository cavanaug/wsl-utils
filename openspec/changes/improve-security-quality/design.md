# Design Document: Security and Quality Improvements

## Context

A comprehensive security and code quality review identified 31 issues across the wsl-utils codebase, ranging from critical command injection vulnerabilities to minor code quality improvements. This change addresses all identified issues through a phased implementation approach that prioritizes security fixes while improving overall code quality, performance, and maintainability.

### Background
- Codebase: ~2,500 lines of Bash scripting across 15+ files
- No existing formal specifications or security guidelines
- Windows-WSL integration creates unique security challenges
- Current architecture has some code duplication and inconsistent patterns

### Stakeholders
- **Users**: Benefit from improved security and reliability
- **Contributors**: Benefit from clearer patterns and better documentation
- **Security auditors**: Benefit from documented security controls

## Goals / Non-Goals

### Goals
1. **Eliminate critical security vulnerabilities** (command injection, race conditions, unsafe eval)
2. **Establish security best practices** for Windows-WSL integration
3. **Improve code maintainability** through centralization and standardization
4. **Add comprehensive test coverage** for critical paths
5. **Maintain backward compatibility** - no breaking changes

### Non-Goals
1. Rewriting scripts in a different language
2. Changing user-facing APIs or command-line interfaces
3. Adding new features beyond security improvements
4. Optimizing for performance where security is not impacted

## Decisions

### Decision 1: Phased Implementation Approach
**Choice**: Implement in 4 phases (Critical → High → Medium → Low priority)

**Rationale**:
- Allows immediate addressing of critical security vulnerabilities
- Permits testing and validation at each phase
- Reduces risk of introducing breaking changes
- Allows for feedback incorporation between phases

**Alternatives Considered**:
- All-at-once implementation: Too risky, harder to test
- Issue-by-issue implementation: Too slow for critical security fixes

### Decision 2: Restrict envsubst Variable Expansion
**Choice**: Use explicit variable whitelist with envsubst

**Rationale**:
- Prevents command injection via crafted environment variables
- Maintains existing configuration file format
- Minimal impact on legitimate use cases

**Alternatives Considered**:
- Remove envsubst entirely: Rejected, breaks existing config flexibility
- Bash parameter expansion only: More complex for nested references
- Full YAML variable interpolation: Requires additional dependencies

### Decision 3: PowerShell Command Execution Strategy
**Choice**: Use PowerShell's `-Command` with proper quoting and parameter separation

**Rationale**:
- Prevents command injection while maintaining functionality
- Works with existing PowerShell infrastructure
- No dependency on PowerShell scripts or modules

**Alternatives Considered**:
- Base64-encoded commands (`-EncodedCommand`): More complex, harder to debug
- PowerShell script files: Adds filesystem dependencies
- Migrate to direct Win32 API calls: Too complex, reduces portability

### Decision 4: Path Validation Approach
**Choice**: Validate paths are within `$HOME` or `$PWD` boundaries

**Rationale**:
- Prevents most path traversal attacks
- Aligns with principle of least privilege
- Clear security boundary for users

**Alternatives Considered**:
- Allow any path: Rejected due to security risk
- Maintain allowlist of specific directories: Too restrictive
- Use realpath canonicalization only: Insufficient without boundary checks

### Decision 5: Cache File Validation Strategy
**Choice**: Validate cache files contain only `WIN_ENV[...]` assignments before sourcing

**Rationale**:
- Simple pattern matching is fast and effective
- Prevents arbitrary code execution
- Maintains cache performance benefits

**Alternatives Considered**:
- Parse as data only (no sourcing): Breaks existing architecture
- Cryptographic signatures: Overkill for local cache files
- No validation: Unacceptable security risk

### Decision 6: Test Framework and Coverage
**Choice**: Continue using BATS, target >80% overall coverage, >90% for security paths

**Rationale**:
- BATS already integrated and working well
- Coverage targets balance thoroughness with pragmatism
- Security-critical paths need highest coverage

**Alternatives Considered**:
- Switch to different framework (shunit2, etc.): Unnecessary disruption
- 100% coverage target: Diminishing returns, impractical
- Lower coverage targets: Insufficient for security assurance

## Architecture Changes

### Current Architecture
```
wsl-utils/
├── bin/              # All executables (main + helpers)
├── config/           # YAML configuration files
├── env/              # Shell environment setup
├── setup/            # Installation scripts
└── tests/            # BATS test suites
```

### New Architecture
```
wsl-utils/
├── bin/              # All executables (main + helpers)
├── config/           # YAML configuration files
├── env/              # Shell environment setup
├── setup/            # Installation scripts
└── tests/            # BATS test suites (expanded)
    ├── test_security.bats          # NEW: Security tests
    ├── test_error_handling.bats    # NEW: Error tests
    └── test_integration_windows.bats # NEW: Integration tests
```

### Security Implementation Approach
Security fixes will be implemented **inline** within each affected script:
- **bin/win-run**: Inline PowerShell command injection prevention and envsubst restrictions
- **bin/wslutil-setup**: Inline envsubst restrictions
- **env/shellenv.bash**: Inline race condition fix and cache validation

## Implementation Details

### Critical Security Fixes (Phase 1)

#### SEC-001: PowerShell Command Injection
**Location**: `bin/win-run:476-487, 131-132`

**Current (vulnerable)**:
```bash
PS_CMD="& \"${CMD}\"${PS_ARGS}"
"$POWERSHELL_EXE" -NoProfile -Command "$PS_CMD"
```

**Fixed**:
```bash
# Build PowerShell script that accepts command and args separately
PS_SCRIPT='param($Cmd, [string[]]$Args) & $Cmd @Args'
"$POWERSHELL_EXE" -NoProfile -Command "$PS_SCRIPT" -Cmd "$CMD" -Args "${CMDARGS[@]}"
```

#### SEC-002: envsubst Restrictions
**Location**: `bin/wslutil-setup:266, bin/win-run:130, 171`

**Current (vulnerable)**:
```bash
executable=$(echo "$executable" | envsubst)
```

**Fixed**:
```bash
# Define allowed variables
ALLOWED_VARS='${WIN_WINDIR} ${WIN_PROGRAMFILES} ${WIN_PROGRAMFILES_X86} ${WIN_USERPROFILE} ${WIN_LOCALAPPDATA} ${WIN_APPDATA}'
executable=$(echo "$executable" | envsubst "$ALLOWED_VARS")
```

#### SEC-003: Race Condition Fix
**Location**: `env/shellenv.bash:70-72`

**Current (vulnerable)**:
```bash
# Release lock
exec 200>&-
# Move files (TOCTOU vulnerability!)
mv -f "${temp_win}" "${WIN_ENV_FILE}.win"
mv -f "${temp_sh}" "${WIN_ENV_FILE}.sh"
```

**Fixed**:
```bash
# Move files while holding lock
if [[ -f "${temp_sh}" ]] && [[ -f "${temp_win}" ]]; then
    mv -f "${temp_win}" "${WIN_ENV_FILE}.win"
    mv -f "${temp_sh}" "${WIN_ENV_FILE}.sh"
fi
# Then release lock
exec 200>&-
```

#### SEC-004: Cache Validation
**Location**: `env/shellenv.bash:117-119`

**Current (vulnerable)**:
```bash
if [[ -f "${WIN_ENV_FILE}.sh" ]]; then
    source "${WIN_ENV_FILE}.sh"
fi
```

**Fixed**:
```bash
if [[ -f "${WIN_ENV_FILE}.sh" ]]; then
    # Validate cache file contains only WIN_ENV assignments
    if grep -qvE '^(WIN_ENV\[|declare -A WIN_ENV|#|$)' "${WIN_ENV_FILE}.sh"; then
        echo "ERROR: Cache file contains suspicious content" >&2
        rm -f "${WIN_ENV_FILE}.sh" "${WIN_ENV_FILE}.win"
        return 1
    fi
    source "${WIN_ENV_FILE}.sh"
fi
```

## Risks / Trade-offs

### Risk 1: Breaking Changes from Security Fixes
**Risk**: Security fixes might break edge cases or undocumented behavior

**Mitigation**:
- Comprehensive test suite before and after changes
- Gradual rollout through phases
- Document all behavioral changes in CHANGELOG
- Provide clear error messages for rejected operations

### Risk 2: Performance Impact from Validation
**Risk**: Additional validation adds overhead to command execution

**Impact Assessment**:
- Path validation: ~1-2ms per path (negligible)
- Cache validation: ~5-10ms once per session (acceptable)
- Log sanitization: <1ms per log entry (negligible)

**Mitigation**:
- Benchmark performance before/after
- Optimize validation logic where possible
- Cache validation results where appropriate

### Risk 3: Test Coverage Gaps
**Risk**: Tests might not cover all edge cases, especially in Windows integration

**Mitigation**:
- Prioritize testing of security-critical paths
- Include negative test cases (expected failures)
- Test on multiple WSL distributions (Ubuntu, Debian, etc.)
- Document known limitations

## Migration Plan

### Phase 1: Critical Security (Week 1)
1. Fix SEC-001 (PowerShell command injection) inline in bin/win-run
2. Fix SEC-002 (envsubst restrictions) inline in bin/wslutil-setup and bin/win-run
3. Fix SEC-003 (race condition) inline in env/shellenv.bash
4. Fix SEC-004 (cache validation) inline in env/shellenv.bash
5. Add security test suite
6. Run full test suite and verify no regressions
7. Deploy to staging/test environment

### Phase 2: High Priority (Weeks 2-3)
1. Implement remaining high-priority security fixes inline
2. Add error handling improvements
3. Add error handling test suite
4. Comprehensive testing
5. Deploy to production

### Phase 3: Medium Priority (Weeks 4-6)
1. Standardize code patterns across all scripts
2. Add integration test suite
3. Performance optimization
4. Documentation updates

### Phase 4: Low Priority (Ongoing)
1. Code cleanup and refactoring
2. Additional test coverage
3. Documentation improvements
4. Performance optimizations

### Rollback Plan
If critical issues are discovered:
1. Revert to previous version via git
2. Identify specific problematic changes
3. Create hotfix for specific issue
4. Re-test and redeploy

### Testing Strategy
Each phase must pass:
- All existing BATS tests
- New tests specific to phase changes
- Manual testing on WSL1 and WSL2
- Security audit checklist verification

## Open Questions

1. **Q**: Should path validation be configurable per-user?
   **A**: No for now. Users needing access outside HOME/PWD should use native Windows tools directly.

2. **Q**: Should we add telemetry/metrics for security events?
   **A**: Deferred to future work. Current focus is on fixing vulnerabilities.

3. **Q**: Should cache validation include checksums/signatures?
   **A**: Not initially. Pattern matching is sufficient for local cache files.

4. **Q**: Should we support Windows Terminal detection for better error formatting?
   **A**: Deferred to future enhancement. Focus on security first.

## Success Criteria

### Phase 1 Success
- ✅ All 4 critical security issues fixed
- ✅ No command injection possible via user input
- ✅ No race conditions in cache operations
- ✅ All existing tests pass
- ✅ New security tests pass

### Overall Success
- ✅ All 31 identified issues resolved
- ✅ Test coverage >80% overall, >90% for security paths
- ✅ No breaking changes to user-facing interfaces
- ✅ Documentation updated
- ✅ Security audit passes
- ✅ Performance within 5% of baseline (non-regression)

## References

- Code Review Report: (agent output from initial review)
- OWASP Shell Injection Guidelines: https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html
- Bash Best Practices: https://mywiki.wooledge.org/BashGuide/Practices
- TOCTOU Attacks: https://en.wikipedia.org/wiki/Time-of-check_to_time-of-use
