<p align="center">
  <img src="assets/logo.png" width="120" alt="Multi Discord logo">
</p>

<h1 align="center">Multi Discord</h1>

<p align="center">
  Run <b>multiple Discord accounts at the same time</b> on one computer — Windows, Linux and macOS.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Windows-0078D6?logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black" alt="Linux">
  <img src="https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
  <a href="https://paypal.me/mfsafadi"><img src="https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white" alt="Donate with PayPal"></a>
</p>

No installation, no patching of Discord, no third-party binaries — just a small script that launches your installed Discord with a separate data folder per account.

## Features

- Create as many **profiles** as you want — each profile is a separate Discord account
- Launch one profile, or **Launch All** at once
- **Rename** a profile without losing its login or shortcuts
- **Start at login** per profile (opens minimized to the tray)
- **Desktop shortcut** / app-menu entry per profile
- **Add the tool to the Start menu** (Windows) or app menu (Linux / macOS)
- Your normal Discord keeps working untouched and can run alongside the profiles
- Logins are remembered per profile
- Works with Discord Stable, PTB, or Canary (whichever is installed)
- Every copy (installed, portable or cloned repo) shares the same profiles — or keep them next to the script with portable mode

## Windows

**Requirements:** Windows 10 / 11, the Discord desktop app, Windows PowerShell 5.1 (built in).

### Install

Download **`DiscordMulti-Setup-<version>.exe`** from the [latest release](https://github.com/mphpmaster/multi-discord/releases/latest) and run it.

- Installs for your user only — **no admin rights needed**
- Choose whether to add a **Start menu** shortcut (on by default) and a **Desktop** shortcut
- Uninstall any time from **Settings → Apps**; you'll be asked whether to keep your profiles (logins)

Prefer no installer? Download the **portable** zip, extract it anywhere and double-click **`Start-DiscordMulti.bat`**.

### Use

1. Open **Discord Multi** from the Start menu (or the portable `.bat`).
2. Type a profile name (e.g. `Work`) and click **Add Account**.
3. Select it and click **Launch** (or double-click it). A new Discord window opens — log in with your other account.

Optional:
- Tick **Start with Windows** to open that profile automatically when you sign in.
- Click **Desktop Shortcut** to open that account later with one click.
- Click **Add to Start Menu** so you can find Discord Multi from the Start menu.
- Click **About** for the version, links and donation info.

## Linux & macOS

**Requirements:** bash and the Discord desktop app. On Linux, [zenity](https://help.gnome.org/users/zenity/) is used for dialogs when available; otherwise a terminal menu is shown. Native packages (deb / rpm / tar.gz / AUR) and Flatpak are detected automatically.

```bash
chmod +x discord-multi.sh
./discord-multi.sh            # interactive menu
```

Or use commands directly:

```bash
./discord-multi.sh add Work
./discord-multi.sh launch Work
./discord-multi.sh startup Work on      # start at login
./discord-multi.sh shortcut Work        # app-menu entry (Linux) / Desktop launcher (macOS)
./discord-multi.sh menu on              # add Discord Multi itself to your app menu
./discord-multi.sh rename Work Job       # keeps the login and shortcuts
./discord-multi.sh list                 # * = starts at login
./discord-multi.sh help                 # all commands
```

If Discord is installed somewhere unusual, point the script at it:

```bash
DISCORD_BIN="/path/to/Discord" ./discord-multi.sh launch Work
```

| | Start at login | App menu |
| --- | --- | --- |
| Linux | `~/.config/autostart/` | `~/.local/share/applications/` |
| macOS | `~/Library/LaunchAgents/` | `~/Applications/` |

## How it works

Discord stores its login session in its data folder (`%APPDATA%\discord`, `~/.config/discord`, or `~/Library/Application Support/discord`). For each profile, the tool:

1. Creates a private data folder for it in the shared profiles folder:

   | OS | Profiles folder |
   | --- | --- |
   | Windows | `%LOCALAPPDATA%\Discord Multi\profiles` |
   | Linux | `~/.local/share/discord-multi/profiles` |
   | macOS | `~/Library/Application Support/Discord Multi/profiles` |

   **Portable mode:** put an empty file named `portable.txt` next to the script to keep profiles in a `profiles` folder beside it instead (e.g. on a USB stick). Profiles made by older versions next to the script are moved to the shared folder automatically once their Discord is closed.
2. Launches the installed Discord with the `DISCORD_USER_DATA_DIR` environment variable pointed at that folder. Because every profile has its own folder, Discord's single-instance check works per profile: different profiles run side by side, and opening a profile that is already running (e.g. in the tray) just brings its window back — so its login is never lost to a duplicate copy. (Setting `APPDATA` alone does not work on Windows: Electron resolves the AppData folder through the Windows API, not the environment variable.)
3. Sets `SKIP_HOST_UPDATE` and `SKIP_MODULE_UPDATE` in the profile's `settings.json`, because the updater is shared with your main Discord and would otherwise hang on **"Starting..."**. Updates still arrive through your main Discord install, which the profiles reuse.
4. Points `VENCORD_USER_DATA_DIR` at your main [Vencord](https://vencord.dev) folder (`%APPDATA%\Vencord`, `~/.config/Vencord`, or `~/Library/Application Support/Vencord`), so every profile shares the same Vencord plugins, settings and themes. Set `VENCORD_USER_DATA_DIR` yourself to use a different folder.

Deleting a profile removes only its folder (and its start-at-login entry).

> **Note:** the profiles folder contains your Discord login sessions. Never share it or commit it — a local `profiles/` folder is already listed in `.gitignore`.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Stuck on "Starting..." | Close the window (or end the extra Discord process) and launch again. Please open an issue if it keeps happening. |
| "Discord is not installed" | Install the desktop app from [discord.com/download](https://discord.com/download), or set `DISCORD_BIN` (Linux / macOS). |
| Script blocked by Windows | Use the `.bat` launcher — it runs the script with `-ExecutionPolicy Bypass` for that process only. |
| Can't rename or delete a profile | Close that profile's Discord window first. |
| No dialogs on Linux | Install `zenity`, or use the terminal menu / commands. |

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## Support the project

If this tool saves you time, you can support its development:

- ⭐ Star the repo
- 💸 Donate via PayPal: [paypal.me/mfsafadi](https://paypal.me/mfsafadi)

## Author

Mohammad Al-Safadi — [@mphpmaster](https://github.com/mphpmaster)

## Disclaimer

This project is not affiliated with, endorsed by, or connected to Discord Inc. It does not modify the Discord client; it only launches it with separate data folders. Use it in accordance with [Discord's Terms of Service](https://discord.com/terms).

## License

[MIT](LICENSE) © Mohammad Al-Safadi
