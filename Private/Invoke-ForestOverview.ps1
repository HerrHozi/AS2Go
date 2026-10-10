<#
.SYNOPSIS
Displays an overview of domains and domain controllers in the current forest.

.DESCRIPTION
Collects domain details, domain classifications, controller counts, and preferred controllers,
then displays a formatted forest overview.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Combines domain details, domain types, controller counts, and preferred DCs in a forest summary.
#>
function Invoke-ForestOverview {

    ################################################################################
    #####                                                                      ##### 
    #####    Collect info about the current foest, incl. the best DC           #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    $Script:DoaminTypes = Get-DomainType
    $Script:DCsPerDomain = Get-NumberofDCs
    $Script:BestDCs = Set-BestDomainController
    $Forest = Get-ADForest

    $AllDomainsDetails = $Forest.Domains | ForEach-Object {
        Get-DomainPWDetails -DomainName $_
    }

    invoke-output -Type Header -Message "Identified the following domains"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Invoke-Output -Type H1 -Message $Functionality

    $overview = $AllDomainsDetails |
    Select-Object `
    @{N = 'Domain'; E = { $_.NetBIOSName } },
    @{N = 'DomainType'; E = { $_.DomainType } },
    @{N = 'EnabledUsers'; E = { $_.EnabledUser } },
    @{N = 'DomainMode'; E = { $_.DomainMode } },
    @{N = 'MachineAccountQuota'; E = { $_.MachineAccountQuota } },
    @{N = 'RWDCs'; E = { $Script:DCsPerDomain[$_.DomainFQDN].RWDC } },
    @{N = 'RODCs'; E = { $Script:DCsPerDomain[$_.DomainFQDN].RODC } },
    @{N = 'Best DC'; E = { $Script:BestDCs[$_.DomainFQDN] } },
    @{N = 'FQDN'; E = { $_.DomainFQDN } }

    $FQDN = (Get-ADDomain).DNSRoot
    Set-TextMarker -OldFormat $overview -column 'FQDN' -value $FQDN -color $Script:fgcC


    if ($null -ne $script:ErrorForestInfo ) {
        Invoke-output -Type Error -Message $script:ErrorForestInfo
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}