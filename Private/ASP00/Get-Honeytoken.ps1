<#
.SYNOPSIS
Displays the configured MDI honeytoken account.

.DESCRIPTION
Reads the Honeytoken setting and displays it beneath the HoneyToken heading, or warns
when the setting is empty.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Displays the configured honeytoken or warns if unset.
#>
function Get-Honeytoken {

    ################################################################################
    #####                                                                      ##### 
    #####    Check if a honeytoken was selected                                #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type H1 -Message "`nCurrent HoneyToken"
    
    $previousDN = Get-ASConfig -Setting "Honeytoken"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        Write-AS2GoOutput -Type Bullet -Message "Identified HoneyToken" -TM $previousCN
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No Honeytoken identified."
    }

    Measure-FunctionRuntime -End -Details $Info
}
