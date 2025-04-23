# wsl-utils

A collection of command-line utilities designed to simplify and enhance the interoperability between Windows Subsystem for Linux (WSL) and the Windows host environment.

## Overview

`wsl-utils` provides a central command, `wslutil`, which acts as a dispatcher for various subcommands aimed at managing the WSL environment, checking its health, and facilitating seamless interaction with Windows tools and files.

## Features

*   **Environment Setup:** Easily configure necessary environment variables for WSL-Windows interop.
*   **Health Checks:** Diagnose potential issues in your WSL setup with `wslutil doctor`.
*   **In-Place Upgrades:** Keep `wsl-utils` up-to-date directly from the repository.
*   **Extensible:** Add custom functionality by creating `wslutil-*` scripts.
*   **Windows Integration:** Includes helpers for interacting with Windows clipboard and opening files/URLs in the Windows default browser (via `win-*` scripts, although their integration with `wslutil` might vary).

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository-url> ~/.wslutil
    ```
    *(Replace `<repository-url>` with the actual URL of your git repository)*

2.  **Add to PATH (Optional but Recommended):**
    Add the `bin` directory to your shell's PATH environment variable. Add this line to your `~/.bashrc`, `~/.zshrc`, or equivalent shell configuration file:
    ```bash
    export PATH="$HOME/.wslutil/bin:$PATH"
    ```
    Reload your shell configuration (`source ~/.bashrc`) or open a new terminal.

3.  **Set up Shell Environment:**
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

Performs a health check on your WSL environment specifically for `wsl-utils`. It verifies:
*   Presence of required command-line tools (e.g., `wl-copy`, `wl-paste`, `crudini`).
*   Correct WSL environment detection.
*   Availability of `wslutil` in the PATH.
*   Presence of essential environment variables (`WIN_USERPROFILE`, `WIN_WINDIR`).
*   Existence of required configuration files (`/etc/wsl.conf`, `/usr/lib/binfmt.d/WSLInterop.conf`).
*   Basic structure of `/etc/wsl.conf` (checks for `[boot]` and `[user]` sections if `crudini` is installed).

**Example:**
```bash
wslutil doctor
```
The output will show checks (`✓`) and crosses (`✗`) indicating the status of each item. If issues are found, it provides suggestions for fixing them, such as installing missing packages or setting up the shell environment.

### `wslutil shellenv`

Generates shell commands to export necessary environment variables used by `wsl-utils` and potentially other WSL integration tools. This typically includes `WSLUTIL_DIR`, `WIN_USERPROFILE`, and `WIN_WINDIR`.

**Usage:**
It's intended to be used with `eval` in your shell startup script (e.g., `~/.bashrc`):
```bash
eval "$(wslutil shellenv)"
```

### `wslutil upgrade`

Updates the `wsl-utils` installation by pulling the latest changes from its git repository.

**Usage:**
```bash
wslutil upgrade
```

**Options:**
*   `--fetch`: Fetches updates from the remote repository but does not apply them.

### `wslutil register` (Placeholder)

Currently, this subcommand prints a message indicating registration. Its full functionality might be defined in the future.

### Other Subcommands (from help output)

*   `shim`: Intended to create/update Windows command shims (implementation details may vary).
*   `setup`: Intended for setting up and configuring the system environment, potentially requiring `sudo` (implementation details may vary).

### Custom Subcommands

Any executable script named `wslutil-<name>` found in your PATH can be run as `wslutil <name>`.

## Contributing

Contributions are welcome! Please refer to the project's contribution guidelines (if available) or open an issue/pull request on the repository.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.


