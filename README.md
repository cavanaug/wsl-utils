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

### Automated Installation (Recommended)

Use the provided installation script for automatic setup:

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh | sh

# Or clone first, then run installer
git clone https://github.com/cavanaug/wsl-utils.git $HOME/.wslutil
$HOME/.wslutil/install.sh
```

**Installation Options:**

```bash
# Full installation with custom directory
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh)" -- --install-dir ~/my-wslutil

# Skip PATH setup (useful for system-wide installations)
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh)" -- --no-path

# Preview what will be done (dry run)
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh)" -- --dry-run

# Use custom repository fork
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/cavanaug/wsl-utils/main/install.sh)" -- https://github.com/user/fork.git

# Local installation after cloning
git clone https://github.com/cavanaug/wsl-utils.git && cd wsl-utils && ./install.sh --no-path
```

The installer automatically:

* Clones the repository to `~/.wslutil` (or custom directory)
* Adds `bin` directory to your PATH in `~/.bashrc`
* Configures shell environment integration
* Currently supports bash only (uses default repository: <https://github.com/cavanaug/wsl-utils.git>)

### Manual Installation

If you prefer manual installation:

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

### Script Categories

This project provides two distinct categories of scripts with different purposes:

- **`wslutil` scripts**: Commands for setup and configuration of the wslutil environment itself. These are typically run interactively during initial setup or maintenance (e.g., `wslutil doctor`, `wslutil setup`, `wslutil shellenv`).

- **`win-*` scripts**: General-purpose utilities for daily Windows integration tasks. These are designed for command-line usage, scripting, and automation (e.g., `win-run`, `win-open`, `win-browser`, `win-copy`).

### `wslutil` (main command)

Acts as the entry point and dispatcher for all other subcommands. Also handles discovering custom `wslutil-*` scripts in the PATH.

**Built-in Subcommands:**

* `doctor` - Run comprehensive health checks on the wslutil environment
* `shellenv` - Setup shell environment variables (eval the output)
* `setup` - Configure and merge wslutil settings, create Windows executable symlinks
* `upgrade` - Upgrade wslutil in place via git pull

**Features:**

* **WSL Environment Validation:** Ensures commands only run within WSL
* **External Command Discovery:** Automatically discovers and executes `wslutil-*` scripts
* **Help System:** Dynamic help that includes discovered external commands

### `wslutil doctor`

Performs comprehensive health checks on your WSL environment specifically for `wslutil`. This command validates your system configuration and provides detailed diagnostics.

**Checks Performed:**

* **Required Commands:** Validates presence of essential tools (`crudini`, `wl-copy`, `wayland-info`, `dos2unix`, `iconv`, etc.)
* **Environment Variables:** Checks for proper WSL environment setup (`WIN_USERPROFILE`, `WIN_WINDIR`, etc.)
* **Configuration Files:** Validates existence and content of `/etc/wsl.conf` and `/usr/lib/binfmt.d/WSLInterop.conf`
* **System Integration:** Verifies WSL interop configuration and binfmt support

**Example:**

```bash
wslutil doctor
```

The output shows visual indicators (✓/✗) for each check with detailed status information.

### `wslutil shellenv`

Generates shell commands to export necessary environment variables used by `wslutil` and other WSL integration tools. Reads the appropriate `env/shellenv.<shell>` file based on your current shell (`$SHELL`).

**Environment Variables Set:**

* `WSLUTIL_DIR` - Installation directory path
* `WIN_USERPROFILE` - Windows user profile path (converted to WSL format)
* `WIN_WINDIR` - Windows directory path (converted to WSL format)
* `WSL_INTEROP` - WSL interop socket path
* Shell-specific Windows environment variable arrays

**Usage:**

```bash
eval "$(wslutil shellenv)"
```

### `wslutil setup`

Configures and merges wslutil settings into system configuration files, and creates Windows executable symlinks based on YAML configuration.

**Configuration Management:**

* **wslutil.yml**: Creates symlinks for Windows executables in bin directory
* **wsl.conf**: Merges settings into `/etc/wsl.conf`
* **wslconfig**: Merges settings into `${WIN_USERPROFILE}/.wslconfig`
* **wslgconfig**: Merges settings into `${WIN_USERPROFILE}/.wslgconfig`

**Options:**

* `--dry-run` - Show what would be done without making changes
* `-c, --config FILE` - Use custom config file instead of default wslutil.yml
* `--help` - Show help message and exit

**Features:**

* **Two-Phase Processing**: Processes system configuration first, then user configuration
* **Windows Executable Cache**: Builds cache of Windows PATH executables with PowerShell fallback
* **YAML Processing**: Handles `winrun` entries (symlinks to win-run) and `winexe` entries (direct symlinks)
* **Variable Expansion**: Supports environment variables like `${WIN_PROGRAMFILES}` in paths
* **INI File Merging**: Uses `crudini` for safe configuration file merging

**Examples:**

```bash
wslutil setup                              # Perform configuration setup
wslutil setup --dry-run                    # Preview changes without applying
wslutil setup -c ./project-config.yml     # Use custom config file
wslutil setup --config /path/to/custom.yml # Use custom config file
```

**Dependencies:**

* `crudini` - Required for INI file merging
* `yq` - Required for YAML processing

### `wslutil upgrade`

Updates the `wsl-utils` installation by running `git pull` within the repository directory.

**Options:**

* `--fetch` - Fetch updates from remote repository but don't apply them

**Examples:**

```bash
wslutil upgrade          # Pull and apply updates
wslutil upgrade --fetch  # Fetch updates only
```

## Windows Integration Tools

### `win-run` - Advanced Windows Program Execution

The most feature-rich tool for executing Windows programs from WSL with automatic path conversion and extensive configuration options.

**Command-line Options:**

* `--raw` - Bypass UTF-8 output processing (useful for binary output)
* `--plain` - Skip automatic path conversion for arguments
* `-c FILE` - Use custom config file instead of default hierarchy
* `--help` - Show comprehensive help message

**Key Features:**

* **Automatic Path Conversion:** WSL paths automatically converted to Windows paths for file/directory arguments
* **Alias Support:** Define shortcuts for Windows programs via YAML configuration files
* **UTF-8 Output Processing:** Intelligent encoding detection and conversion (UTF-16LE to UTF-8)
* **Symlink Support:** Can be invoked via symlinks for command-specific behavior
* **Environment Variable Resolution:** Supports variable substitution in alias configurations

**Configuration System:**

* **Config Hierarchy:** `${WSLUTIL_DIR}/config/win-run.yml` → `~/.config/wslutil/win-run.yml`
* **Custom Configs:** Use `-c FILE` for project-specific configurations
* **YAML Format:**

  ```yaml
  aliases:
    command-name:
      path: ${WIN_PROGRAMFILES}/App/app.exe
      options: "--flag value"
  ```

* **Environment Variables:** Supports `${WIN_PROGRAMFILES}`, `${WIN_LOCALAPPDATA}`, etc.

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

* **Automatic Path Conversion:** Files/directories converted using `wslpath -m`
* **Explorer Integration:** Uses Windows Explorer for directory opening
* **File URI Support:** Converts paths to proper `file:` URIs
* **Multi-argument Support:** Handle multiple files/directories in single command

**Examples:**

```bash
win-open document.docx           # Open with associated application
win-open /home/user/project/     # Open directory in Explorer
win-open file1.txt file2.txt     # Open multiple files
```

### `win-browser` - Default Browser Integration

Opens URLs and files in the default Windows web browser with dynamic browser detection.

**Features:**

* **Dynamic Browser Detection:** Runtime detection via Windows registry queries
* **Automatic Path Conversion:** Local files converted to `file:` URIs
* **Multi-argument Support:** Handle multiple URLs/files simultaneously
* **Registry Integration:** Uses `reg.exe` and `ftype` for browser detection

**Examples:**

```bash
win-browser https://example.com                    # Open URL
win-browser ./project/index.html                   # Open local HTML file
win-browser https://site1.com https://site2.com    # Open multiple URLs
```

### `win-copy` - Windows Clipboard Copy

Copies data from stdin to Windows clipboard with intelligent WSLg integration.

**Command-line Options:**

* `-h, --help` - Show help message
* **WSLg mode** (when available): All `wl-copy` options supported:
  * `-o, --trim-newline` - Trim final newline character
  * `-n, --foreground` - Stay in foreground (don't fork)
  * `-c, --clear` - Clear clipboard instead of copying
  * `-p, --primary` - Use primary selection
  * `-s, --seat SEAT` - Use specific seat

**Features:**

* **Intelligent Fallback:** Uses WSLg's `wl-copy` when available, falls back to `clip.exe`
* **Environment Detection:** Automatically detects WSL2_GUI_APPS_ENABLED status
* **Compatibility Layer:** Can be symlinked as `wl-copy` for tool compatibility

**Examples:**

```bash
echo "Hello Windows" | win-copy      # Copy text to clipboard
cat file.txt | win-copy              # Copy file contents
win-copy --clear                     # Clear clipboard (WSLg mode)
```

### `win-paste` - Windows Clipboard Paste

Retrieves data from Windows clipboard with automatic line ending normalization.

**Command-line Options:**

* `-h, --help` - Show help message
* **WSLg mode** (when available): All `wl-paste` options supported:
  * `-n, --no-newline` - Don't add newline at end (DEFAULT)
  * `-t, --type TYPE` - Select specific MIME type (DEFAULT text)
  * `-l, --list-types` - List available MIME types
  * `-p, --primary` - Use primary selection
  * `-s, --seat SEAT` - Use specific seat

**Features:**

* **Intelligent Fallback:** Uses WSLg's `wl-paste` when available, falls back to PowerShell
* **Line Ending Normalization:** Automatically strips Windows carriage returns
* **UTF-8 Processing:** Ensures proper UTF-8 output from Windows clipboard

**Examples:**

```bash
win-paste > clipboard.txt            # Save clipboard to file
win-paste | grep "search"            # Search clipboard content
win-paste --list-types               # List available MIME types (WSLg mode)
```

### `win-utf8` - Windows Output Encoding Converter

Low-level utility that converts Windows command output to UTF-8 with Unix line endings. Handles both UTF-16LE with BOM and BOM-less UTF-16LE output from PowerShell and cmd.exe.

**Note:** Generally you should use `win-run` instead, which automatically handles encoding conversion for you. This script is provided for advanced use cases or when you need direct control over the conversion process.

**Features:**

* **Automatic Encoding Detection:** Detects UTF-16LE (with or without BOM) vs UTF-8
* **Python-based Conversion:** Uses embedded Python script for reliable UTF-16LE to UTF-8 conversion
* **Line Ending Normalization:** Converts Windows line endings to Unix format using `dos2unix`
* **Pipeline Friendly:** Designed for use in command pipelines
* **Error Handling:** Graceful fallback for malformed input streams

**Usage:**

```bash
# Convert Windows command output (advanced usage)
powershell.exe -Command "Get-Process" | win-utf8
cmd.exe /c dir | win-utf8                   # Clean CMD output

# Better: Use win-run instead for automatic handling  
win-run powershell.exe -Command "Get-Process"
win-run cmd.exe /c dir
```

## Utility Tools

### `wslpath-drive` - Enhanced Path Conversion

Wrapper around `wslpath` that adds support for Windows drive substitution via `subst.exe` or network drives that are mapped.

**Options:**

* `-W` - Convert to Windows path with drive substitution (backward slashes)
* `-M` - Convert to Windows path with drive substitution (forward slashes)
* All standard `wslpath` options when used without `-W` or `-M`

**Features:**

* **Drive Substitution Support:** Automatically detects and learns `subst.exe` drive mappings
* **Intelligent Fallback:** Falls back to standard `wslpath` behavior
* **Nested Path Handling:** Correctly handles nested substitute drive paths
* **Case-insensitive Matching:** Robust path matching for drive substitution

**Examples:**

```bash
wslpath-drive -W /home/user/file.txt        # Convert with drive substitution
wslpath-drive -M /mnt/c/projects            # Convert with forward slashes
wslpath-drive -w /home/user/file.txt        # Standard wslpath behavior
```

## Configuration

### Environment Variables

**Core System Variables:**

* `WSLUTIL_DIR` - Installation directory (auto-detected from script location)
* `WSL_INTEROP` - WSL interop socket path (default: `/run/WSL/1_interop`)

**Windows Environment Variables:**

All Windows environment variables are automatically imported and converted to WSL format via `wslutil shellenv`:

* `WIN_USERPROFILE` - Windows user profile path (e.g., `/mnt/c/Users/username`)
* `WIN_WINDIR` - Windows directory path (default: `/mnt/c/Windows`)
* `WIN_PROGRAMFILES` - Program Files directory (e.g., `/mnt/c/Program Files`)
* `WIN_PROGRAMFILES_X86` - Program Files (x86) directory
* `WIN_LOCALAPPDATA` - Local AppData directory (e.g., `/mnt/c/Users/username/AppData/Local`)
* `WIN_APPDATA` - Roaming AppData directory (e.g., `/mnt/c/Users/username/AppData/Roaming`)
* `WIN_COMPUTERNAME` - Windows computer name
* `WIN_USERNAME` - Windows username
* `WIN_USERDOMAIN` - Windows user domain
* `WIN_HOMEPATH` - Combined HOMEDRIVE + HOMEPATH from Windows
* `WIN_ENV[]` - Associative array containing all Windows environment variables
  
  **⚠️ WARNING**: `WIN_ENV` is a Bash associative array and has important limitations:
  * **Not passed to subshells or scripts** - Child processes cannot access WIN_ENV
  * **Only available in the current shell session** after running `eval "$(wslutil shellenv)"`
  * **Use individual WIN_* variables instead** for scripts and subprocesses
  * **Access in current shell**: `echo "${WIN_ENV[COMPUTERNAME]}"` ✓
  * **Won't work in scripts**: Scripts cannot access WIN_ENV unless they source shellenv ✗

**Configuration Variables:**

* `XDG_CONFIG_HOME` - Config directory override (default: `~/.config`) - used for win-run config hierarchy
* `WSLUTIL_DEBUG` - When set to any non-empty value, enables detailed logging to `~/.local/state/wslutil/*.log`

**Build Variables (for development):**

* `BATS_TMPDIR` - Temporary directory for BATS tests (default: `/tmp`)
* `TMPDIR` - System temporary directory override

### Configuration Files

**Configuration Hierarchy:**

The system uses a two-phase configuration approach: system configuration first, then user configuration. User configurations override system defaults.

**User Configuration Directory:** `~/.config/wslutil/`

**Supported User Configuration Files:**

* **`wslutil.yml`**: User-specific Windows executable symlinks (winrun/winexe entries)
* **`win-run.yml`**: User-specific win-run aliases and configurations
* **`wsl.conf`**: User WSL settings merged into `/etc/wsl.conf` (requires sudo)
* **`wslconfig`**: User WSL2 settings merged into `${WIN_USERPROFILE}/.wslconfig`
* **`wslgconfig`**: User WSLg settings merged into `${WIN_USERPROFILE}/.wslgconfig`

**System Configuration Files:**

* **Global win-run**: `${WSLUTIL_DIR}/config/win-run.yml`
* **System configs**: `${WSLUTIL_DIR}/config/` (wslutil.yml, wsl.conf, wslconfig, wslgconfig)

**Shell Environment:**

* `env/shellenv.bash` - Bash environment setup
* `env/shellenv.zsh` - Zsh environment setup
* Other shells supported via `env/shellenv.<shell>` files

**Creating User Configurations:**

The default user configuration directory is `~/.config/wslutil/`. Files placed here will be processed during Phase 2 of `wslutil setup` and will override system defaults.

```bash
# Create user config directory
mkdir -p ~/.config/wslutil

# Example user wslutil.yml for custom Windows executable symlinks
cat > ~/.config/wslutil/wslutil.yml << 'EOF'
winexe:
  - myapp.exe                    # Direct symlink to Windows executable
winrun:
  - custom-tool.exe              # Symlink via win-run for path conversion
EOF

# Example user win-run.yml for custom aliases
cat > ~/.config/wslutil/win-run.yml << 'EOF'
aliases:
  myeditor:
    path: ${WIN_PROGRAMFILES}/MyEditor/editor.exe
    options: "--new-window"
EOF

# Apply user configurations (processes both system and user configs)
wslutil setup

# Or use a custom config file for project-specific setups
wslutil setup -c ./my-project/project-config.yml
```

**Custom Configuration Files:**

You can create project-specific or temporary configuration files and use them with the `-c` option:

```bash
# Create a project-specific config file
cat > ./dev-tools.yml << 'EOF'
winexe:
  - devenv.exe                   # Visual Studio
  - "${WIN_PROGRAMFILES}/Git/bin/git.exe"
winrun:
  - msbuild.exe                  # MSBuild with path conversion
  - dotnet.exe                   # .NET CLI with path conversion
EOF

# Apply only this custom config (still processes system config first)
wslutil setup -c ./dev-tools.yml
```

### Logging

Logging is disabled by default but can be enabled by setting the `WSLUTIL_DEBUG` environment variable. When enabled, tools maintain detailed logs in `~/.local/state/wslutil/`:

* `win-run.log` - Windows command execution log
* `win-open.log` - File/directory opening log
* `win-browser.log` - Browser invocation log
* `win-clipboard.log` - Clipboard operation log

**Enable logging:**

```bash
# Enable logging for current session
export WSLUTIL_DEBUG=1

# Enable logging permanently (add to ~/.bashrc or ~/.zshrc)
echo 'export WSLUTIL_DEBUG=1' >> ~/.bashrc

# View logs
tail -f ~/.local/state/wslutil/win-run.log
```

## Advanced Features

### WSLg Integration

Tools automatically detect and prefer WSLg when available:

* Clipboard tools use native `wl-copy`/`wl-paste` when possible
* Fallback to PowerShell/clip.exe for older systems
* Environment detection via `WSL2_GUI_APPS_ENABLED`

### Extensibility

Add custom functionality by creating `wslutil-<name>` scripts:

1. Create executable script named `wslutil-<name>`
2. Place in PATH or `${WSLUTIL_DIR}/bin/`
3. Access via `wslutil <name>`

### Error Handling

All tools include robust error handling:

* Graceful fallbacks for missing dependencies
* Comprehensive logging for troubleshooting
* Clear error messages with suggested fixes

## Troubleshooting

1. **Run diagnostics:** `wslutil doctor`
2. **Check logs:** `~/.local/state/wslutil/*.log` (requires `WSLUTIL_DEBUG=1`)
3. **Verify environment:** `wslutil shellenv`
4. **Test individual tools:** Use `--help` for usage information
5. **Run tests:** `./tests/run_tests.sh` (requires BATS and yq)

## Testing

The project includes a comprehensive test suite using BATS (Bash Automated Testing System).

### Prerequisites

* **BATS**: `sudo apt install bats` or `brew install bats-core`
* **yq**: `sudo apt install yq` or `brew install yq`

### Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run specific test file
./tests/run_tests.sh test_option_parsing.bats

# Run with verbose output
./tests/run_tests.sh -v
```

### Test Coverage

The test suite covers:

* Command-line option parsing and help functionality
* Config file validation, loading, and hierarchy precedence
* Alias resolution and environment variable expansion
* Path conversion logic and error handling
* Integration testing and logging functionality
* Setup command symlink creation and YAML processing

## Contributing

Contributions are welcome! Please refer to the project's contribution guidelines (if available) or open an issue/pull request on the repository.

When contributing:

1. Run tests to ensure functionality: `./tests/run_tests.sh`
2. Add tests for new features or bug fixes
3. Update documentation as needed

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
