# Changelog

All notable changes to this project will be documented in this file.

## [unreleased]

### 🚀 Features

- *(setup)* ✨ add chrome.exe to WSL2 bin symlinks
- ✨ Add win-run and wslpath-drive utilities
- ✨ add win-run and wslpath-drive scripts
- ✨ enhance doctor script with package hints
- ✨ enhance doctor utility and README details

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

### 🚜 Refactor

- *(env)* ♻️ centralize wsl environment initialization

### 📚 Documentation

- Add a description to the README

