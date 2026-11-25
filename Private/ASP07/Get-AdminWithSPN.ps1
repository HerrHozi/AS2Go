function Get-AdminWithSPN {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for priviledge accounts with SPN                        #####                                 
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin
    
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
    Measure-FunctionRuntime -End -Details $Info

    return $foundAdminWithSPN
}
