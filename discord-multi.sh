#!/usr/bin/env bash
# ============================================================
#  Discord Multi - run multiple Discord instances with different accounts
#  Linux & macOS version. Each profile gets its own data folder.
#
#  Usage: ./discord-multi.sh            (interactive menu / GUI)
#         ./discord-multi.sh help       (all commands)
# ============================================================

set -u

APP_NAME="Discord Multi"
VERSION="1.1.4"
GITHUB_USER="mphpmaster"
REPO_URL="https://github.com/mphpmaster/multi-discord"
DONATE_URL="https://paypal.me/mfsafadi"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
OS="$(uname -s)"

# Profiles location:
#  - Default: one shared folder for every copy of the script
#  - Portable mode: create an empty "portable.txt" next to the script to keep profiles beside it
#  - DISCORD_MULTI_PROFILES overrides both
LEGACY_DIR="$SCRIPT_DIR/profiles"
if [ -n "${DISCORD_MULTI_PROFILES:-}" ]; then
    PROFILES_DIR="$DISCORD_MULTI_PROFILES"
elif [ -f "$SCRIPT_DIR/portable.txt" ]; then
    PROFILES_DIR="$LEGACY_DIR"
elif [ "$OS" = "Darwin" ]; then
    PROFILES_DIR="$HOME/Library/Application Support/Discord Multi/profiles"
else
    PROFILES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/discord-multi/profiles"
fi

mkdir -p "$PROFILES_DIR"

# ---------------------------------------------------------------- helpers

die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

# A safe identifier for file names (autostart entries, launch agents)
slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }

valid_name() {
    case "$1" in
        ''|.*|*/*) return 1 ;;
    esac
    return 0
}

profile_exists() { [ -d "$PROFILES_DIR/$1" ]; }

list_profiles() {
    local d
    for d in "$PROFILES_DIR"/*/; do
        [ -d "$d" ] || continue
        basename "$d"
    done
}

# ---------------------------------------------------------------- find Discord
# Sets DISCORD_KIND (bin | flatpak), DISCORD_CMD and DISCORD_DATA_NAME.
# Override with DISCORD_BIN=/path/to/Discord if auto-detection fails.

find_discord() {
    DISCORD_KIND=""; DISCORD_CMD=""; DISCORD_DATA_NAME="discord"

    if [ -n "${DISCORD_BIN:-}" ]; then
        [ -x "$DISCORD_BIN" ] || die "DISCORD_BIN is not executable: $DISCORD_BIN"
        DISCORD_KIND="bin"; DISCORD_CMD="$DISCORD_BIN"
        DISCORD_DATA_NAME="${DISCORD_DATA_NAME_OVERRIDE:-discord}"
        return 0
    fi

    local c
    if [ "$OS" = "Darwin" ]; then
        for c in \
            "/Applications/Discord.app/Contents/MacOS/Discord|discord" \
            "$HOME/Applications/Discord.app/Contents/MacOS/Discord|discord" \
            "/Applications/Discord PTB.app/Contents/MacOS/Discord PTB|discordptb" \
            "/Applications/Discord Canary.app/Contents/MacOS/Discord Canary|discordcanary"
        do
            if [ -x "${c%|*}" ]; then
                DISCORD_KIND="bin"; DISCORD_CMD="${c%|*}"; DISCORD_DATA_NAME="${c#*|}"
                return 0
            fi
        done
        return 1
    fi

    # Linux: native installs first
    for c in \
        "/usr/share/discord/Discord|discord" \
        "/opt/discord/Discord|discord" \
        "/opt/Discord/Discord|discord" \
        "/usr/lib/discord/Discord|discord" \
        "/usr/share/discord-ptb/DiscordPTB|discordptb" \
        "/opt/discord-ptb/DiscordPTB|discordptb" \
        "/usr/share/discord-canary/DiscordCanary|discordcanary" \
        "/opt/discord-canary/DiscordCanary|discordcanary"
    do
        if [ -x "${c%|*}" ]; then
            DISCORD_KIND="bin"; DISCORD_CMD="${c%|*}"; DISCORD_DATA_NAME="${c#*|}"
            return 0
        fi
    done
    for c in discord discord-ptb discord-canary; do
        if command -v "$c" >/dev/null 2>&1; then
            DISCORD_KIND="bin"; DISCORD_CMD="$(command -v "$c")"
            case "$c" in
                discord-ptb)    DISCORD_DATA_NAME="discordptb" ;;
                discord-canary) DISCORD_DATA_NAME="discordcanary" ;;
            esac
            return 0
        fi
    done
    if command -v flatpak >/dev/null 2>&1 && flatpak info com.discordapp.Discord >/dev/null 2>&1; then
        DISCORD_KIND="flatpak"; DISCORD_CMD="com.discordapp.Discord"
        return 0
    fi
    return 1
}

real_user_data() {
    if [ "$OS" = "Darwin" ]; then
        printf '%s' "$HOME/Library/Application Support/$DISCORD_DATA_NAME"
    else
        printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/$DISCORD_DATA_NAME"
    fi
}

# The main Vencord settings folder. Every profile points at it so they all share one set
# (Vencord would otherwise keep separate settings in "<profile>/VencordData").
vencord_dir() {
    if [ -n "${VENCORD_USER_DATA_DIR:-}" ]; then
        printf '%s' "$VENCORD_USER_DATA_DIR"
    elif [ "$OS" = "Darwin" ]; then
        printf '%s' "$HOME/Library/Application Support/Vencord"
    elif [ "$DISCORD_KIND" = "flatpak" ]; then
        printf '%s' "$HOME/.var/app/$DISCORD_CMD/config/Vencord"
    else
        printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/Vencord"
    fi
}

# ---------------------------------------------------------------- prepare & launch

prepare_profile() {
    local name="$1"
    local data="$PROFILES_DIR/$name/data"
    local user_data="$data/$DISCORD_DATA_NAME"
    mkdir -p "$user_data"

    # Skip the updater: it is shared with the main Discord install
    local settings="$user_data/settings.json"
    if [ ! -s "$settings" ]; then
        printf '{\n  "SKIP_HOST_UPDATE": true,\n  "SKIP_MODULE_UPDATE": true\n}\n' > "$settings"
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$settings" <<'PY' || true
import json, sys
p = sys.argv[1]
try:
    with open(p) as f:
        d = json.load(f)
except Exception:
    d = {}
d["SKIP_HOST_UPDATE"] = True
d["SKIP_MODULE_UPDATE"] = True
with open(p, "w") as f:
    json.dump(d, f, indent=2)
PY
    fi

    # Older builds keep modules in the data folder: copy them from the main install
    local real v
    real="$(real_user_data)"
    if [ -d "$real" ]; then
        for v in "$real"/*/; do
            [ -d "$v" ] || continue
            v="$(basename "$v")"
            case "$v" in
                [0-9]*.[0-9]*.[0-9]*)
                    [ -e "$user_data/$v" ] || cp -R "$real/$v" "$user_data/$v" 2>/dev/null || true ;;
            esac
        done
    fi
}

launch_profile() {
    local name="$1" minimized="${2:-no}"
    valid_name "$name" || die "Invalid profile name: $name"
    # Not migrated yet (still in use): launch it from its old location
    if ! profile_exists "$name" && [ -d "$LEGACY_DIR/$name" ]; then PROFILES_DIR="$LEGACY_DIR"; fi
    profile_exists "$name" || die "Profile not found: $name"
    find_discord || die "Discord is not installed. Get it from https://discord.com/download (or set DISCORD_BIN)."

    prepare_profile "$name"
    local data="$PROFILES_DIR/$name/data"
    local log="$PROFILES_DIR/$name/discord.log"
    local vencord
    vencord="$(vencord_dir)"
    # No --multi-instance: the single-instance lock is per data folder, so a profile that is
    # already running is brought to the front instead of starting a second copy (which would
    # show the login screen because the first copy holds the saved login).
    local args=""
    [ "$minimized" = "yes" ] && args="--start-minimized"

    # Electron ignores XDG/HOME overrides for some paths; Discord honors DISCORD_USER_DATA_DIR.
    if [ "$DISCORD_KIND" = "flatpak" ]; then
        # The app's own ~/.var/app folder is always visible; only share a custom Vencord folder
        local share_vencord=""
        case "$vencord" in
            "$HOME/.var/app/$DISCORD_CMD"/*) ;;
            *) share_vencord="--filesystem=$vencord" ;;
        esac
        # shellcheck disable=SC2086
        nohup flatpak run --filesystem="$data" --env=DISCORD_USER_DATA_DIR="$data" \
            ${share_vencord:+"$share_vencord"} --env=VENCORD_USER_DATA_DIR="$vencord" \
            "$DISCORD_CMD" $args >"$log" 2>&1 &
    else
        # shellcheck disable=SC2086
        DISCORD_USER_DATA_DIR="$data" XDG_CONFIG_HOME="$data" VENCORD_USER_DATA_DIR="$vencord" \
            nohup "$DISCORD_CMD" $args >"$log" 2>&1 &
    fi
    disown 2>/dev/null || true
    info "Launched profile: $name"
}

launch_all() {
    local n found=0
    while IFS= read -r n; do
        [ -n "$n" ] || continue
        found=1
        launch_profile "$n"
        sleep 2
    done <<EOF
$(list_profiles)
EOF
    [ "$found" = 1 ] || info "No profiles yet."
}

add_profile() {
    local name="$1"
    valid_name "$name" || die "Invalid name (no '/', not starting with '.')."
    profile_exists "$name" && die "A profile with this name already exists."
    mkdir -p "$PROFILES_DIR/$name/data"
    info "Added profile: $name"
}

# True if Discord is running with this profile (Electron's SingletonLock -> "host-pid")
profile_running() {
    local lock target pid
    for lock in "$PROFILES_DIR/$1/data"/*/SingletonLock; do
        [ -L "$lock" ] || continue
        target="$(readlink "$lock" 2>/dev/null)" || continue
        pid="${target##*-}"
        case "$pid" in ''|*[!0-9]*) continue ;; esac
        kill -0 "$pid" 2>/dev/null && return 0
    done
    return 1
}

# Move profiles created by older versions (next to the script) into the shared folder.
# Profiles whose Discord is running are skipped and moved on a later run.
migrate_legacy_profiles() {
    [ -d "$LEGACY_DIR" ] || return 0
    [ "$LEGACY_DIR" -ef "$PROFILES_DIR" ] && return 0
    local d n saved="$PROFILES_DIR"
    for d in "$LEGACY_DIR"/*/; do
        [ -d "$d" ] || continue
        n="$(basename "$d")"
        [ -e "$PROFILES_DIR/$n" ] && continue
        PROFILES_DIR="$LEGACY_DIR"
        if profile_running "$n"; then PROFILES_DIR="$saved"; continue; fi
        PROFILES_DIR="$saved"
        mv "$LEGACY_DIR/$n" "$PROFILES_DIR/$n" 2>/dev/null || true
    done
    rmdir "$LEGACY_DIR" 2>/dev/null || true
}

shortcut_path() {
    local s; s="$(slug "$1")"
    if [ "$OS" = "Darwin" ]; then
        printf '%s' "$HOME/Desktop/Discord - $s.command"
    else
        printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/discord-multi-$s.desktop"
    fi
}

rename_profile() {
    local old="$1" new="$2"
    valid_name "$old" || die "Invalid profile name: $old"
    valid_name "$new" || die "Invalid name (no '/', not starting with '.')."
    profile_exists "$old" || die "Profile not found: $old"
    [ "$old" = "$new" ] && { info "Nothing to do."; return 0; }
    # Exists and is a different folder (same folder = case-only rename on macOS)
    if profile_exists "$new" && ! [ "$PROFILES_DIR/$old" -ef "$PROFILES_DIR/$new" ]; then
        die "A profile with this name already exists."
    fi
    profile_running "$old" && die "Close the Discord window of \"$old\" first."

    local had_startup="no" had_shortcut="no"
    startup_enabled "$old" && had_startup="yes"
    [ -f "$(shortcut_path "$old")" ] && had_shortcut="yes"

    # Two-step move so case-only renames work on case-insensitive file systems (macOS)
    local tmp="$PROFILES_DIR/.rename-$$"
    mv "$PROFILES_DIR/$old" "$tmp" && mv "$tmp" "$PROFILES_DIR/$new" || die "Could not rename the profile folder."

    if [ "$had_startup" = "yes" ]; then
        rm -f "$(startup_path "$old")"
        set_startup "$new" on >/dev/null
    fi
    if [ "$had_shortcut" = "yes" ]; then
        rm -f "$(shortcut_path "$old")"
        create_shortcut "$new" >/dev/null
    fi
    info "Renamed: $old -> $new"
}

remove_profile() {
    local name="$1"
    valid_name "$name" || die "Invalid profile name: $name"
    profile_exists "$name" || die "Profile not found: $name"
    set_startup "$name" off >/dev/null
    rm -rf "${PROFILES_DIR:?}/$name"
    info "Deleted profile: $name"
}

# ---------------------------------------------------------------- start at login

startup_path() {
    local s; s="$(slug "$1")"
    if [ "$OS" = "Darwin" ]; then
        printf '%s' "$HOME/Library/LaunchAgents/com.discordmulti.$s.plist"
    else
        printf '%s' "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/discord-multi-$s.desktop"
    fi
}

startup_enabled() { [ -f "$(startup_path "$1")" ]; }

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'
}

desktop_quote() {
    # Quote an argument for a .desktop Exec line
    printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/`/\\`/g' -e 's/\$/\\$/g')"
}

set_startup() {
    local name="$1" state="$2" path
    path="$(startup_path "$name")"
    case "$state" in
        on)
            profile_exists "$name" || die "Profile not found: $name"
            mkdir -p "$(dirname "$path")"
            if [ "$OS" = "Darwin" ]; then
                cat > "$path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.discordmulti.$(slug "$name")</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$(xml_escape "$SCRIPT_PATH")</string>
        <string>launch</string>
        <string>$(xml_escape "$name")</string>
        <string>--minimized</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
            else
                cat > "$path" <<EOF
[Desktop Entry]
Type=Application
Name=Discord ($name)
Comment=Discord Multi profile: $name
Exec=/bin/bash $(desktop_quote "$SCRIPT_PATH") launch $(desktop_quote "$name") --minimized
Icon=discord
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
            fi
            info "Start at login: ON for $name"
            ;;
        off)
            rm -f "$path"
            info "Start at login: OFF for $name"
            ;;
        *) die "Use: startup <name> on|off" ;;
    esac
}

# ---------------------------------------------------------------- shortcut

create_shortcut() {
    local name="$1" s
    profile_exists "$name" || die "Profile not found: $name"
    s="$(slug "$name")"
    if [ "$OS" = "Darwin" ]; then
        local f="$HOME/Desktop/Discord - $s.command"
        printf '#!/bin/bash\n/bin/bash %q launch %q\n' "$SCRIPT_PATH" "$name" > "$f"
        chmod +x "$f"
        info "Created: $f"
    else
        local dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
        local f="$dir/discord-multi-$s.desktop"
        mkdir -p "$dir"
        cat > "$f" <<EOF
[Desktop Entry]
Type=Application
Name=Discord ($name)
Comment=Discord Multi profile: $name
Exec=/bin/bash $(desktop_quote "$SCRIPT_PATH") launch $(desktop_quote "$name")
Icon=discord
Terminal=false
Categories=Network;InstantMessaging;
EOF
        chmod +x "$f"
        info "Added to the app menu: Discord ($name)"
    fi
}

# ---------------------------------------------------------------- app menu entry for the tool

menu_entry_path() {
    if [ "$OS" = "Darwin" ]; then
        printf '%s' "$HOME/Applications/$APP_NAME.command"
    else
        printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/applications/discord-multi.desktop"
    fi
}

set_menu_entry() {
    local state="$1" path
    path="$(menu_entry_path)"
    case "$state" in
        on)
            mkdir -p "$(dirname "$path")"
            if [ "$OS" = "Darwin" ]; then
                printf '#!/bin/bash\n/bin/bash %q\n' "$SCRIPT_PATH" > "$path"
                chmod +x "$path"
                info "Added to ~/Applications: $APP_NAME"
            else
                local term="false"
                command -v zenity >/dev/null 2>&1 || term="true"
                cat > "$path" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_NAME
Comment=Run multiple Discord accounts at once
Exec=/bin/bash $(desktop_quote "$SCRIPT_PATH")
Icon=$SCRIPT_DIR/assets/logo.png
Terminal=$term
Categories=Network;InstantMessaging;Utility;
EOF
                chmod +x "$path"
                info "Added to the app menu: $APP_NAME"
            fi
            ;;
        off)
            rm -f "$path"
            info "Removed from the app menu: $APP_NAME"
            ;;
        *) die "Use: menu on|off" ;;
    esac
}

about_text() {
    local t
    t="$APP_NAME $VERSION
Run multiple Discord accounts at once.

GitHub: https://github.com/$GITHUB_USER
Source code & issues: $REPO_URL"
    [ -n "$DONATE_URL" ] && t="$t
Donate via PayPal: $DONATE_URL"
    t="$t

MIT License - not affiliated with Discord Inc."
    printf '%s' "$t"
}

open_folder() {
    if [ "$OS" = "Darwin" ]; then open "$PROFILES_DIR"
    elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$PROFILES_DIR" >/dev/null 2>&1 &
    else info "$PROFILES_DIR"; fi
}

# ---------------------------------------------------------------- interactive UI
# Uses zenity (Linux) or AppleScript dialogs (macOS); falls back to a terminal menu.

UI="tty"
if [ "$OS" = "Darwin" ] && [ ! -t 0 ] && command -v osascript >/dev/null 2>&1; then
    UI="mac"
elif [ "$OS" = "Darwin" ] && [ "${DISCORD_MULTI_GUI:-}" = "1" ]; then
    UI="mac"
elif [ "$OS" != "Darwin" ] && command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] \
     && { [ ! -t 0 ] || [ "${DISCORD_MULTI_GUI:-}" = "1" ]; }; then
    UI="zenity"
fi

as_quote() { printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"; }

ui_msg() {
    case "$UI" in
        zenity) zenity --info --title="Discord Multi" --text="$1" 2>/dev/null ;;
        mac)    osascript -e "display dialog $(as_quote "$1") with title \"Discord Multi\" buttons {\"OK\"} default button 1" >/dev/null 2>&1 ;;
        *)      printf '\n%s\n' "$1" ;;
    esac
}

ui_input() {
    case "$UI" in
        zenity) zenity --entry --title="Discord Multi" --text="$1" 2>/dev/null ;;
        mac)    osascript -e "text returned of (display dialog $(as_quote "$1") default answer \"\" with title \"Discord Multi\")" 2>/dev/null ;;
        *)      local r; printf '%s ' "$1" >&2; IFS= read -r r; printf '%s' "$r" ;;
    esac
}

ui_confirm() {
    case "$UI" in
        zenity) zenity --question --title="Discord Multi" --text="$1" 2>/dev/null ;;
        mac)    osascript -e "display dialog $(as_quote "$1") with title \"Discord Multi\" buttons {\"Cancel\", \"Yes\"} default button 1" >/dev/null 2>&1 ;;
        *)      local r; printf '%s [y/N] ' "$1" >&2; IFS= read -r r; case "$r" in y|Y|yes) return 0 ;; esac; return 1 ;;
    esac
}

# ui_choose "Title" item1 item2 ...  -> prints the chosen item
ui_choose() {
    local title="$1"; shift
    [ $# -gt 0 ] || return 1
    case "$UI" in
        zenity)
            zenity --list --title="Discord Multi" --text="$title" --column="" --hide-header \
                --width=380 --height=420 "$@" 2>/dev/null ;;
        mac)
            local items="" i
            for i in "$@"; do items="$items$( [ -n "$items" ] && printf ', ')$(as_quote "$i")"; done
            local r
            r="$(osascript -e "choose from list {$items} with title \"Discord Multi\" with prompt $(as_quote "$title")" 2>/dev/null)"
            [ -n "$r" ] && [ "$r" != "false" ] && printf '%s' "$r" ;;
        *)
            local idx=1 i r
            printf '\n%s\n' "$title" >&2
            for i in "$@"; do printf '  %d) %s\n' "$idx" "$i" >&2; idx=$((idx + 1)); done
            printf 'Choose [1-%d]: ' "$#" >&2
            IFS= read -r r || return 1
            case "$r" in ''|*[!0-9]*) return 1 ;; esac
            [ "$r" -ge 1 ] && [ "$r" -le "$#" ] || return 1
            eval "printf '%s' \"\${$r}\"" ;;
    esac
}

pick_profile() {
    local items=() n
    while IFS= read -r n; do [ -n "$n" ] && items+=("$n"); done <<EOF
$(list_profiles)
EOF
    if [ ${#items[@]} -eq 0 ]; then ui_msg "No profiles yet. Add one first."; return 1; fi
    ui_choose "$1" "${items[@]}"
}

# Run a command; in GUI mode show errors as a dialog instead of exiting
run_ui() {
    local out
    if out="$( ( "$@" ) 2>&1 )"; then
        [ "$UI" = "tty" ] && [ -n "$out" ] && printf '%s\n' "$out"
        return 0
    fi
    ui_msg "${out:-Something went wrong.}"
    return 1
}

interactive() {
    local action name state
    while true; do
        action="$(ui_choose "Discord Multi $VERSION - what do you want to do?" \
            "Launch a profile" "Launch all" "Add account" "Start at login (on/off)" \
            "Create shortcut" "Rename a profile" "Delete a profile" "Open profiles folder" \
            "$( [ -f "$(menu_entry_path)" ] && echo "Remove from app menu" || echo "Add to app menu" )" \
            "About" "Quit")" || break
        case "$action" in
            "Launch a profile")
                name="$(pick_profile "Launch which profile?")" && run_ui launch_profile "$name" ;;
            "Launch all")
                run_ui launch_all ;;
            "Add account")
                name="$(ui_input "Profile name (e.g. Work):")" && [ -n "$name" ] && run_ui add_profile "$name" \
                    && ui_msg "Added \"$name\". Choose \"Launch a profile\" and log in with that account." ;;
            "Start at login (on/off)")
                if name="$(pick_profile "Start which profile at login?")"; then
                    if startup_enabled "$name"; then state="ON"; else state="OFF"; fi
                    if ui_confirm "Start at login is $state for \"$name\". Turn it $( [ "$state" = ON ] && echo OFF || echo ON )?"; then
                        if [ "$state" = ON ]; then run_ui set_startup "$name" off; else run_ui set_startup "$name" on; fi
                    fi
                fi ;;
            "Create shortcut")
                name="$(pick_profile "Create a shortcut for which profile?")" && run_ui create_shortcut "$name" \
                    && ui_msg "Shortcut created for \"$name\"." ;;
            "Rename a profile")
                if name="$(pick_profile "Rename which profile?")"; then
                    state="$(ui_input "New name for \"$name\":")" && [ -n "$state" ] \
                        && run_ui rename_profile "$name" "$state"
                fi ;;
            "Delete a profile")
                name="$(pick_profile "Delete which profile?")" \
                    && ui_confirm "Delete \"$name\" and all its data? Close its Discord window first." \
                    && run_ui remove_profile "$name" ;;
            "Open profiles folder")
                open_folder ;;
            "Add to app menu")
                run_ui set_menu_entry on && ui_msg "$APP_NAME was added to your app menu." ;;
            "Remove from app menu")
                run_ui set_menu_entry off && ui_msg "$APP_NAME was removed from your app menu." ;;
            "About")
                ui_msg "$(about_text)" ;;
            *) break ;;
        esac
    done
}

# ---------------------------------------------------------------- CLI

usage() {
    cat <<EOF
Discord Multi $VERSION - run multiple Discord accounts at once

Usage: $(basename "$0") [command]

  (no command)               Interactive menu (GUI if zenity / macOS dialogs are available)
  list                       List profiles (* = starts at login)
  add <name>                 Create a profile
  launch <name> [--minimized]  Launch a profile
  launch-all                 Launch every profile
  startup <name> on|off      Start the profile when you log in
  shortcut <name>            Add an app-menu entry (Linux) / Desktop launcher (macOS)
  rename <old> <new>         Rename a profile (keeps its login and shortcuts)
  remove <name>              Delete a profile and its data
  folder                     Open the profiles folder
  menu on|off                Add/remove Discord Multi in your app menu (~/Applications on macOS)
  about                      Version, links and donation info
  help                       Show this help

Environment:
  DISCORD_BIN=/path/to/Discord      Use a specific Discord binary
  DISCORD_MULTI_PROFILES=/path      Store profiles somewhere else

Profiles are stored in:
  $PROFILES_DIR
Create an empty portable.txt next to the script to keep them beside it instead.
  DISCORD_MULTI_GUI=1               Force dialogs even when run from a terminal
EOF
}

cmd="${1:-}"
[ $# -gt 0 ] && shift

[ -z "${DISCORD_MULTI_PROFILES:-}" ] && migrate_legacy_profiles

case "$cmd" in
    "")          interactive ;;
    list)
        while IFS= read -r n; do
            [ -n "$n" ] || continue
            if startup_enabled "$n"; then printf '%s *\n' "$n"; else printf '%s\n' "$n"; fi
        done <<EOF
$(list_profiles)
EOF
        ;;
    add)         [ $# -ge 1 ] || die "Usage: add <name>";      add_profile "$1" ;;
    launch)
        [ $# -ge 1 ] || die "Usage: launch <name> [--minimized]"
        if [ "${2:-}" = "--minimized" ]; then launch_profile "$1" yes; else launch_profile "$1"; fi ;;
    launch-all)  launch_all ;;
    startup)     [ $# -ge 2 ] || die "Usage: startup <name> on|off"; set_startup "$1" "$2" ;;
    shortcut)    [ $# -ge 1 ] || die "Usage: shortcut <name>"; create_shortcut "$1" ;;
    rename)      [ $# -ge 2 ] || die "Usage: rename <old> <new>"; rename_profile "$1" "$2" ;;
    remove|delete) [ $# -ge 1 ] || die "Usage: remove <name>"; remove_profile "$1" ;;
    folder)      open_folder ;;
    menu)        [ $# -ge 1 ] || die "Usage: menu on|off"; set_menu_entry "$1" ;;
    about)       about_text; printf '\n' ;;
    help|-h|--help) usage ;;
    version|--version) info "$VERSION" ;;
    *)           usage; exit 1 ;;
esac
