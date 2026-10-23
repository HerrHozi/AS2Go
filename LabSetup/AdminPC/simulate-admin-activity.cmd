cd "C:\temp\AS2Go"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Add-RandomUser.ps1" -Enabled
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Create-DA-Tickets.ps1"
pause