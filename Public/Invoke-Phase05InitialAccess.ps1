<#
.SYNOPSIS
    Reviews the current user's Active Directory account and local security context.

.DESCRIPTION
    Displays local administrator and token elevation status, then retrieves the current user's Active Directory
    account, password policy, and group membership information. Safe Mode skips the Active Directory lookup.

    In the AS2Go lab, privileged groups such as Domain Admins and Enterprise Admins can be moved to the Tier 0
    Groups OU. The lab applies an inherited deny permission for the configured scenario-user group on that OU.
    As a result, a newly created AS2Go scenario user may not be able to enumerate those groups or read their
    memberships. This is an intentional part of the Tier 0 visibility boundary; ASP05 can therefore show only
    the group information available to the current account.

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

.PARAMETER UnAttended
    When specified, skips the pause at the end of the AS2Go demo workflow.

.PARAMETER DeveloperMode
    Enables developer behavior, including logging and suppressing images and console clearing.

.PARAMETER SafeMode
    Skips the Active Directory account and group information lookup.

.EXAMPLE
    PS C:\> Invoke-ASPhase05InitialAccess
    Displays the current user's Active Directory and local security context.

.EXAMPLE
    PS C:\> Invoke-ASPhase05InitialAccess -UnAttended
    Displays the phase information and returns without waiting at the end of the AS2Go demo workflow.

.NOTES
    Requires a domain-connected Windows session and the ActiveDirectory PowerShell module for the directory lookup.
    Group enumeration can be limited by Active Directory permissions, including the AS2Go Tier 0 lab ACL.

.LINK
    Invoke-ASPhase05InitialAccess

.FUNCTIONALITY
Reviews the current user's AD account, password policy, and visible group memberships, then reports local
administrator and token elevation status. AS2Go Tier 0 permissions may restrict group visibility.

#>

function Invoke-ASPhase05InitialAccess {

    ################################################################################
    #####                                                                      #####
    #####    Run the Attack Phase - Initial Access                              #####
    #####                                                                      #####
    ################################################################################

    [Alias("ASP05")]
    Param (
        [switch]$Preview,
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$Simulation,
        [Alias("DelevoperMode")]
        [switch]$DeveloperMode,
        [switch]$SafeMode
    )
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase05InitialAccess' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

    $Info = Measure-FunctionRuntime -Begin

    If ($DeveloperMode) {
        $SkipImages = $true
        $SkipClearHost = $true
        $EnableLogging = $true
    }

    If (-not $AS2GoDemo) { Set-NewColorSchema -NewStage $Script:InitialStart }
    If (-not $SkipClearHost) { Clear-Host }

    Update-WindowTitle -NewTitle $Script:Phase05
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase05

    Show-CurrentPhase -Phase "ASP05.html"

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase05.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((get-help (Get-FunctionName)).Functionality)

    Update-WindowTitle -NewTitle $Script:Phase05

    Write-AS2GoOutput -Type H1 -Message "`nChecking local administrator status"
    Test-LocalAdministrator | Format-List

    If(-not $safeMode) {
        Write-AS2GoOutput -Type H1 -M "Retrieving current AD user information"
        Get-CurrentADUserInfo | Format-List
    }


    If ($AS2GoDemo) {
        if (-not $UnAttended) {
            pause
        }
    }
    Measure-FunctionRuntime -End -Details $Info
}
