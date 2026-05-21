function New-UserManipulation {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
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
            Label = "&Cancel"
            Help  = "Cancel the entire account manipulation process."
            Value = "Skip"
        }
    )
    
    $Action = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    If ($Action -eq "Skip") { return }


    #[int]$NoLT = ($AllDomainsDetails | 
    #    Where-Object { $null -ne $_.LockoutThreshold -and $_.LockoutThreshold -gt 0 } | 
    #    Measure-Object -Property LockoutThreshold -Minimum).Minimum

    $DomainSearchBase = Set-AttackScope -Action "User Account Manipulation"
    If ($DomainSearchBase -eq "SKIP") { return }

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
                        Invoke-Output -Type Warning -Message "Please enter at least one character!"
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
                Start-UserManipulation -SearchBase $DomainSearchBase -NewPassword $NewRandomPW -Server $domain -Action $action
            }
            Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
        }
    }
    else {
        $server = Get-BestDomainController -domain $DomainSearchBase
        $runtime = Measure-Command {
            Start-UserManipulation -SearchBase $DomainSearchBase -NewPassword $NewRandomPW -Server $server -Action $action
        }
        Write-log -Message "Finished in $($runtime.TotalSeconds) seconds."
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}




