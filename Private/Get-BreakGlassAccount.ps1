<#
.SYNOPSIS
Displays the configured break-glass account.

.DESCRIPTION
Reads the saved account distinguished name and displays the resolved account or an unset-state
message.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Reads the saved account distinguished name and reports whether one is configured.
#>
function Get-BreakGlassAccount {

    ################################################################################
    #####                                                                      ##### 
    #####    Check if Break Glass Account was selected                         #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type H1 -Message "`nCurrent Break Glass Account"
    
    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        Write-AS2GoOutput -Type Bullet -Message "Identified Break Glass Account" -TM $previousCN
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No Break Glass Account identified."
    }

    Measure-FunctionRuntime -End -Details $Info
}