<#
.SYNOPSIS
    Executes a password spray attack against Active Directory users in a specified scope.

.DESCRIPTION
    This function performs a password spray attack by attempting to authenticate multiple Active Directory users
    with one or more passwords. It provides multiple scope options (Forest, Root Domain, Current Domain, or specific OU)
    and allows the user to configure the attack parameters interactively or in unattended mode.

    The function performs password spray attacks using both standard authentication methods and Rubeus (if available).
    It checks domain password policies to calculate maximum safe spray attempts without locking accounts.

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

.PARAMETER UnAttended
    When specified, skips all interactive prompts and uses default values for automated execution.

.PARAMETER DeveloperMode
    When specified, displays additional debug information including successful credential matches.

.EXAMPLE
    PS C:\> Invoke-ASPhase05InitialAccess
    Runs an interactive password spray attack with prompts for scope and password selection.

.EXAMPLE
    PS C:\> Invoke-ASPhase05InitialAccess -UnAttended
    Runs an automated password spray attack using default settings (current domain, last stored password & the samaccount name as password).

.NOTES
    - Requires the ActiveDirectory PowerShell module
    - Displays current domain password policies before executing the attack
    - Logs all activities and execution times
    - Supports targeting Forest, Root Domain, Current Domain, or specific OUs
    - Optional Rubeus integration for Kerberos-based attacks

.LINK
    Invoke-ASPhase05InitialAccess

.FUNCTIONALITY
    Displays the current user's Active Directory account, domain, password policy, and group membership
    information using Get-CurrentADUserInfo, then reports local administrator membership and token
    elevation status using Test-LocalAdministrator.

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
        [switch]$DeveloperMode
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

    Show-CurrentPhase -Phase "phase_05.html"

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase05.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((get-help (Get-FunctionName)).Functionality)

    Update-WindowTitle -NewTitle $Script:Phase05

    Write-AS2GoOutput -Type H1 -Message "`nChecking local administrator status"
    Test-LocalAdministrator | Format-List

    Write-AS2GoOutput -Type H1 -M "Retrieving current AD user information"
    Get-CurrentADUserInfo | Format-List

    If ($AS2GoDemo) {
        if (-not $UnAttended) {
            pause
        }
    }
    Measure-FunctionRuntime -End -Details $Info
}
