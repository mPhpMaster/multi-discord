param([string]$ProfileName, [switch]$Minimized)

# ============================================================
#  Discord Multi - run multiple Discord instances with different accounts
#  Each profile gets its own data folder (separate login session)
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$AppName    = 'Discord Multi'
$AppVersion = '1.1.1'
$GitHubUser = 'mphpmaster'
$RepoUrl    = 'https://github.com/mphpmaster/multi-discord'
$DonateUrl  = 'https://paypal.me/mfsafadi'

# Profiles location:
#  - Default: one shared folder for every copy (installed, portable, cloned repo)
#  - Portable mode: create an empty "portable.txt" next to the script to keep profiles beside it
$PortableMode = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'portable.txt')
$LegacyRoot   = Join-Path $PSScriptRoot 'profiles'
if ($PortableMode) {
    $Root = $LegacyRoot
} else {
    $Root = Join-Path $env:LOCALAPPDATA 'Discord Multi\profiles'
}
New-Item -ItemType Directory -Force -Path $Root | Out-Null

# Move profiles created by older versions (stored next to the script) to the shared folder.
# A profile whose Discord is still running is skipped and moved on a later start.
function Move-LegacyProfiles {
    if ($PortableMode -or -not (Test-Path -LiteralPath $LegacyRoot)) { return @() }
    $skipped = @()
    foreach ($dir in @(Get-ChildItem -LiteralPath $LegacyRoot -Directory -ErrorAction SilentlyContinue)) {
        $dest = Join-Path $Root $dir.Name
        if (Test-Path -LiteralPath $dest) { $skipped += "$($dir.Name) (already exists)"; continue }
        # Renaming fails while Discord has files open: use it as an "in use" test
        $probe = "$($dir.Name).__moving"
        try { Rename-Item -LiteralPath $dir.FullName -NewName $probe -ErrorAction Stop }
        catch { $skipped += "$($dir.Name) (Discord is running)"; continue }
        $src = Join-Path $LegacyRoot $probe
        try {
            Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force -ErrorAction Stop
            Remove-Item -LiteralPath $src -Recurse -Force -ErrorAction Stop
        } catch {
            # Roll back so nothing is lost
            if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
            Rename-Item -LiteralPath $src -NewName $dir.Name -ErrorAction SilentlyContinue
            $skipped += "$($dir.Name) (could not copy)"
        }
    }
    if (-not (Get-ChildItem -LiteralPath $LegacyRoot -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $LegacyRoot -Force -ErrorAction SilentlyContinue
    }
    return $skipped
}
$LogoIco = Join-Path $PSScriptRoot 'assets\logo.ico'
$LogoPng = Join-Path $PSScriptRoot 'assets\logo.png'

# Folder of a profile: the shared folder, or the old location if it has not been moved yet
function Get-ProfileDir([string]$name) {
    $p = Join-Path $Root $name
    if (Test-Path -LiteralPath $p) { return $p }
    if (-not $PortableMode) {
        $old = Join-Path $LegacyRoot $name
        if (Test-Path -LiteralPath $old) { return $old }
    }
    return $p
}

function Get-ProfileNames {
    $names = @(Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    if (-not $PortableMode -and (Test-Path -LiteralPath $LegacyRoot)) {
        $names += @(Get-ChildItem -LiteralPath $LegacyRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notlike '*.__moving' } | ForEach-Object { $_.Name })
    }
    return @($names | Sort-Object -Unique)
}

function Get-DiscordExe {
    # Prefer Stable, then PTB, then Canary
    $variants = @(
        @{ Dir = 'Discord';       Exe = 'Discord.exe' },
        @{ Dir = 'DiscordPTB';    Exe = 'DiscordPTB.exe' },
        @{ Dir = 'DiscordCanary'; Exe = 'DiscordCanary.exe' }
    )
    foreach ($v in $variants) {
        $dir = Join-Path $env:LOCALAPPDATA $v.Dir
        if (-not (Test-Path $dir)) { continue }
        $apps = Get-ChildItem $dir -Directory -Filter 'app-*' -ErrorAction SilentlyContinue |
            Sort-Object { try { [version]($_.Name -replace '^app-', '') } catch { [version]'0.0' } } -Descending
        foreach ($a in $apps) {
            $exe = Join-Path $a.FullName $v.Exe
            if (Test-Path $exe) { return $exe }
        }
    }
    return $null
}

function Show-Msg($text, $icon = 'Information') {
    [System.Windows.Forms.MessageBox]::Show($text, 'Discord Multi', 'OK', $icon) | Out-Null
}

function Start-DiscordProfile([string]$name, [bool]$minimized = $false) {
    $exe = Get-DiscordExe
    if (-not $exe) {
        Show-Msg "Discord is not installed on this computer.`nInstall it from discord.com/download and try again." 'Error'
        return
    }
    $roaming = Join-Path (Get-ProfileDir $name) 'Roaming'
    New-Item -ItemType Directory -Force -Path $roaming | Out-Null

    # Discord's data folder name depends on the variant (discord / discordptb / discordcanary)
    $dataName = ([System.IO.Path]::GetFileNameWithoutExtension($exe)).ToLower()
    $userData = Join-Path $roaming $dataName
    New-Item -ItemType Directory -Force -Path $userData | Out-Null

    # Skip the updater: it is shared with the main Discord and gets stuck on "Starting..."
    $settingsFile = Join-Path $userData 'settings.json'
    $settings = $null
    if (Test-Path $settingsFile) {
        try { $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json } catch { $settings = $null }
    }
    if (-not $settings) { $settings = New-Object PSObject }
    $settings | Add-Member -NotePropertyName 'SKIP_HOST_UPDATE'   -NotePropertyValue $true -Force
    $settings | Add-Member -NotePropertyName 'SKIP_MODULE_UPDATE' -NotePropertyValue $true -Force
    [System.IO.File]::WriteAllText($settingsFile, ($settings | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))

    # Older Discord builds keep their modules in the data folder: copy them from the main install
    $realUserData = Join-Path $env:APPDATA $dataName
    if (Test-Path $realUserData) {
        Get-ChildItem $realUserData -Directory | Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } | ForEach-Object {
            $dest = Join-Path $userData $_.Name
            if (-not (Test-Path $dest)) { Copy-Item $_.FullName $dest -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    # No --multi-instance: each profile has its own data folder, so Discord's single-instance
    # lock is per profile. Opening a profile that is already running (e.g. hidden in the tray)
    # just brings its window back instead of starting a second copy, which can't read the
    # saved login while the first one holds it and would show the login screen.
    $psi.Arguments = ''
    if ($minimized) { $psi.Arguments = '--start-minimized' }
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = Split-Path $exe
    # Redirect Discord's data to this profile's folder instead of the default one.
    # Electron ignores %APPDATA% on Windows, but Discord honors DISCORD_USER_DATA_DIR.
    $psi.EnvironmentVariables['DISCORD_USER_DATA_DIR'] = $roaming
    $psi.EnvironmentVariables['APPDATA'] = $roaming
    # Vencord would otherwise keep separate settings per profile ("<profile>\VencordData"):
    # point every profile at the main Vencord settings so they all share one set.
    $vencordDir = if ($env:VENCORD_USER_DATA_DIR) { $env:VENCORD_USER_DATA_DIR } else { Join-Path $env:APPDATA 'Vencord' }
    $psi.EnvironmentVariables['VENCORD_USER_DATA_DIR'] = $vencordDir
    [System.Diagnostics.Process]::Start($psi) | Out-Null
}

function Save-ProfileShortcut([string]$lnkPath, [string]$name, [bool]$minimized) {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnkArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -ProfileName `"$name`""
    if ($minimized) { $lnkArgs += ' -Minimized' }
    $lnk.Arguments = $lnkArgs
    $exe = Get-DiscordExe
    if ($exe) { $lnk.IconLocation = "$exe,0" }
    $lnk.WindowStyle = 7
    $lnk.Save()
}

function New-ProfileShortcut([string]$name) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    Save-ProfileShortcut (Join-Path $desktop "Discord - $name.lnk") $name $false
    Show-Msg "Desktop shortcut created:`nDiscord - $name"
}

# ---- Start with Windows (a shortcut in the user's Startup folder) ----
function Get-StartupShortcutPath([string]$name) {
    $startup = [Environment]::GetFolderPath('Startup')
    return Join-Path $startup "Discord Multi - $name.lnk"
}

function Test-ProfileStartup([string]$name) {
    return Test-Path -LiteralPath (Get-StartupShortcutPath $name)
}

function Set-ProfileStartup([string]$name, [bool]$enabled) {
    $path = Get-StartupShortcutPath $name
    if ($enabled) {
        Save-ProfileShortcut $path $name $true
    } elseif (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
    }
}

# ---- Start Menu entry for the tool itself ----
function Get-StartMenuPath {
    return Join-Path ([Environment]::GetFolderPath('Programs')) "$AppName.lnk"
}

function Test-StartMenu { return Test-Path -LiteralPath (Get-StartMenuPath) }

function Set-StartMenu([bool]$enabled) {
    $path = Get-StartMenuPath
    if (-not $enabled) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        return
    }
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.Description = 'Run multiple Discord accounts at once'
    if (Test-Path $LogoIco) { $lnk.IconLocation = "$LogoIco,0" }
    $lnk.WindowStyle = 7
    $lnk.Save()
}

# Launched from a shortcut: start the profile directly, no UI
if ($ProfileName) {
    [void](Move-LegacyProfiles)
    # Get-ProfileDir also finds profiles not moved yet (still in use)
    if (-not (Test-Path -LiteralPath (Get-ProfileDir $ProfileName))) { exit }
    Start-DiscordProfile $ProfileName $Minimized.IsPresent
    exit
}

# ======================= UI =======================
$font = New-Object System.Drawing.Font('Segoe UI', 10)

$form = New-Object System.Windows.Forms.Form
$form.Text = "$AppName $AppVersion - Multiple Accounts"
$form.Size = New-Object System.Drawing.Size(460, 510)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = $font
$form.BackColor = [System.Drawing.Color]::FromArgb(54, 57, 63)
$form.ForeColor = [System.Drawing.Color]::White
if (Test-Path $LogoIco) { try { $form.Icon = New-Object System.Drawing.Icon($LogoIco) } catch { } }

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'Profiles (each one = a separate account):'
$lbl.Location = New-Object System.Drawing.Point(15, 12)
$lbl.AutoSize = $true
$form.Controls.Add($lbl)

$list = New-Object System.Windows.Forms.ListBox
$list.Location = New-Object System.Drawing.Point(15, 40)
$list.Size = New-Object System.Drawing.Size(250, 340)
$list.BackColor = [System.Drawing.Color]::FromArgb(47, 49, 54)
$list.ForeColor = [System.Drawing.Color]::White
$list.BorderStyle = 'FixedSingle'
$form.Controls.Add($list)

function Refresh-List {
    $list.Items.Clear()
    foreach ($n in (Get-ProfileNames)) { [void]$list.Items.Add($n) }
    if ($list.Items.Count -gt 0) {
        $list.SelectedIndex = 0
    } elseif ($chkStartup) {
        $chkStartup.Enabled = $false
        $chkStartup.Checked = $false
    }
}

function New-Btn($text, $y, $color) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point(280, $y)
    $b.Size = New-Object System.Drawing.Size(150, 32)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 0
    $b.BackColor = $color
    $b.ForeColor = [System.Drawing.Color]::White
    $b.Cursor = 'Hand'
    $form.Controls.Add($b)
    return $b
}

$blurple = [System.Drawing.Color]::FromArgb(88, 101, 242)
$gray    = [System.Drawing.Color]::FromArgb(79, 84, 92)
$red     = [System.Drawing.Color]::FromArgb(218, 55, 60)
$green   = [System.Drawing.Color]::FromArgb(35, 165, 89)

$btnRun    = New-Btn 'Launch'            40  $green
$btnRunAll = New-Btn 'Launch All'        78  $blurple
$btnLnk    = New-Btn 'Desktop Shortcut'  116 $gray
$btnStart  = New-Btn 'Add to Start Menu' 154 $gray
$btnFolder = New-Btn 'Open Folder'       192 $gray
$btnRename = New-Btn 'Rename'            230 $gray
$btnDel    = New-Btn 'Delete'            268 $red
$btnAbout  = New-Btn 'About'             340 $gray

$chkStartup = New-Object System.Windows.Forms.CheckBox
$chkStartup.Text = 'Start with Windows'
$chkStartup.Location = New-Object System.Drawing.Point(282, 308)
$chkStartup.Size = New-Object System.Drawing.Size(160, 26)
$chkStartup.ForeColor = [System.Drawing.Color]::White
$chkStartup.Cursor = 'Hand'
$form.Controls.Add($chkStartup)
$script:updatingStartup = $false

$txt = New-Object System.Windows.Forms.TextBox
$txt.Location = New-Object System.Drawing.Point(15, 395)
$txt.Size = New-Object System.Drawing.Size(250, 28)
$txt.BackColor = [System.Drawing.Color]::FromArgb(64, 68, 75)
$txt.ForeColor = [System.Drawing.Color]::White
$txt.BorderStyle = 'FixedSingle'
$form.Controls.Add($txt)

$btnAdd = New-Btn '+  Add Account' 390 $blurple

$hint = New-Object System.Windows.Forms.Label
$hint.Text = 'Type a name (e.g. Work) and click Add. Double-click a name to launch.'
$hint.Location = New-Object System.Drawing.Point(15, 435)
$hint.Size = New-Object System.Drawing.Size(420, 22)
$hint.ForeColor = [System.Drawing.Color]::FromArgb(185, 187, 190)
$hint.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
$form.Controls.Add($hint)

function Get-Selected {
    if ($list.SelectedItem) { return [string]$list.SelectedItem }
    Show-Msg 'Select a profile from the list first.' 'Warning'
    return $null
}

$addAction = {
    $name = $txt.Text.Trim()
    if (-not (Test-ProfileName $name)) { return }
    $p = Join-Path $Root $name
    if (Test-Path -LiteralPath (Get-ProfileDir $name)) { Show-Msg 'A profile with this name already exists.' 'Warning'; return }
    New-Item -ItemType Directory -Force -Path (Join-Path $p 'Roaming') | Out-Null
    $txt.Clear()
    Refresh-List
    $list.SelectedItem = $name
}
$btnAdd.Add_Click($addAction)
$txt.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { $_.SuppressKeyPress = $true; & $addAction } })

$btnRun.Add_Click({ $n = Get-Selected; if ($n) { Start-DiscordProfile $n } })
$list.Add_DoubleClick({ if ($list.SelectedItem) { Start-DiscordProfile ([string]$list.SelectedItem) } })

$btnRunAll.Add_Click({
    if ($list.Items.Count -eq 0) { Show-Msg 'No profiles yet.' 'Warning'; return }
    foreach ($n in @($list.Items)) { Start-DiscordProfile ([string]$n); Start-Sleep -Milliseconds 1500 }
})

$btnLnk.Add_Click({ $n = Get-Selected; if ($n) { New-ProfileShortcut $n } })

# ---- Start Menu toggle ----
function Update-StartMenuButton {
    if (Test-StartMenu) { $btnStart.Text = 'Remove from Start' } else { $btnStart.Text = 'Add to Start Menu' }
}
$btnStart.Add_Click({
    try {
        if (Test-StartMenu) {
            Set-StartMenu $false
            Show-Msg "$AppName was removed from the Start menu."
        } else {
            Set-StartMenu $true
            Show-Msg "$AppName was added to the Start menu."
        }
    } catch {
        Show-Msg "Could not update the Start menu:`n$($_.Exception.Message)" 'Error'
    }
    Update-StartMenuButton
})
Update-StartMenuButton

# ---- About dialog ----
function Show-About {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "About $AppName"
    $dlg.Size = New-Object System.Drawing.Size(380, 400)
    $dlg.StartPosition = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.ShowInTaskbar = $false
    $dlg.Font = $font
    $dlg.BackColor = $form.BackColor
    $dlg.ForeColor = [System.Drawing.Color]::White
    if ($form.Icon) { $dlg.Icon = $form.Icon }

    $y = 20
    if (Test-Path $LogoPng) {
        $pic = New-Object System.Windows.Forms.PictureBox
        $pic.Image = [System.Drawing.Image]::FromFile($LogoPng)
        $pic.SizeMode = 'Zoom'
        $pic.Size = New-Object System.Drawing.Size(88, 88)
        $pic.Location = New-Object System.Drawing.Point(138, $y)
        $dlg.Controls.Add($pic)
        $y += 98
    }

    $addLabel = {
        param($text, $size, $bold, $color)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text
        $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
        $l.Font = New-Object System.Drawing.Font('Segoe UI', $size, $style)
        $l.ForeColor = $color
        $l.TextAlign = 'MiddleCenter'
        $l.Size = New-Object System.Drawing.Size(344, ([int]($size * 2.4)))
        $l.Location = New-Object System.Drawing.Point(10, $script:aboutY)
        $dlg.Controls.Add($l)
        $script:aboutY += $l.Height + 2
    }
    $muted = [System.Drawing.Color]::FromArgb(185, 187, 190)
    $script:aboutY = $y
    & $addLabel $AppName 15 $true ([System.Drawing.Color]::White)
    & $addLabel "Version $AppVersion" 9.5 $false $muted
    & $addLabel 'Run multiple Discord accounts at once.' 9.5 $false $muted
    $script:aboutY += 8

    $addLink = {
        param($text, $url)
        $l = New-Object System.Windows.Forms.LinkLabel
        $l.UseMnemonic = $false   # show '&' literally
        $l.Text = $text
        $l.Tag = $url
        $l.TextAlign = 'MiddleCenter'
        $l.LinkColor = [System.Drawing.Color]::FromArgb(0, 168, 252)
        $l.ActiveLinkColor = [System.Drawing.Color]::White
        $l.Size = New-Object System.Drawing.Size(344, 24)
        $l.Location = New-Object System.Drawing.Point(10, $script:aboutY)
        $l.Add_LinkClicked({ param($s, $e) Start-Process ([string]$s.Tag) })
        $dlg.Controls.Add($l)
        $script:aboutY += 26
    }
    & $addLink "GitHub: @$GitHubUser" "https://github.com/$GitHubUser"
    & $addLink 'Source code & issues' $RepoUrl
    if ($DonateUrl) { & $addLink 'Donate via PayPal' $DonateUrl }

    $script:aboutY += 6
    & $addLabel 'MIT License - not affiliated with Discord Inc.' 8 $false $muted

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Close'
    $ok.Size = New-Object System.Drawing.Size(100, 32)
    $ok.Location = New-Object System.Drawing.Point(132, ($script:aboutY + 6))
    $ok.FlatStyle = 'Flat'
    $ok.FlatAppearance.BorderSize = 0
    $ok.BackColor = $blurple
    $ok.ForeColor = [System.Drawing.Color]::White
    $ok.DialogResult = 'OK'
    $dlg.Controls.Add($ok)
    $dlg.AcceptButton = $ok
    $dlg.ClientSize = New-Object System.Drawing.Size(364, ($script:aboutY + 52))

    [void]$dlg.ShowDialog($form)
    $dlg.Dispose()
}
$btnAbout.Add_Click({ Show-About })

# Keep the checkbox in sync with the selected profile
$list.Add_SelectedIndexChanged({
    $script:updatingStartup = $true
    if ($list.SelectedItem) {
        $chkStartup.Enabled = $true
        $chkStartup.Checked = Test-ProfileStartup ([string]$list.SelectedItem)
    } else {
        $chkStartup.Enabled = $false
        $chkStartup.Checked = $false
    }
    $script:updatingStartup = $false
})

$chkStartup.Add_CheckedChanged({
    if ($script:updatingStartup -or -not $list.SelectedItem) { return }
    try {
        Set-ProfileStartup ([string]$list.SelectedItem) $chkStartup.Checked
    } catch {
        Show-Msg "Could not update the startup setting:`n$($_.Exception.Message)" 'Error'
    }
})
$btnFolder.Add_Click({ Start-Process explorer.exe $Root })

function Test-ProfileName([string]$name) {
    if (-not $name) { Show-Msg 'Enter a name for the profile.' 'Warning'; return $false }
    if ($name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $name.StartsWith('.')) {
        Show-Msg 'The name contains invalid characters.' 'Warning'; return $false
    }
    return $true
}

$btnRename.Add_Click({
    $old = Get-Selected; if (-not $old) { return }
    Add-Type -AssemblyName Microsoft.VisualBasic
    $new = [Microsoft.VisualBasic.Interaction]::InputBox("New name for `"$old`":", 'Rename Profile', $old)
    $new = $new.Trim()
    if (-not $new -or $new -ceq $old) { return }
    if (-not (Test-ProfileName $new)) { return }
    $oldDir  = Get-ProfileDir $old
    $parent  = Split-Path $oldDir -Parent
    $newPath = Join-Path $parent $new
    # Allow case-only renames (same folder on Windows)
    if ((Test-Path -LiteralPath $newPath) -and ($new -ne $old)) { Show-Msg 'A profile with this name already exists.' 'Warning'; return }

    $hadStartup = Test-ProfileStartup $old
    $desktopOld = Join-Path ([Environment]::GetFolderPath('Desktop')) "Discord - $old.lnk"
    $hadDesktop = Test-Path -LiteralPath $desktopOld
    try {
        if ($new -ieq $old) {
            # Case-only rename needs a temporary name
            $tmp = Join-Path $parent ("_rename_" + [guid]::NewGuid().ToString('N'))
            Rename-Item -LiteralPath $oldDir -NewName (Split-Path $tmp -Leaf) -ErrorAction Stop
            Rename-Item -LiteralPath $tmp -NewName $new -ErrorAction Stop
        } else {
            Rename-Item -LiteralPath $oldDir -NewName $new -ErrorAction Stop
        }
    } catch {
        Show-Msg "Could not rename. Make sure that profile's Discord window is closed.`n`n$($_.Exception.Message)" 'Error'
        return
    }
    # Move the shortcuts that point to the old name
    if ($hadStartup) { Set-ProfileStartup $old $false; Set-ProfileStartup $new $true }
    if ($hadDesktop) {
        Remove-Item -LiteralPath $desktopOld -Force -ErrorAction SilentlyContinue
        Save-ProfileShortcut (Join-Path ([Environment]::GetFolderPath('Desktop')) "Discord - $new.lnk") $new $false
    }
    Refresh-List
    $list.SelectedItem = $new
})

$btnDel.Add_Click({
    $n = Get-Selected; if (-not $n) { return }
    $r = [System.Windows.Forms.MessageBox]::Show("Delete profile `"$n`" and all its data?`n(Close its Discord window first.)",
        'Confirm Delete', 'YesNo', 'Warning', 'Button2')
    if ($r -ne 'Yes') { return }
    try {
        Remove-Item -LiteralPath (Get-ProfileDir $n) -Recurse -Force -ErrorAction Stop
        Set-ProfileStartup $n $false
        Refresh-List
    } catch {
        Show-Msg 'Could not delete. Make sure that profile''s Discord window is closed.' 'Error'
    }
})

if (-not (Get-DiscordExe)) {
    $form.Add_Shown({ Show-Msg "Warning: Discord is not installed.`nInstall it first from discord.com/download" 'Warning' })
}

$notMoved = @(Move-LegacyProfiles)
if ($notMoved.Count -gt 0) {
    # They still work from the old folder; just let the user know they'll move later
    $hint.Text = 'Some profiles move to the shared folder once their Discord is closed.'
    $hint.ForeColor = [System.Drawing.Color]::FromArgb(250, 168, 26)
}

Refresh-List
[void]$form.ShowDialog()
