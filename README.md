# wsl-utils

A collection of command-line utilities designed to simplify and enhance the interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment.

## Overview

`wsl-utils` provides a central command, `wslutil`, which acts as a dispatcher for various subcommands aimed at managing the WSL environment, checking its health, and facilitating seamless interaction with Windows tools and files.

## Features

* **Environment Setup:** Easily configure necessary environment variables for WSL-Windows interop using `wslutil shellenv`.
* **Health Checks:** Diagnose potential issues in your WSL setup with comprehensive system checks via `wslutil doctor`.
* **In-Place Upgrades:** Keep `wsl-utils` up-to-date directly from its git repository using `wslutil upgrade`.
* **Extensible:** Add custom functionality by creating executable `wslutil-<name>` scripts in your PATH.
* **Windows Integration Helpers:** Complete suite of tools for seamless Windows interoperability.
* **Path Conversion:** Advanced WSL-to-Windows path conversion with drive substitution support.
* **Clipboard Integration:** Full bidirectional clipboard support with intelligent fallbacks.

## Installation

1. **Clone the repository:**

    ```bash
    git clone <repository-url> ~/.wslutil
    ```

    *(Replace `<repository-url>` with the actual URL of your git repository)*

2. **Add to PATH (Optional but Recommended):**
    Add the `bin` directory to your shell's PATH environment variable. Add this line to your `~/.bashrc`, `~/.zshrc`, or equivalent shell configuration file:

    ```bash
    export PATH="$HOME/.wslutil/bin:$PATH"
    ```

    Reload your shell configuration (`source ~/.bashrc`) or open a new terminal.

3. **Set up Shell Environment:**
    To ensure necessary environment variables (like `WIN_USERPROFILE`, `WIN_WINDIR`) are set, evaluate the output of `wslutil shellenv`. Add this to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.):

    ```bash
    # Load wslutil environment variables if wslutil is available
    if command -v wslutil >/dev/null 2>&1; then
      eval "$(wslutil shellenv)"
    fi
    ```

    Reload your shell configuration (`source ~/.bashrc`) or open a new terminal.

## Usage

The main command is `wslutil`. Use `--help` to see available subcommands and general options.

```bash
wslutil --help
```

To get help for a specific subcommand, use `--help` after the subcommand name:

```bash
wslutil <subcommand> --help
```

Example:

```bash
wslutil doctor --help
```

## Core Commands

### `wslutil` (main command)

Acts as the entry point and dispatcher for all other subcommands. Also handles discovering custom `wslutil-*` scripts in the PATH.

**Built-in Subcommands:**
- `doctor` - Run comprehensive health checks on the wslutil environment
- `shellenv` - Setup shell environment variables (eval the output)
- `upgrade` - Upgrade wslutil in place via git pull
- `register` - Register wslutil (placeholder for future functionality)

**Features:**
- **WSL Environment Validation:** Ensures commands only run within WSL
- **External Command Discovery:** Automatically discovers and executes `wslutil-*` scripts
- **Help System:** Dynamic help that includes discovered external commands

### `wslutil doctor`

Performs comprehensive health checks on your WSL environment specifically for `wslutil`. This command validates your system configuration and provides detailed diagnostics.

**Checks Performed:**
- **Required Commands:** Validates presence of essential tools (`crudini`, `wl-copy`, `wayland-info`, `dos2unix`, `iconv`, etc.)
- **Environment Variables:** Checks for proper WSL environment setup (`WIN_USERPROFILE`, `WIN_WINDIR`, etc.)
- **Configuration Files:** Validates existence and content of `/etc/wsl.conf` and `/usr/lib/binfmt.d/WSLInterop.conf`
- **System Integration:** Verifies WSL interop configuration and binfmt support

**Example:**
```bash
wslutil doctor
```

The output shows visual indicators (✓/✗) for each check with detailed status information.

### `wslutil shellenv`

Generates shell commands to export necessary environment variables used by `wslutil` and other WSL integration tools. Reads the appropriate `env/shellenv.<shell>` file based on your current shell (`$SHELL`).

**Environment Variables Set:**
- `WSLUTIL_DIR` - Installation directory path
- `WIN_USERPROFILE` - Windows user profile path (converted to WSL format)
- `WIN_WINDIR` - Windows directory path (converted to WSL format)
- `WSL_INTEROP` - WSL interop socket path
- Shell-specific Windows environment variable arrays

**Usage:**
```bash
eval "$(wslutil shellenv)"
```

### `wslutil upgrade`

Updates the `wsl-utils` installation by running `git pull` within the repository directory.

**Options:**
- `--fetch` - Fetch updates from remote repository but don't apply them

**Examples:**
```bash
wslutil upgrade          # Pull and apply updates
wslutil upgrade --fetch  # Fetch updates only
```

## Windows Integration Tools

### `win-run` - Advanced Windows Program Execution

The most feature-rich tool for executing Windows programs from WSL with automatic path conversion and extensive configuration options.

**Command-line Options:**
- `--raw` - Bypass UTF-8 output processing (useful for binary output)
- `--plain` - Skip automatic path conversion for arguments
- `-c FILE` - Use custom config file instead of default hierarchy
- `--help` - Show comprehensive help message

**Key Features:**
- **Automatic Path Conversion:** WSL paths automatically converted to Windows paths for file/directory arguments
- **Alias Support:** Define shortcuts for Windows programs via YAML configuration files
- **UTF-8 Output Processing:** Intelligent encoding detection and conversion (UTF-16LE to UTF-8)
- **Symlink Support:** Can be invoked via symlinks for command-specific behavior
- **Environment Variable Resolution:** Supports variable substitution in alias configurations

**Configuration System:**
- **Config Hierarchy:** `${WSLUTIL_DIR}/config/win-run.yml` → `~/.config/wslutil/win-run.yml`
- **Custom Configs:** Use `-c FILE` for project-specific configurations
- **YAML Format:**
  ```yaml
  aliases:
    command-name:
      path: ${WIN_PROGRAMFILES}/App/app.exe
      options: "--flag value"
  ```
- **Environment Variables:** Supports `${WIN_PROGRAMFILES}`, `${WIN_LOCALAPPDATA}`, etc.

**Examples:**
```bash
# Basic usage with automatic path conversion
win-run notepad.exe /home/user/file.txt

# Skip path conversion (plain mode)
win-run --plain notepad.exe C:\Users\user\file.txt

# Use custom config for project-specific aliases
win-run -c project-aliases.yml custom-tool.exe

# Raw output for binary data
win-run --raw some-binary.exe > output.bin
```

### `win-open` - Windows Explorer Integration

Opens files and directories using Windows Explorer or associated applications.

**Features:**
- **Automatic Path Conversion:** Files/directories converted using `wslpath -m`
- **Explorer Integration:** Uses Windows Explorer for directory opening
- **File URI Support:** Converts paths to proper `file:` URIs
- **Multi-argument Support:** Handle multiple files/directories in single command

**Examples:**
```bash
win-open document.docx           # Open with associated application
win-open /home/user/project/     # Open directory in Explorer
win-open file1.txt file2.txt     # Open multiple files
```

### `win-browser` - Default Browser Integration

Opens URLs and files in the default Windows web browser with dynamic browser detection.

**Features:**
- **Dynamic Browser Detection:** Runtime detection via Windows registry queries
- **Automatic Path Conversion:** Local files converted to `file:` URIs
- **Multi-argument Support:** Handle multiple URLs/files simultaneously
- **Registry Integration:** Uses `reg.exe` and `ftype` for browser detection

**Examples:**
```bash
win-browser https://example.com                    # Open URL
win-browser ./project/index.html                   # Open local HTML file
win-browser https://site1.com https://site2.com    # Open multiple URLs
```

### `win-copy` - Windows Clipboard Copy

Copies data from stdin to Windows clipboard with intelligent WSLg integration.

**Command-line Options:**
- `-h, --help` - Show help message
- **WSLg mode** (when available): All `wl-copy` options supported:
  - `-o, --trim-newline` - Trim final newline character
  - `-n, --foreground` - Stay in foreground (don't fork)
  - `-c, --clear` - Clear clipboard instead of copying
  - `-p, --primary` - Use primary selection
  - `-s, --seat SEAT` - Use specific seat

**Features:**
- **Intelligent Fallback:** Uses WSLg's `wl-copy` when available, falls back to `clip.exe`
- **Environment Detection:** Automatically detects WSL2_GUI_APPS_ENABLED status
- **Compatibility Layer:** Can be symlinked as `wl-copy` for tool compatibility

**Examples:**
```bash
echo "Hello Windows" | win-copy      # Copy text to clipboard
cat file.txt | win-copy              # Copy file contents
win-copy --clear                     # Clear clipboard (WSLg mode)
```

### `win-paste` - Windows Clipboard Paste

Retrieves data from Windows clipboard with automatic line ending normalization.

**Command-line Options:**
- `-h, --help` - Show help message
- **WSLg mode** (when available): All `wl-paste` options supported:
  - `-n, --no-newline` - Don't add newline at end (DEFAULT)
  - `-l, --list-types` - List available MIME types
  - `-t, --type TYPE` - Select specific MIME type
  - `-p, --primary` - Use primary selection
  - `-s, --seat SEAT` - Use specific seat

**Features:**
- **Intelligent Fallback:** Uses WSLg's `wl-paste` when available, falls back to PowerShell
- **Line Ending Normalization:** Automatically strips Windows carriage returns
- **UTF-8 Processing:** Ensures proper UTF-8 output from Windows clipboard

**Examples:**
```bash
win-paste > clipboard.txt            # Save clipboard to file
win-paste | grep "search"            # Search clipboard content
win-paste --list-types               # List available MIME types (WSLg mode)
```

## Utility Tools

### `wslpath-drive` - Enhanced Path Conversion

Wrapper around `wslpath` that adds support for Windows drive substitution via `subst.exe`.

**Options:**
- `-W` - Convert to Windows path with drive substitution (backward slashes)
- `-M` - Convert to Windows path with drive substitution (forward slashes)
- All standard `wslpath` options when used without `-W` or `-M`

**Features:**
- **Drive Substitution Support:** Automatically detects and uses `subst.exe` drive mappings
- **Intelligent Fallback:** Falls back to standard `wslpath` behavior
- **Nested Path Handling:** Correctly handles nested substitute drive paths
- **Case-insensitive Matching:** Robust path matching for drive substitution

**Examples:**
```bash
wslpath-drive -W /home/user/file.txt        # Convert with drive substitution
wslpath-drive -M /mnt/c/projects            # Convert with forward slashes
wslpath-drive -w /home/user/file.txt        # Standard wslpath behavior
```

### `sanitize` - Text Sanitization

Simple utility for removing non-ASCII characters from Windows command output.

**Features:**
- **UTF-16LE to UTF-8 Conversion:** Uses `iconv` for proper encoding conversion
- **Line Ending Normalization:** Applies `dos2unix` for consistent line endings
- **Pipeline Friendly:** Designed for use in command pipelines

**Usage:**
```bash
powershell.exe Get-Process | sanitize       # Clean PowerShell output
cmd.exe /c dir | sanitize                   # Clean CMD output
```

**Note:** Generally, you should use `win-run` instead, which automatically handles text sanitization.

## Configuration

### Environment Variables

The following environment variables are used by wsl-utils:

- `WSLUTIL_DIR` - Installation directory (auto-detected)
- `WIN_USERPROFILE` - Windows user profile path in WSL format
- `WIN_WINDIR` - Windows directory path in WSL format
- `WIN_PROGRAMFILES` - Program Files directory path
- `WIN_PROGRAMFILES_X86` - Program Files (x86) directory path
- `WIN_LOCALAPPDATA` - Local AppData directory path
- `WIN_APPDATA` - Roaming AppData directory path

### Configuration Files

**win-run Configuration:**
- Global: `${WSLUTIL_DIR}/config/win-run.yml`
- User: `~/.config/wslutil/win-run.yml`

**Shell Environment:**
- `env/shellenv.bash` - Bash environment setup
- `env/shellenv.zsh` - Zsh environment setup
- Other shells supported via `env/shellenv.<shell>` files

### Logging

All tools maintain detailed logs in `~/.local/state/wslutil/`:
- `win-run.log` - Windows command execution log
- `win-open.log` - File/directory opening log
- `win-browser.log` - Browser invocation log
- `win-clipboard.log` - Clipboard operation log

## Advanced Features

### WSLg Integration

Tools automatically detect and prefer WSLg when available:
- Clipboard tools use native `wl-copy`/`wl-paste` when possible
- Fallback to PowerShell/clip.exe for older systems
- Environment detection via `WSL2_GUI_APPS_ENABLED`

### Extensibility

Add custom functionality by creating `wslutil-<name>` scripts:
1. Create executable script named `wslutil-<name>`
2. Place in PATH or `${WSLUTIL_DIR}/bin/`
3. Access via `wslutil <name>`

### Error Handling

All tools include robust error handling:
- Graceful fallbacks for missing dependencies
- Comprehensive logging for troubleshooting
- Clear error messages with suggested fixes

## Troubleshooting

1. **Run diagnostics:** `wslutil doctor`
2. **Check logs:** `~/.local/state/wslutil/*.log`
3. **Verify environment:** `wslutil shellenv`
4. **Test individual tools:** Use `--help` for usage information

## Contributing

Contributions are welcome! Please refer to the project's contribution guidelines (if available) or open an issue/pull request on the repository.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.