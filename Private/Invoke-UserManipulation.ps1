<#
.SYNOPSIS
Disables AD users, resets their passwords, or performs both operations.

.DESCRIPTION
Selects enabled users for Disable and all users in the search base for other actions.
Runs LDAP DirectoryEntry operations in parallel to disable accounts, reset passwords, or perform both.
Each successful change writes TickValue to adminDescription. A missing NewPassword is replaced with a random password.
Displays progress, DC CPU and LDAP timing when available, and per-user success or error messages.
Q can stop processing. This low-level function does not exclude backdoor or break-glass accounts.

.PARAMETER SearchBase
Distinguished name of the OU or domain subtree containing the target users.

.PARAMETER Server
AD server used for user enumeration and LDAP changes; also queried for progress metrics.

.PARAMETER NewPassword
Plain-text replacement password for PwReset or Both. A random password is generated when omitted or blank.

.PARAMETER Action
Operation to perform: Disable, PwReset, or Both, matched without case sensitivity. Other values do not change accounts.

.PARAMETER TickValue
Value written to adminDescription after a successful change. Defaults to the current time as yyyy-MM-dd HH:mm:ss.

.PARAMETER ThrottleLimit
Maximum concurrent account-processing operations, from 1 through 100. Defaults to 5.

.EXAMPLE
Invoke-UserManipulation -SearchBase "OU=Demo Accounts,OU=AS2Go,DC=example,DC=com" -Server "DC01.example.com" -Action Disable
Disables enabled users in the selected demo-account OU and marks successful changes.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires permission to change the target users. No protected-account exclusions are applied in this function.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Disables users, resets passwords, or both in the specified AD search base, without protected-account exclusions.
Marks changed accounts in adminDescription and reports results, progress, and available DC metrics.
#>
function Invoke-UserManipulation {

    ################################################################################
    ######                                                                     #####
    ######    Bulk-manipulate AD users in parallel:                            #####
    ######      1. Reset password                                              #####
    ######      2. Disable account                                             #####
    ######      3. Write tick value to adminDescription                        #####
    ######                                                                     #####
    ################################################################################

    param(
        [Parameter(Mandatory)]
        [string]$SearchBase,
        [Parameter(Mandatory)]
        [string]$Server,
        [string]$NewPassword,           # auto-generated if omitted
        [string]$Action,
        [string]$TickValue = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 5
    )

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Invoke-UserManipulation"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Show-CurrentPhase -Phase  "https://cymulate.com/cybersecurity-glossary"   

    # Auto-generate password if none given
    if ([string]::IsNullOrWhiteSpace($NewPassword)) {
        $NewPassword = Get-RandomPassword
    }

    if ($Action -match "^Disable$") {
        $users = Get-ADUser `
            -Filter "Enabled -eq 'True'" `
            -SearchBase $SearchBase `
            -Server $Server `
            -Properties SamAccountName, SID

        $total = $users.Count

        if ($total -eq 0) {
            Write-AS2GoOutput -Type Warning -Message "No enabled users found under $SearchBase"
            return
        }
    }
    else {
        $users = Get-ADUser `
            -Filter "*" `
            -SearchBase $SearchBase `
            -Server $Server `
            -Properties SamAccountName, SID

        $total = $users.Count
    }

    $cname = Convert-FromDNToCN -DistinguishedName $SearchBase
    Write-AS2GoOutput -Type Quit -Message "Press 'Q' at any time to abort User Manipulation`n      for '$total' users under '$cname'!`n      Password: '$NewPassword' | Tick: '$TickValue'"

    $startTime = Get-Date

    # ---- PARALLEL WORKER ----
    # Uses DirectoryServices.DirectoryEntry (raw LDAP on port 389) instead of the AD module.
    # This completely avoids ADWS and its connection pool limit — the root cause of
    # the "transient condition" error under parallel load.
    $manipulateWorker = {

        $dn = $_.DistinguishedName
        $sid = $_.SID.Value
        $sam = $_.SamAccountName
        $srv = $using:Server
        $pw = $using:NewPassword
        $tick = $using:TickValue
        $Manipulation = $using:Action

        $errors = [System.Collections.Generic.List[string]]::new()

        try {
            $entry = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$srv/$dn"

            # 1. Reset password via LDAP SetPassword
            If ($Manipulation -match "^PwReset$|^Both$") {
            
                try {
                    $entry.Invoke("SetPassword", $pw)
                    $entry.Properties["adminDescription"].Value = $tick
                    $entry.CommitChanges()
                }
                catch { 
                    $errors.Add("PwReset: $($_.Exception.InnerException.Message ?? $_.Exception.Message)") 
                }
            }

            # 2+3. Disable account + write tick in a single LDAP roundtrip
            If ($Manipulation -match "^Disable$|^Both$") {
                try {
                    $uac = [int]$entry.Properties["userAccountControl"].Value
                    $entry.Properties["userAccountControl"].Value = $uac -bor 2
                    $entry.Properties["adminDescription"].Value = $tick
                    $entry.CommitChanges()
                }
                catch { 
                    $errors.Add("Disable+AdminDesc: $($_.Exception.InnerException.Message ?? $_.Exception.Message)") 
                }
            }
            $entry.Dispose()
        }
        catch {
            $errors.Add("LDAPConnect: $($_.Exception.Message)")
        }

        [PSCustomObject]@{
            User    = "$sam ($sid)"
            Success = ($errors.Count -eq 0)
            Errors  = ($errors -join " | ")
        }
    }

    # ---- PARALLEL JOB ----
    $job = $users | ForEach-Object -Parallel $manipulateWorker -ThrottleLimit $ThrottleLimit -AsJob

    $allResults = [System.Collections.Generic.List[object]]::new()
    $processed = 0
    $metricsRefreshEverySeconds = 3
    $lastMetricsTime = [DateTime]::MinValue   # force immediate first poll
    $lastValidCpu = $null
    $metricsJob = $null
    $progressTick = 0
    $pulseChars = @('|', '/', '-', '\\')
    $metrics = [PSCustomObject]@{ CPU = 'n/a'; LDAP = 'n/a' }

    # Metrics worker runs as background job — never blocks the monitor loop
    $metricsWorker = {
        param($srv)
        $cpu = 'n/a'
        try {
            $c = (Get-Counter -ComputerName $srv '\Processor(_Total)\% Processor Time' -MaxSamples 1 -ErrorAction Stop).CounterSamples[0].CookedValue
            $cpu = [math]::Round($c, 1)
        }
        catch {
            try {
                $s = Get-CimInstance -ClassName Win32_Processor -ComputerName $srv -OperationTimeoutSec 3 -ErrorAction Stop |
                Select-Object -ExpandProperty LoadPercentage
                if ($s) { $cpu = [math]::Round(($s | Measure-Object -Average).Average, 1) }
            }
            catch {}
        }
        $lat = 'n/a'
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $d = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$srv/RootDSE")
            $null = $d.Properties["defaultNamingContext"].Value
            $sw.Stop()
            $lat = $sw.ElapsedMilliseconds
        }
        catch {}
        [pscustomobject]@{ CPU = $cpu; LDAP = $lat }
    }

    # ---- MONITOR LOOP ----
    while ($job.State -eq "Running") {

        if ([Console]::KeyAvailable) {
            if ([Console]::ReadKey($true).Key -eq 'Q') {
                Stop-Job $job
                break
            }
        }

        $newResults = Receive-Job $job
        if ($null -ne $newResults) {
            foreach ($r in @($newResults)) { $allResults.Add($r) }
        }
        $processed = $allResults.Count

        $elapsed = (Get-Date) - $startTime
        $rate = if ($elapsed.TotalSeconds -gt 0) {
            [math]::Round($processed / $elapsed.TotalSeconds, 2)
        }
        else { 0 }

        $eta = if ($rate -gt 0) {
            [math]::Round(($total - $processed) / $rate, 1)
        }
        else { 0 }

        # Non-blocking async metrics
        if ($null -ne $metricsJob) {
            if ($metricsJob.State -ne 'Running') {
                $fresh = Receive-Job $metricsJob
                Remove-Job $metricsJob -Force
                $metricsJob = $null
                if ($null -ne $fresh) {
                    if ($fresh.CPU -is [ValueType]) { $lastValidCpu = $fresh.CPU }
                    $metrics = [PSCustomObject]@{
                        CPU  = if ($null -ne $lastValidCpu) { $lastValidCpu } else { $fresh.CPU }
                        LDAP = $fresh.LDAP
                    }
                }
            }
            elseif (((Get-Date) - $lastMetricsTime).TotalSeconds -gt 5) {
                Stop-Job $metricsJob
                Remove-Job $metricsJob -Force
                $metricsJob = $null
            }
        }
        if (($null -eq $metricsJob) -and (((Get-Date) - $lastMetricsTime).TotalSeconds -ge $metricsRefreshEverySeconds)) {
            $metricsJob = Start-Job -ScriptBlock $metricsWorker -ArgumentList $Server
            $lastMetricsTime = Get-Date
        }

        $pulse = $pulseChars[$progressTick % $pulseChars.Count]
        $progressTick++
        $cpuStatus = if ($metrics.CPU -is [ValueType]) { "$($metrics.CPU)%" } else { $metrics.CPU }
        $ldapStatus = if ($metrics.LDAP -is [ValueType]) { "$($metrics.LDAP)ms" } else { $metrics.LDAP }
        $percent = [math]::Round(($processed / $total) * 100, 2)

        Write-Progress `
            -Activity "Performing User Manipulation (PwReset + Disable + AdminDesc)" `
            -Status "$pulse Done: $processed/$total | $rate ops/s | ETA: $eta s | Throttle: $ThrottleLimit | DC CPU: $cpuStatus | LDAP: $ldapStatus" `
            -PercentComplete $percent

        Start-Sleep -Milliseconds 250
    }

    # Cleanup metrics job
    if ($null -ne $metricsJob) {
        Stop-Job $metricsJob -ErrorAction SilentlyContinue
        Remove-Job $metricsJob -Force -ErrorAction SilentlyContinue
    }

    # Collect remaining results
    $remainingResults = Receive-Job $job
    if ($null -ne $remainingResults) {
        foreach ($r in @($remainingResults)) { $allResults.Add($r) }
    }
    Remove-Job $job -Force
    Write-Progress -Activity "Performing User Manipulation (PwReset + Disable + AdminDesc)" -Completed

    # ---- RESULTS ----
    $succeeded = $allResults | Where-Object { $_.Success -eq $true }
    $failed = $allResults | Where-Object { $_.Success -eq $false }

    if ($succeeded) {
        Write-AS2GoOutput -Type TextMaker -Message "Successfully manipulated user accounts in the selected scope: $cname | " -TM "Total: $($succeeded.Count)"
    }

    #Undo-UserManipulation -TickValue $TickValue -Server $server -SearchBase $SearchBase

    if ($failed) {
        Write-AS2GoOutput -Type Warning -Message "$($failed.Count) user(s) had errors:"
        $failed | ForEach-Object {
            Write-AS2GoOutput -Type Bullet -Message "$($_.User): $($_.Errors)"
        }
    }

    Write-AS2GoOutput -Type Success -Message "Completed user account manipulation for the current scope (see examples above)."
    Write-Log -Message "    >> Password used: $NewPassword"
    Write-Log -Message "    >> TickValue: $TickValue"
    Measure-FunctionRuntime -End -Details $Info
}
