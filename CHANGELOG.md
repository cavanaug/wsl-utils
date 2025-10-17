## [unreleased]

### 🚀 Features

- ✨ add WSL version and Windows config checks
- ✨ add win-uptime script
- ✨ add wslutil uptime subcommand
- ✨ add verbose and seconds options to tools
- ✨ add UTF-16LE to UTF-8 conversion

### 💼 Other

- ⚙️ refresh WSL configs and doctor script
- ⚙️ Remove experimental wslconfig support
- ⚙️ Add Xresources DPI & font settings
- ⚙️ update .gitignore and wslutil config

### 📚 Documentation

- 📚 add DETAILS.md and simplify README
- 📚 update changelog for unreleased changes

### 🎨 Styling

- 🎨 normalize whitespace and formatting in wslutil-setup
- 🎨 indent tip output in doctor script
- 🎨 add trailing newline to README.md
- 🎨 Refactor wslutil-uptime formatting

## [0.5.0] - 2025-08-27

### 🚀 Features

- *(setup)* ✨ add chrome.exe to WSL2 bin symlinks
- ✨ Add win-run and wslpath-drive utilities
- ✨ add win-run and wslpath-drive scripts
- ✨ enhance doctor script with package hints
- ✨ enhance doctor utility and README details
- ✨ Enhance WSL interop and Windows cmd output
- ✨ Use apt-file for doctor dependency checks
- ✨ add help messages and AI context file
- ✨ add alias support to win-run
- ✨ add --plain mode to win-run and overhaul docs
- ✨ add win-utf8 conversion script
- ✨ add CLI flags and colors to wslutil-doctor
- ✨ enable debug logging via WSLUTIL_DEBUG
- ✨ add wslutil-setup and config merging
- ✨ add symlink checks and fix suggestions
- ✨ enhance Windows exe discovery
- ✨ add install script and update docs

### 🐛 Bug Fixes

- 🐛 improve doctor checks and extend docs
- 🐛 enable upgrade outside WSL, refine env sync
- 🐛 loosen WSL check and improve env parsing
- 🐛 prefer local subcommands, keep exit status
- 🐛 send errors to stderr, validate WSL_INTEROP
- 🐛 relax WSL_INTEROP requirement in wslutil
- 🐛 Correct WSL_INTEROP socket check
- 🐛 Correct WSL_INTEROP validation
- 🐛 Improve handling of Windows command output encoding
- 🐛 Improve path and command execution in win-run
- 🐛 Improve Windows interop script reliability
- 🐛 ensure correct UTF-8 output from powershell
- 🐛 correct symlink target check

### 💼 Other

- Feat: check for WIN_USERPROFILE and WIN_WINDIR in wslutil-doctor
- Feat: Add check for update-binfmts command in wslutil-doctor
- Feat: Check for update-binfmts specifically in /usr/sbin
- Feat: Add check for /usr/lib/binfmt.d/WSLInterop.conf
- Refactor: Reorder checks in wslutil-doctor for command availability
- Chore: Add blank lines after environment and file checks
- Refactor: Remove status text from wslutil-doctor output lines
- Refactor: Skip file content checks if crudini is missing
- Docs: Create standard GitHub-style README for wslutil tools
- Feat: Add --raw option to bypass output processing
- ⚙️ enable notepad as default text editor
- ⚙️ restructure and update configuration files

### 🚜 Refactor

- *(env)* ♻️ centralize wsl environment initialization
- ♻️ improve command dispatch & env setup
- ♻️ cache WIN_ENV and add version compare
- ♻️ Add dev guidelines & disable WSL GUI

### 📚 Documentation

- Add a description to the README
- 📚 add changelog, roadmap and polish README
- 📚 add changelog, roadmap and README tweaks
- 📚 Remove AGENTS.md and expand CLAUDE.md docs
- 📚 add AGENTS.md symlink

### 🧪 Testing

- 🚨 add comprehensive test suite for win-run
- 🚨 Add wslutil-setup Bats tests

### ⚙️ Miscellaneous Tasks

- 🔧 remove sanitize script and drop iconv requirement
