<#
.SYNOPSIS
Displays the configured break-glass account.

.FUNCTIONALITY
Reads the saved account distinguished name and reports whether one is configured.
#>
function Get-BreakGlassAccount {

    ################################################################################
    #####                                                                      ##### 
    #####    Check if Break Glass Account was selected                         #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type H1 -Message "`nCurrent Break Glass Account"
    
    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        Invoke-Output -Type Bullet -Message "Identified Break Glass Account" -TM $previousCN
    }
    else {
        Invoke-Output -Type Warning -Message "No Break Glass Account identified."
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}