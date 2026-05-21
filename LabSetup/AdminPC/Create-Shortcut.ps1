$root = $env:PUBLIC
$SourceFilePath = "C:\Users\adsa\OneDrive - mrhozi\PowerShell Module\AS2Go\2026.05.21.957\Private\Create-DA-Tickets.ps1"
$ShortcutPath = "$root\Desktop\Create Tickets for PtT2.lnk"
$PowerShellExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$WScriptObj = New-Object -ComObject ("WScript.Shell")
$shortcut = $WscriptObj.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $PowerShellExe
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$SourceFilePath`""
$shortcut.WorkingDirectory = Split-Path -Path $SourceFilePath
$shortcut.IconLocation = "$PowerShellExe,0"
$shortcut.Save()

# Set "Run as administrator" (RunAsUser) flag in the .lnk header.
$bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
$bytes[0x15] = $bytes[0x15] -bor 0x20
[System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)