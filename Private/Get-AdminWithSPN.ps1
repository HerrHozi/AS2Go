function Get-AdminWithSPN {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for priviledge accounts with SPN                        #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################
    
    [bool]$foundAdminWithSPN = $false

    try {
        $result = Get-ADUser -Filter { (adminCount -eq 1) -and (servicePrincipalName -like "*") -and (samAccountName -ne "krbtgt") } -Properties servicePrincipalName, adminCount -ErrorAction Stop
        If ($result) { $foundAdminWithSPN = $true }
    }
    catch {
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }

    Write-Log -Message "    >> Found '$($result.count) Admins with SPN!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $foundAdminWithSPN
}
