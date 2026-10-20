# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.0] - 2026-10-20

### Added
- Linux and macOS support (`discord-multi.sh`) with zenity / AppleScript dialogs or a terminal menu, plus a full command-line interface
- **Start with Windows** / start at login per profile (opens minimized)
- **Add to Start Menu** button (Windows) and `menu on|off` command (Linux / macOS)
- **Rename** a profile (also moves its start-at-login and desktop shortcuts)
- **About** dialog with version, GitHub and PayPal donation links
- Windows installer (`DiscordMulti-Setup-<version>.exe`): per-user, no admin, optional Start menu and Desktop shortcuts, uninstaller that can keep your profiles
- Project logo (`assets/`)

### Fixed
- Profiles asking to log in again: opening a profile that was already running (e.g. hidden in the tray) started a second copy that couldn't read the saved login. Profiles now use Discord's own single-instance check, so the running window is brought back instead

### Changed
- Profiles are stored in one shared folder so the installed app, the portable copy and the repo all see the same profiles; `portable.txt` keeps them next to the script. Older profiles are moved automatically once their Discord is closed

## [1.0.0] - 2026-10-20

### Added
- GUI to create, launch, and delete Discord profiles
- Launch All button
- Per-profile desktop shortcuts that launch directly without the GUI
- Support for Discord Stable, PTB, and Canary

### Fixed
- New instances hanging on "Starting...": profiles now use `DISCORD_USER_DATA_DIR` (Electron ignores `%APPDATA%`) and skip the shared updater

### Changed
- Profiles are stored in a portable `profiles` folder next to the script
