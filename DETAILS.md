# wsl-utils - Detailed Documentation

This document provides comprehensive information about wsl-utils configuration, advanced usage, environment variables, and troubleshooting.

## Configuration

### Environment Variables

**Core System Variables:**

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

1. **Factory Configuration:** Resolved from the command location: `${PREFIX}/share/wslutil/config/` for `make install`, or `config/` in a checkout.
2. **User Configuration:** `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/`

**Supported Configuration Files:**

* `wslutil.yml` - Windows executable configuration for `wslutil setup exes` and `win-run`

#### Windows Executable Configuration (wslutil.yml)

A single `wslutil.yml` file drives both PATH symlinks (`wslutil setup exes`) and runtime path/options resolution (`win-run`). Factory and user configs are merged **by name**: factory entries are loaded first, then user entries replace whole entries for matching keys.

**Locations:**

1. **Factory:** `${PREFIX}/share/wslutil/config/wslutil.yml` (or `config/wslutil.yml` in a checkout)
2. **User:** `${XDG_CONFIG_HOME:-$HOME/.config}/wslutil/wslutil.yml` (delta overrides only)

**Schema:**

```yaml
exes:
  <name>:
    mode: direct | shim | none   # required
    path: <string>               # optional; supports ${WIN_*} expansion
    options: <string> | null     # optional; prepended by win-run only
```

| `mode` | `setup exes` (PATH link) | Runtime (`win-run`) |
|--------|--------------------------|---------------------|
| `direct` | Symlink `$SHIMDIR/<name>` → Windows exe | Not used (invoked directly) |
| `shim` | Symlink `$SHIMDIR/<name>` → `win-run` | Path convert + UTF-8; uses `path` / `options` if set |
| `none` | No link; **removes** existing `$SHIMDIR/<name>` if present | `win-run <name>` only; prefers `path` when set |

When `path` is omitted, `setup exes` discovers the Windows executable via PATH cache / `Get-Command`; `win-run` uses the bare command name.

**User override example** (`~/.config/wslutil/wslutil.yml`):

```yaml
exes:
  notepad++.exe:
    mode: shim
    path: ${WIN_PROGRAMFILES}/Notepad++/notepad++.exe
  mytool.exe:
    mode: none
    path: ${WIN_USERPROFILE}/tools/mytool.exe
    options: "--quiet"
  # Disable a factory PATH link without editing factory config:
  cmd.exe:
    mode: none
```

**Custom config file** (`-c` / `--config`): loads that file only — no factory+user merge.

**Migration from old schemas:**

| Old | New |
|-----|-----|
| `winexe: [cmd.exe]` | `exes.cmd.exe: { mode: direct }` |
| `winexe: ["${…}/brave.exe"]` | `exes.brave.exe: { mode: direct, path: "${…}/brave.exe" }` |
| `winrun: [notepad.exe]` | `exes.notepad.exe: { mode: shim }` |
| `aliases.foo.path` / `options` in `win-run.yml` | `exes.foo: { mode: none, path, options }` (or `shim`/`direct` if a PATH link is desired) |

Old `winexe` / `winrun` / `aliases` keys and `win-run.yml` are no longer read. If `~/.config/wslutil/win-run.yml` still exists, `win-run` and `setup exes` warn that entries should be moved into `wslutil.yml`.

**Usage examples:**

```bash
# Create/update PATH symlinks from merged config
wslutil setup exes

# Use a single config file (no merge)
wslutil setup exes -c ~/.config/wslutil/wslutil.yml

# win-run resolves path/options from the same merged config
win-run brave.exe https://example.com
win-run -c project.yml custom-tool.exe
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

**Pattern 4: WSL System Monitoring**
```bash
# Monitor WSL distribution uptime (not VM uptime)
wslutil uptime                       # Standard uptime format
wslutil uptime --pretty              # Human-readable format  
wslutil uptime --since               # Show WSL distro start time
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

Add entries under `exes` in `~/.config/wslutil/wslutil.yml`:

```yaml
exes:
  myapp.exe:
    mode: none
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

**WSL Distribution Monitoring**
```bash
# Check WSL distribution uptime (different from system uptime)
wslutil uptime                       # Shows WSL distro uptime, not VM
uptime                               # Shows underlying system/VM uptime

# Useful for troubleshooting WSL restarts vs system reboots
wslutil uptime --since               # When did WSL distro last start?
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
- Cache frequently used Windows executable paths in `wslutil.yml` `exes` entries

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