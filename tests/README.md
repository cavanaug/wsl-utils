# WSL-Utils Test Suite

This directory contains the BATS (Bash Automated Testing System) test suite for wsl-utils, specifically focusing on `win-run` functionality.

## Prerequisites

- BATS (Bash Automated Testing System)
- `yq` (YAML processor)
- WSL environment (for some tests)

### Installing BATS

**Ubuntu/Debian:**
```bash
sudo apt install bats
```

**macOS:**
```bash
brew install bats-core
```

**From source:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Installing yq

**Ubuntu/Debian:**
```bash
sudo apt install yq
```

**macOS:**
```bash
brew install yq
```

## Running Tests

### Run All Tests
```bash
./tests/run_tests.sh
```

### Run Specific Test File
```bash
./tests/run_tests.sh test_option_parsing.bats
```

### Run with Verbose Output
```bash
./tests/run_tests.sh -v
```

### Run Individual Test Files Directly
```bash
cd tests
bats test_option_parsing.bats
```

## Test Structure

### Test Files

- **`test_option_parsing.bats`** - Tests command-line option parsing
  - `--help` functionality
  - `-c` config file option
  - `--raw` option
  - Error handling for invalid options

- **`test_alias_resolution.bats`** - Tests alias system
  - Config file loading and hierarchy
  - Environment variable expansion
  - Custom config file support
  - Alias path and options resolution

- **`test_path_conversion.bats`** - Tests path conversion logic
  - WSL to Windows path conversion
  - File vs directory handling
  - Multiple argument processing
  - Environment variable expansion in paths

- **`test_integration.bats`** - Integration tests
  - End-to-end functionality
  - Config hierarchy precedence
  - Comprehensive error handling
  - Logging functionality

- **`test_wslutil_setup.bats`** - Tests for wslutil-setup command
  - Command-line option parsing (--help, --dry-run)
  - YAML configuration processing (wslutil.yml)
  - Symlink creation for winrun and winexe entries
  - Variable expansion in configuration paths
  - Two-phase processing (system and user configs)
  - INI file merging with crudini
  - Windows executable cache building and management
  - Error handling for missing dependencies and files

### Helper Functions

**`test_helpers.bash`** provides common test utilities:
- `setup_test_env()` - Sets up isolated test environment
- `cleanup_test_env()` - Cleans up test artifacts
- `create_test_config()` - Creates test configuration files
- `skip_if_not_wsl()` - Skips tests requiring WSL
- `skip_if_no_yq()` - Skips tests requiring yq

## Test Categories

### Unit Tests
Focus on individual functions and components:
- Option parsing logic
- Alias resolution functions
- Path conversion algorithms

### Integration Tests
Test complete workflows:
- Config loading and precedence
- End-to-end command execution
- Error handling chains
- Logging system

### Environment-Specific Tests
Some tests are conditional:
- **WSL-only tests**: Skipped if not running in WSL
- **yq-dependent tests**: Skipped if yq is not available

## Test Data

Tests use temporary directories and files to avoid affecting the system:
- Config files created in `$BATS_TMPDIR/wsl-utils-test-$$`
- Log files redirected to test-specific locations
- Environment variables isolated per test

## Coverage

The test suite covers:
- ✅ Command-line option parsing
- ✅ Help system functionality
- ✅ Config file validation and loading
- ✅ Alias resolution and environment variable expansion
- ✅ Path conversion logic
- ✅ Error handling and user feedback
- ✅ Logging functionality
- ✅ Config hierarchy (global → user → custom)

## Debugging Tests

### Verbose Output
Use `-v` flag for detailed test output:
```bash
./tests/run_tests.sh -v
```

### Individual Test Debugging
Run specific test with BATS directly:
```bash
bats -t test_option_parsing.bats
```

### Manual Testing
Source test helpers for manual testing:
```bash
source tests/test_helpers.bash
setup_test_env
# Manual testing here
cleanup_test_env
```

## Contributing

When adding new functionality to `win-run`:

1. Add corresponding test cases
2. Update existing tests if behavior changes
3. Ensure all tests pass: `./tests/run_tests.sh`
4. Add integration tests for complex features

### Test Naming Convention
- Test files: `test_<component>.bats`
- Test cases: Descriptive names explaining what is being tested
- Helper functions: Clear, reusable utility functions

### Best Practices
- Use `skip_if_*` functions for conditional tests
- Clean up test artifacts in `teardown()`
- Use meaningful assertions with clear error messages
- Test both success and failure cases