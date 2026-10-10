<#
.SYNOPSIS
Checks the configured AS2Go lab environment.

.FUNCTIONALITY
Audits break-glass, tiering, groups, demo users, AD CS, enrollment services, and honeytokens.
#>
function Invoke-VerifyConfiguration {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-Output -Type Header -Message "Check if all AS2GO Active Directory requirements are met."
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Invoke-Output -Type H1 -Message $Functionality

    Get-BreakGlassAccount

    $TargetServer = Get-BestDomainController -Domain (Get-ADDomain).DNSRoot
    Get-TieringAssets -Server $TargetServer
    Get-AS2GoGroups -Server $TargetServer
    Get-DemoAccounts -Server $TargetServer

    $bestDC = Get-BestDomainController -Domain (Get-ADForest).RootDomain
    Get-ADCSEnterpriseCA -Server $bestDC 
    Get-ADCSEnrollmentServices -Server $bestDC
    
    Get-Honeytoken

    Invoke-Output -Type Success "Environment check completed successfully."
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}