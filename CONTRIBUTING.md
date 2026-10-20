# Contributing to Multi Discord

Thanks for your interest in improving Multi Discord! Bug reports, ideas, and pull requests are all welcome.

## Project layout

| File | Purpose |
| --- | --- |
| `DiscordMulti.ps1` | Windows GUI (PowerShell + WinForms) |
| `Start-DiscordMulti.bat` | Windows launcher (bypasses execution policy for this process only) |
| `discord-multi.sh` | Linux & macOS version (bash) |
| `installer/DiscordMulti.nsi` | Windows installer (NSIS). Build: `makensis -DVERSION=1.1.1 installer/DiscordMulti.nsi` |
| `assets/` | Logo (`logo.svg` is the source; `logo.png` / `logo.ico` are generated from it) |

When you add a feature, try to add it to **both** versions so they stay in sync.

## Reporting bugs

Open an issue using the **Bug report** template and include:

- OS and version
- Discord variant (Stable / PTB / Canary / Flatpak) and version
- Whether your main Discord was open at the time
- What you expected vs. what happened (screenshots help)

## Suggesting features

Open an issue using the **Feature request** template. Describe the problem you want solved, not just the solution.

## Pull requests

1. Fork the repo and create a branch: `git checkout -b feature/my-change`
2. Make your change.
3. Test it:
   - Add a profile, launch it, log in
   - Launch two profiles at the same time alongside your main Discord
   - Toggle start-at-login and the shortcut / menu entry
   - Delete a profile
4. Run the linters locally (same checks as CI):
   ```powershell
   Install-Module PSScriptAnalyzer -Scope CurrentUser
   Invoke-ScriptAnalyzer -Path . -Recurse
   ```
   ```bash
   shellcheck discord-multi.sh
   ```
5. Add a line to `CHANGELOG.md` under **Unreleased**.
6. Open a pull request describing what changed and how you tested it.

## Code guidelines

**Windows (`DiscordMulti.ps1`)**
- Must run on **Windows PowerShell 5.1** with no extra modules — no PowerShell 7-only syntax (`??`, `?.`, ternary, etc.).
- Keep it saved as **UTF-8 with BOM** and CRLF line endings.

**Linux / macOS (`discord-multi.sh`)**
- Must run on the **bash 3.2** that ships with macOS — no associative arrays, `mapfile`, or `${var,,}`.
- No required dependencies beyond standard tools; `zenity` and `python3` are optional.
- LF line endings.

**Both**
- Keep each version a single file.
- Never modify Discord's installation files; only work inside the tool's own `profiles` folder.
- Bump the version in both scripts (`$AppVersion` / `VERSION`) when releasing.

## Code of conduct

Be respectful and constructive. Harassment of any kind is not tolerated.
