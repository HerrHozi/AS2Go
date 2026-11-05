<#
.SYNOPSIS
    Runs the Phase 04 password-spray demonstration in an authorized Active Directory lab.

.DESCRIPTION
    Displays forest password-policy information, prompts for a target scope, and starts the Phase 04 demonstration.
    Interactive mode lets the operator select whether to use the configured password and account names as candidates.
    Unattended mode uses configured values. Run only in an explicitly authorized, isolated lab environment.

.PARAMETER Preview
    Browses descriptions and workflow steps offline without executing actions. Uses a separate preview menu; runtime
    selection and skip parameters are not evaluated.

.PARAMETER UnAttended
    Skips interactive prompts and uses configured values for execution.

.PARAMETER DeveloperMode
    Enables developer diagnostics and logging, and skips phase images and host clearing.

.PARAMETER SafeMode
    Limits the initial confirmation prompt to Skip, so the phase does not proceed.

.EXAMPLE
    PS C:\> Invoke-ASPhase04BruteForceAttack -Preview
    Browses the Phase 04 descriptions and workflow without executing the phase.

.NOTES
    - Requires the ActiveDirectory PowerShell module
    - Displays current domain password policies before executing the attack
    - The target scope is selected at runtime
    - Use only in explicitly authorized, isolated lab environments

.LINK
    Invoke-ASPhase04BruteForceAttack


.COMPONENT
    Category: Main Function

.FUNCTIONALITY
    Displays forest password policies, including account lockout thresholds and minimum password lengths.
    Selects a domain or forest scope and chooses the configured password and whether account names are tested.
    Unattended mode uses configured values; Preview is offline, and SafeMode prevents execution by allowing only Skip.
#>

function Invoke-ASPhase04BruteForceAttack {

    ################################################################################
    #####                                                                      #####
    #####    Run the Attack Phase - Brute Force Account                        #####
    #####                                                                      #####
    ################################################################################

    [Alias("ASP04", "PwSpray")]
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
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase04BruteForceAttack' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
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
    
    Show-CurrentPhase -Phase "phase_04.html"
    Update-WindowTitle -NewTitle $Script:Phase04
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase04

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -M "Attack Phase - $($Script:Phase04.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((get-help (Get-FunctionName)).Functionality)

    $promptParams = @{}
    if ($safemode) {
        $promptParams.Options = @(
            [pscustomobject]@{
                Label = '&Skip'
                Help  = 'Skip this step in Safe Mode'
                Value = $Script:No
            }
        )
    }
    
    If (-not $UnAttended) {
        $answer = Show-DecisionPrompt @promptParams
    }
    else {
        if ($safemode) {
            $answer = $Script:No
        }
        else {
            $answer = $Script:Yes
        }

    }



    If ($answer -ne $Script:Yes ) {
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-AS2GoOutput -Type  Error -M "The 'ActiveDirectory' PowerShell module is not installed."
        return
    }

    $Forest = Get-ADForest
    $Script:DoaminTypes = Get-DomainType

    $AllDomainsDetails = $Forest.Domains | ForEach-Object {
        Get-DomainPWDetails -DomainName $_
    }

    Write-Host "`nDiscovered Domain Password Policy Settings in the Forest:" -ForegroundColor $Script:FGCHighLight

    $AllDomainsDetails |
    Select-Object `
    @{N = 'Domain'; E = { $_.NetBIOSName } },
    @{N = 'DomainType'; E = { $_.DomainType } },
    @{N = 'Enabled Users'; E = { $_.EnabledUser } },
    @{N = 'Min. Pw Length'; E = { $_.MinPasswordLength } },
    @{N = 'Complexity'; E = { $_.ComplexityEnabled } },
    @{N = 'Lockout Threshold'; E = { $_.LockoutThreshold } },
    @{N = 'Lockout Duration'; E = { $_.LockoutDuration } },
    @{N = 'LockWin'; E = { $_.LockoutObservationWindow } },
    @{N = 'RevEnc'; E = { $_.ReversibleEncryptionEnabled } },
    @{N = 'FQDN'; E = { $_.DomainFQDN } } | Format-Table -AutoSize


    [int]$NoLT = ($AllDomainsDetails | 
        Where-Object { $null -ne $_.LockoutThreshold -and $_.LockoutThreshold -gt 0 } | 
        Measure-Object -Property LockoutThreshold -Minimum).Minimum

    If ($NoLT -eq 0) {

        #The number of failed logon attempts that causes a user account to be locked out is 0;
        #this means the account will NEVER be locked out.
        Write-Host "The account lockout threshold is configured to " -NoNewline
        Write-Host $NoLT -ForegroundColor $fgcH -NoNewline
        Write-Host "; as a result, user accounts will " -NoNewline
        Write-Host "never" -ForegroundColor $fgcH -NoNewline
        Write-Host " be locked out, regardless of the number of failed logon attempts.`n"
    }
    else {
        # The number of failed logon attempts that causes a user account to be locked out is [n];
        # this means you can run a maximum of [n-1] single 'Password Spray' Attacks.
        [int] $NoPS = $NoLT - 1

        Write-Host "The minimum account lockout threshold configured across all domains in the forest is " -NoNewline
        Write-Host $NoLT -ForegroundColor Yellow -NoNewline
        Write-Host " failed logon attempts."

        Write-Host "As a result, a bad actor could attempt up to " -NoNewline
        Write-Host "$NoPS "  -ForegroundColor Yellow -NoNewline
        Write-Host "passwords per account in a password-spray attack before triggering account lockout.`n"
    }



    $MaxPwLenght = ($AllDomainsDetails | 
        Where-Object { $null -ne $_.MinPasswordLength } | 
        Measure-Object -Property MinPasswordLength -Maximum).Maximum

    Write-Host "The highest minimum password length configured across all domains in this forest is " -NoNewline
    Write-Host $MaxPwLenght -ForegroundColor $fgcH -NoNewline
    Write-Host " characters.`n"

    $DomainSearchBase = Set-AttackScope -Action "Password Spray"
    If ($DomainSearchBase -eq "SKIP") { return }

    $PasswordToTest = Get-ASConfig -Setting "LastPW"

    If (-not $UnAttended) {
        $title = "Confirm or change the password for the first password spray"
        $message = "The current password is:         $PasswordToTest"
        $Options = @(
            [pscustomobject] @{
                Label = "&Keep"
                Help  = "Keep the previous password '$PasswordToTest' for the last password spray."
                Value = $Script:Yes
            },
            [pscustomobject] @{
                Label = "&Change"
                Help  = "Enter a different password for the logon attempt."
                Value = "Change"
            }
        )

        $prompt = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
    

        if ($prompt -ne $Script:Yes) {
            do {
                $PasswordToTest = Read-Host "`n  Enter new password"
                if ([string]::IsNullOrWhiteSpace($PasswordToTest)) {
                    Write-AS2GoOutput -Type Warning -Message "Please enter at least $MaxPwLenght character!"
                }
            }
            while ([string]::IsNullOrWhiteSpace($PasswordToTest) -or $PasswordToTest.Length -lt [int]$MaxPwLenght)
            Set-ASConfig -Setting "LastPW" -Value $PasswordToTest
        }
    }


   
    If (-not $UnAttended) {
        
        $title = "Attack Phase - $($Script:Phase04.toupper()) - starts now ..."
        $message = "Also test each user's samAccountName as a potential password?"
        $Options = @(
            [pscustomobject] @{ 
                Label = "&Yes"
                Help  = "Two password attempts will be performed per user:`n    1. The configured password`n    2. The user's samAccountName"
                Value = $Script:Yes 
            },
            [pscustomobject] @{ 
                Label = "&No"
                Help  = "Only the configured password will be tested."
                Value = $Script:No 
            },
            [pscustomobject] @{ 
                Label = "&Cancel"
                Help  = "Cancel whole password spray."
                Value = "Skip"
            }
        )
        $decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    }
    else {
        $decision = $Script:Yes
    }

    If ($decision -eq $Script:Yes) {
        $IncludeSamAccountNameAsPassword = $true
    }
    elseif ($decision -eq $Script:No) {
        $IncludeSamAccountNameAsPassword = $false
    }
    else {
        Write-AS2GoOutput -Type Success -Message "Password Spray cancelled by user."
        return
    }
   

    If ($DomainSearchBase -eq "All Domains in Forest") {
        $domains = (Get-ADForest).Domains
        foreach ($domain in $domains) {
            $DomainSearchBase = (Get-ADDomain -Server $domain).DistinguishedName
            $runtime = Measure-Command {
                Start-PasswordSprayAttack -SearchBase $DomainSearchBase -Password $PasswordToTest -Server $domain -IncludeSamAccountNameAsPassword:$IncludeSamAccountNameAsPassword
            }
            Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
        }
    }
    else {
        $server = Get-BestDomainController -domain $DomainSearchBase
        $runtime = Measure-Command {
            Start-PasswordSprayAttack -SearchBase $DomainSearchBase -Password $PasswordToTest -Server $server -IncludeSamAccountNameAsPassword:$IncludeSamAccountNameAsPassword 
        }
        Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
    }



    If ($AS2GoDemo) {
        if (-not $UnAttended) {
            pause
        }
    }

    Measure-FunctionRuntime -End -Details $Info
}
