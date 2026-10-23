# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.1.5] - 2026-10-23

### Added
- **macOS app window** (`Discord Multi.app`, in the new `-mac.zip` download): profile list with running status, Launch, Stop, Launch All, Start at login, Desktop Shortcut, Rename, Delete. `./discord-multi.sh` opens the same window on macOS (`tui` for the old menu)
- `stop <name>` and `status` commands (Linux, macOS)

## [1.1.4] - 2026-10-23

### Added
- **Automatic updates:** on start the installed app checks GitHub for a new release, installs it silently and opens again. Portable copies show a download link instead (Windows)

## [1.1.3] - 2026-10-23

### Added
- **Stop** button and a running / not running status for each profile (green dot in the list) (Windows)

### Fixed
- A profile still got no tray icon (next to the clock) while another Discord was open. Discord registers its icon with one fixed ID, and Windows allows only one icon per ID; each profile now gets its own tray icon (Windows)

## [1.1.2] - 2026-10-23

### Fixed
- Windows 11: a profile's tray icon (next to the clock) could be missing while your main Discord was open. Windows hides the new tray entry a profile gets by default; Discord Multi now keeps Discord's tray icons shown

## [1.1.1] - 2026-10-20

### Fixed
- Vencord looked missing in profiles: each profile got its own empty Vencord settings, so every plugin was off. All profiles now share your main Vencord settings, plugins and themes (Windows, Linux, macOS)

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
