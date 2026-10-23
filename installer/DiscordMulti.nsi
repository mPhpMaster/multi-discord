; ============================================================
;  Discord Multi - Windows installer (NSIS 3)
;  Build:  makensis -DVERSION=1.1.5 installer/DiscordMulti.nsi
;  Output: dist/DiscordMulti-Setup-<version>.exe
; ============================================================

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
  !define VERSION "1.1.5"
!endif

!define APP_NAME     "Discord Multi"
!define APP_ID       "DiscordMulti"
!define PUBLISHER    "Mohammad Al-Safadi"
!define URL_REPO     "https://github.com/mphpmaster/multi-discord"
!define URL_DONATE   "https://paypal.me/mfsafadi"
!define SRC          ".."
!define UNINST_KEY   "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"
!define PS_EXE       "$WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
!define PS_ARGS      '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\DiscordMulti.ps1"'

Name "${APP_NAME}"
OutFile "${SRC}\dist\DiscordMulti-Setup-${VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "Software\${APP_ID}" "InstallDir"
RequestExecutionLevel user          ; per-user install, no admin needed
SetCompressor /SOLID lzma
BrandingText "${APP_NAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName"     "${APP_NAME}"
VIAddVersionKey "ProductVersion"  "${VERSION}"
VIAddVersionKey "FileVersion"     "${VERSION}"
VIAddVersionKey "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey "CompanyName"     "${PUBLISHER}"
VIAddVersionKey "LegalCopyright"  "MIT License - ${PUBLISHER}"

; ---------------------------------------------------------------- UI

!define MUI_ICON   "${SRC}\assets\logo.ico"
!define MUI_UNICON "${SRC}\assets\logo.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEFINISHPAGE_BITMAP   "welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP   "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
!define MUI_COMPONENTSPAGE_SMALLDESC

!define MUI_WELCOMEPAGE_TEXT "This will install ${APP_NAME} ${VERSION}.$\r$\n$\r$\nRun multiple Discord accounts at the same time, each in its own window.$\r$\n$\r$\nYour normal Discord is not modified.$\r$\n$\r$\nClick Next to continue."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME}"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!define MUI_FINISHPAGE_LINK "Support the project (PayPal)"
!define MUI_FINISHPAGE_LINK_LOCATION "${URL_DONATE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SRC}\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------------------------------------------------------------- sections

Section "${APP_NAME} (required)" SecCore
    SectionIn RO
    SetOutPath "$INSTDIR"
    File "${SRC}\DiscordMulti.ps1"
    File "${SRC}\Start-DiscordMulti.bat"
    File "${SRC}\README.md"
    File "${SRC}\LICENSE"
    SetOutPath "$INSTDIR\assets"
    File "${SRC}\assets\logo.ico"
    File "${SRC}\assets\logo.png"

    WriteUninstaller "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "Software\${APP_ID}" "InstallDir" "$INSTDIR"

    ; Apps & features entry
    WriteRegStr   HKCU "${UNINST_KEY}" "DisplayName"     "${APP_NAME}"
    WriteRegStr   HKCU "${UNINST_KEY}" "DisplayVersion"  "${VERSION}"
    WriteRegStr   HKCU "${UNINST_KEY}" "Publisher"       "${PUBLISHER}"
    WriteRegStr   HKCU "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\assets\logo.ico"
    WriteRegStr   HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr   HKCU "${UNINST_KEY}" "URLInfoAbout"    "${URL_REPO}"
    WriteRegStr   HKCU "${UNINST_KEY}" "HelpLink"        "${URL_REPO}/issues"
    WriteRegStr   HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr   HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" $0
SectionEnd

Section "Start Menu shortcut" SecStartMenu
    ; Same path the app's "Add to Start Menu" button uses, so the button stays in sync
    CreateShortCut "$SMPROGRAMS\${APP_NAME}.lnk" "${PS_EXE}" '${PS_ARGS}' \
        "$INSTDIR\assets\logo.ico" 0 SW_SHOWMINIMIZED "" "Run multiple Discord accounts at once"
SectionEnd

Section /o "Desktop shortcut" SecDesktop
    CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "${PS_EXE}" '${PS_ARGS}' \
        "$INSTDIR\assets\logo.ico" 0 SW_SHOWMINIMIZED "" "Run multiple Discord accounts at once"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecCore}      "The ${APP_NAME} app."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Add ${APP_NAME} to the Start menu."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop}   "Add a ${APP_NAME} icon to the desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function LaunchApp
    ; The installer is 32-bit: turn off WOW64 redirection so the 64-bit PowerShell starts
    ${If} ${RunningX64}
        ${DisableX64FSRedirection}
    ${EndIf}
    Exec '"${PS_EXE}" ${PS_ARGS}'
    ${If} ${RunningX64}
        ${EnableX64FSRedirection}
    ${EndIf}
FunctionEnd

; ---------------------------------------------------------------- uninstaller

Section "Uninstall"
    ; Shortcuts for the app and for each profile's "Start with Windows"
    Delete "$SMPROGRAMS\${APP_NAME}.lnk"
    Delete "$DESKTOP\${APP_NAME}.lnk"
    Delete "$SMSTARTUP\${APP_NAME} - *.lnk"

    Delete "$INSTDIR\DiscordMulti.ps1"
    Delete "$INSTDIR\Start-DiscordMulti.bat"
    Delete "$INSTDIR\README.md"
    Delete "$INSTDIR\LICENSE"
    Delete "$INSTDIR\assets\logo.ico"
    Delete "$INSTDIR\assets\logo.png"
    RMDir  "$INSTDIR\assets"

    ; Profiles hold the Discord logins: keep them unless the user says otherwise.
    ; Shared folder (v1.1+) and the old per-install folder.
    StrCpy $0 "$LOCALAPPDATA\${APP_NAME}\profiles"
    IfFileExists "$0\*.*" askProfiles 0
    IfFileExists "$INSTDIR\profiles\*.*" askProfiles keepProfiles
    askProfiles:
        IfSilent keepProfiles
        MessageBox MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2 \
            "Also delete your profiles?$\r$\n$\r$\nThis removes the saved Discord logins for every profile.$\r$\nChoose No to keep them for a future install." \
            IDNO keepProfiles
        RMDir /r "$0"
        RMDir "$LOCALAPPDATA\${APP_NAME}"
        RMDir /r "$INSTDIR\profiles"
    keepProfiles:
    RMDir "$INSTDIR\profiles"   ; only removed if empty

    Delete "$INSTDIR\Uninstall.exe"
    RMDir  "$INSTDIR"           ; only removed if empty

    DeleteRegKey HKCU "${UNINST_KEY}"
    DeleteRegKey HKCU "Software\${APP_ID}"
SectionEnd
