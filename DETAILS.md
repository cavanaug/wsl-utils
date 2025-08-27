# wsl-utils - Detailed Documentation

This document provides comprehensive information about wsl-utils configuration, advanced usage, environment variables, and troubleshooting.

## Configuration

### Environment Variables

**Core System Variables:**

* `WSLUTIL_DIR` - Installation directory (auto-detected from script location)
* `WSL_INTEROP` - WSL interop socket path (default: `/run/WSL/1_interop`)

**Windows Environment Variables:**

* `WIN_USERPROFILE` - Windows user profile path (e.g., `/mnt/c/Users/username`)
* `WIN_WINDIR` - Windows directory path (e.g., `/mnt/c/Windows`)
* `WIN_PROGRAMFILES` - Program Files directory (e.g., `/mnt/c/Program Files`)
* `WIN_PROGRAMFILES_X86` - Program Files (x86) directory
* `WIN_LOCALAPPDATA` - User's Local AppData directory
* `WIN_APPDATA` - User's Roaming AppData directory
* `WIN_ENV[]` - Associative array containing Windows environment variables

**⚠️ Important Notes:**
- The `WIN_ENV[]` associative array is only available in the main shell session and is not passed to subshells or scripts
- Logging is opt-in and must be enabled with `WSLUTIL_DEBUG=1` environment variable

### User Configuration

`wsl-utils` supports user-specific configuration files that override system defaults. This allows customization without modifying the installed files.

**Configuration File Locations:**

1. **System Configuration:** `${WSLUTIL_DIR}/config/`
2. **User Configuration:** `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/`

**Supported Configuration Files:**

* `conf.yml` - Windows executable configuration for `wslutil setup`
* `win-run.yml` - Aliases for `win-run` command

#### Windows Executable Configuration (conf.yml)

Controls which Windows executables get symlinked by `wslutil setup`:

```yaml
direct_links:
  - cmd.exe
  - ipconfig.exe
  - ping.exe

shims:
  - notepad.exe
  - explorer.exe
```

**Categories:**
- **direct_links**: Create direct symlinks to Windows executables
- **shims**: Create symlinks that route through `win-run` for path conversion

#### Win-Run Aliases (win-run.yml)

Define custom aliases for Windows applications:

```yaml
aliases:
  brave.exe:
    path: ${WIN_PROGRAMFILES}/BraveSoftware/Brave-Browser/Application/brave.exe
    options: null
  devenv.exe:
    path: ${WIN_PROGRAMFILES}/Microsoft Visual Studio/2022/Community/Common7/IDE/devenv.exe
    options: "--startup-option"
```

**Fields:**
- **path**: Full path to the Windows executable (supports environment variable expansion)
- **options**: Additional command-line options to prepend (optional)

**Usage Example:**
```bash
# Using custom config file
wslutil setup -c ~/.config/wslutil/conf.yml

# Win-run will automatically resolve aliases
win-run brave.exe https://example.com
```

## Advanced Features

### Path Conversion with Drive Substitution

The `wslpath-drive` utility extends standard `wslpath` functionality with support for Windows drive substitution:

```bash
# Standard conversion
wslpath-drive -w /home/user/file.txt
# Output: \\wsl.localhost\distro\home\user\file.txt

# With drive substitution (if Z: maps to \\wsl.localhost\distro)
wslpath-drive -W /home/user/file.txt  
# Output: Z:\home\user\file.txt

# Forward slash version
wslpath-drive -M /mnt/c/projects
# Output: Z:/home/user/file.txt (if substituted)
```

### Windows Integration Patterns

**Pattern 1: Direct Command Execution**
```bash
# Execute Windows commands with automatic path conversion
win-run notepad.exe /home/user/file.txt
win-run powershell.exe -Command "Get-Process"
```

**Pattern 2: Pipeline Integration**
```bash
# Process Windows command output
win-run cmd.exe /c dir | grep ".txt"
win-run powershell.exe -Command "Get-Service" | grep "Running"
```

**Pattern 3: Clipboard Workflows**
```bash
# Copy-paste workflows
ls -la | win-copy                    # Copy to Windows clipboard
win-paste | grep "important"         # Search clipboard content
win-paste > restored.txt             # Save clipboard to file
```

### Extensibility

**Adding Custom Subcommands:**

Create executable scripts named `wslutil-<name>` in your PATH:

```bash
#!/bin/bash
# ~/.local/bin/wslutil-mycommand
echo "This is my custom wslutil command"
```

Usage: `wslutil mycommand`

**Custom Windows Integration:**

Create aliases in `win-run.yml` for Windows applications:

```yaml
aliases:
  myapp.exe:
    path: ${WIN_PROGRAMFILES}/MyApp/bin/myapp.exe
    options: "--default-config"
```

## Troubleshooting

### Common Issues

**Environment Variables Not Set**
```bash
# Check if environment is loaded
echo $WIN_USERPROFILE

# Manually load if needed
eval "$(wslutil shellenv)"
```

**WSL Interop Issues**
```bash
# Check WSL interop status
wslutil doctor

# Verify interop socket
ls -la $WSL_INTEROP
```

**Path Conversion Problems**
```bash
# Test path conversion
wslpath-drive -w /home/user/test.txt

# Check for drive substitution
win-run subst.exe
```

**Encoding Issues with Windows Output**
```bash
# Use win-run for automatic encoding handling
win-run cmd.exe /c dir

# Manual encoding conversion (advanced)
powershell.exe -Command "Get-Process" | win-utf8
```

### Debugging

Enable debug logging:
```bash
export WSLUTIL_DEBUG=1
win-run notepad.exe /tmp/test.txt
# Check logs in ~/.local/state/wslutil/win-run.log
```

### Performance

**Optimizing Windows Command Execution:**
- Use `win-run --raw` for binary output to skip encoding conversion
- Use `win-run --plain` to skip automatic path conversion when not needed
- Cache frequently used Windows executable paths in win-run.yml aliases

## Testing

This project includes comprehensive tests using the Bats (Bash Automated Testing System) framework.

### Running Tests

**Prerequisites:**
```bash
# Install bats-core (example for Ubuntu/Debian)
sudo apt-get install bats

# Or install via npm
npm install -g bats
```

**Execute Tests:**
```bash
# Run all tests
make test

# Run specific test file
bats test/wslutil-setup.bats

# Verbose output
bats --verbose test/
```

### Test Structure

- `test/` - Test files (*.bats)
- `test/fixtures/` - Test data and configuration files
- `test/helpers/` - Common test utilities

**Test Categories:**
- Unit tests for individual script functions
- Integration tests for command workflows
- Configuration validation tests
- Cross-platform compatibility tests

## Environment-Specific Notes

### WSL1 vs WSL2

**WSL1:**
- Direct Windows filesystem access via `/mnt/c/`
- No WSLg support (manual clipboard handling)

**WSL2:**
- Network-based Windows integration
- WSLg support for native clipboard operations
- Enhanced security model

### Windows Version Compatibility

**Windows 10:**
- Basic WSL interop support
- Manual PATH management for Windows executables

**Windows 11:**
- Enhanced WSL integration
- Improved performance for cross-system operations
- Better Unicode support

## Contributing

### Development Setup

1. Fork the repository
2. Clone your fork: `git clone <your-fork-url>`
3. Create a feature branch: `git checkout -b feature-name`
4. Make changes and add tests
5. Run tests: `make test`
6. Commit with conventional commit format
7. Submit a pull request

### Code Style

- Use `shellcheck` for shell script linting
- Follow existing code formatting patterns
- Add documentation for new features
- Include tests for new functionality

### Release Process

This project uses `git-cliff` for changelog generation:

```bash
# Generate changelog for new version
git cliff --tag v0.6.0 --output CHANGELOG.md

# Tag and push
git tag v0.6.0
git push origin v0.6.0
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.