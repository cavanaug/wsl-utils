# wsl-utils

A collection of command-line utilities designed to simplify and enhance the interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment.

## Overview

`wsl-utils` provides a central command, `wslutil`, which acts as a dispatcher for various subcommands aimed at managing the WSL environment, checking its health, and facilitating seamless interaction with Windows tools and files.

## Features

* **Environment Setup:** Easily configure necessary environment variables for WSL-Windows interop.
* **Environment Setup:** Easily configure necessary environment variables (`WIN_USERPROFILE`, `WIN_WINDIR`) for WSL-Windows interop using `wslutil shellenv`.
* **Health Checks:** Diagnose potential issues in your WSL setup (required commands, environment variables, config files) with `wslutil doctor`.
* **In-Place Upgrades:** Keep `wsl-utils` up-to-date directly from its git repository using `wslutil upgrade`.
* **Extensible:** Add custom functionality by creating executable `wslutil-<name>` scripts in your PATH.
* **Windows Integration Helpers:**
  * `win-browser`: Open files, directories, or URLs in the default Windows browser.
  * `win-copy`: Copy standard input to the Windows clipboard (primarily a fallback for non-WSLg environments).
  * `win-open`: Open files or directories using the default Windows application (like double-clicking).
  * `win-paste`: Paste from the Windows clipboard to standard output, correctly handling line endings.
  * `win-run`: Execute Windows commands from WSL, automatically converting file/directory path arguments.

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

## Subcommands

### `wslutil` (main command)

Acts as the entry point and dispatcher for all other subcommands. Also handles discovering custom `wslutil-*` scripts in the PATH.

### `wslutil doctor`

Performs a sanity check on your WSL environment specifically for `wslutil`. Run this command if you suspect something isn't working correctly with `wslutil` or its helper scripts. It checks for common configuration issues, missing dependencies, and incorrect environment variable settings, providing suggestions for fixes if problems are detected.

**Example:**

```bash
wslutil doctor
```

The output will show checks (`✓`) and crosses (`✗`) indicating the status of each item. If issues are found, it provides suggestions for fixing them, such as installing missing packages or setting up the shell environment.

### `wslutil shellenv`

Generates shell commands to export necessary environment variables used by `wslutil` and potentially other WSL integration tools. It reads the appropriate `env/shellenv.<shell>` file based on your current shell (`$SHELL`). This typically includes exporting `WSLUTIL_DIR`, `WIN_USERPROFILE`, and `WIN_WINDIR`.

**Usage:**
It's intended to be used with `eval` in your shell startup script (e.g., `~/.bashrc`):

```bash
eval "$(wslutil shellenv)"
```

### `wslutil upgrade`

Updates the `wsl-utils` installation by running `git pull` within the repository directory (`$WSLUTIL_DIR`).

**Usage:**

```bash
wslutil upgrade
```

**Options:**

* `--fetch`: Fetches updates from the remote repository but does not apply them.

### `wslutil register`

Currently, this subcommand prints a message indicating registration and accepts a `--name` argument, but does not perform any other actions. Its full functionality might be defined in the future.

### Other Subcommands (Placeholders)

The `wslutil --help` output may list other potential subcommands like `shim` and `setup`. These are currently placeholders discovered by the help system and do not have corresponding `wslutil-*` scripts in the base installation.

### Custom Subcommands

Any executable script named `wslutil-<name>` found in your PATH can be run as `wslutil <name>`.

## Helper Scripts (`win-*`)

These scripts are located in the `bin/` directory and provide direct integration with Windows features. They are often used standalone or can be symlinked for compatibility with other tools (e.g., symlinking `wl-paste` to `win-paste`).

### `win-browser [url|file|directory]`

Opens the given arguments (URLs, file paths, directory paths) in the default Windows web browser. File and directory paths are automatically converted to the appropriate Windows format (`file:...`).

**Example:**

```bash
win-browser https://www.google.com
win-browser ./my-project/index.html
```

### `win-copy`

Reads from standard input and copies it to the Windows clipboard.
This script primarily serves as a fallback for systems without WSLg (where `/usr/bin/wl-copy` is preferred). It uses `clip.exe` if `wl-copy` is unavailable or WSLg is not enabled.

**Example:**

```bash
echo "Hello Windows Clipboard" | win-copy
cat somefile.txt | win-copy
```

### `win-open [file|directory]`

Opens the specified file(s) or director(y/ies) using the default Windows application associated with the file type, or Windows Explorer for directories. Paths are converted to Windows format.

**Example:**

```bash
win-open document.docx
win-open /mnt/c/Users/Me/Pictures
win-open ./project/
```

### `win-paste`

Prints the contents of the Windows clipboard to standard output.
This script is useful even with WSLg, as it automatically strips carriage return (`\r`) characters often added when copying text from Windows applications, ensuring clean pasting into Unix environments. It uses `/usr/bin/wl-paste | dos2unix` if available, otherwise falls back to PowerShell's `Get-Clipboard`.

**Example:**

```bash
# Paste clipboard content into a file
win-paste > clipboard_content.txt

# Use in a pipe
win-paste | grep "error"
```

### `win-run <command> [args...]`

Executes a Windows command or executable using PowerShell. Any arguments that are existing file or directory paths within WSL are automatically converted to their Windows equivalents using `wslpath -w`. If the output is piped (`|`), `dos2unix` is used to ensure Unix line endings.

**Example:**

```bash
# Run notepad with a WSL path (converted automatically)
win-run notepad.exe ~/notes.txt

# Run a command and process its output
win-run ipconfig.exe | grep "IPv4"
```

## Roadmap/ChangeLog

See Roadmap.md for a list of planned features and improvements.
See ChangeLog.md for a list of changes across releases

## Contributing

Contributions are welcome! Please refer to the project's contribution guidelines (if available) or open an issue/pull request on the repository.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
