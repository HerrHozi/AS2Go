<#
.SYNOPSIS
Displays the configured AS2Go lab assets and AD CS inventory.

.DESCRIPTION
Displays the saved break-glass setting, then inventories tiering OUs, AS2Go groups, and demo users in the current domain.
Inventories enterprise CAs and Web Enrollment services using a preferred root-domain controller.
Calls Get-Honeytoken and prints a completion message; this is an informational review, not a pass/fail validator.
The current Get-Honeytoken helper reads BreakGlassAccount rather than Honeytoken, so that section repeats that setting.

.PARAMETER param1
Reserved string parameter; currently unused.

.PARAMETER param2
Reserved string parameter; currently unused.

.EXAMPLE
Invoke-VerifyConfiguration
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires initialized module settings and directory access. The completion message does not certify that all prerequisites passed.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Reviews break-glass configuration, tiering OUs, AS2Go groups, demo users, and AD CS infrastructure.
Displays CA reachability and template status; the current honeytoken display repeats the break-glass setting.
#>
function Invoke-VerifyConfiguration {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $Info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $Info.FunctionName
    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type Header -Message "Check if all AS2GO Active Directory requirements are met."
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality

    Get-BreakGlassAccount

    $TargetServer = Get-BestDomainController -Domain (Get-ADDomain).DNSRoot
    Get-TieringAssets -Server $TargetServer
    Get-AS2GoGroups -Server $TargetServer
    Get-DemoAccounts -Server $TargetServer

    $bestDC = Get-BestDomainController -Domain (Get-ADForest).RootDomain
    Get-ADCSEnterpriseCA -Server $bestDC 
    Get-ADCSEnrollmentServices -Server $bestDC
    
    Get-Honeytoken

    Write-AS2GoOutput -Type Success "Environment check completed successfully."
    Measure-FunctionRuntime -End -Details $Info
}