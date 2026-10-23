<#
.SYNOPSIS
Displays the account setting shown as the current honeytoken.

.DESCRIPTION
Reads the BreakGlassAccount setting and displays it beneath the HoneyToken heading, or warns
when the setting is empty.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Reads BreakGlassAccount and displays it under the HoneyToken heading, or warns if unset.
#>
function Get-Honeytoken {

    ################################################################################
    #####                                                                      ##### 
    #####    Check if a honeytoken was selected                                #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type H1 -Message "`nCurrent HoneyToken"
    
    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        Write-AS2GoOutput -Type Bullet -Message "Identified HoneyToken" -TM $previousCN
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No Honeytoken identified."
    }

    Measure-FunctionRuntime -End -Details $Info
}