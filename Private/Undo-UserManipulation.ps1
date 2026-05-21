function Undo-UserManipulation {

    param(
        [Parameter(Mandatory)]
        [string]$SearchBase,
        [Parameter(Mandatory)]
        [string]$Server,
        [Parameter(Mandatory)]
        [string]$TickValue,
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 10
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $users = Get-ADUser `
        -Filter "*" `
        -SearchBase $SearchBase `
        -Server $Server `
        -Properties CanonicalName, SID, adminDescription, whenChanged, pwdLastSet, enabled | 
    Where-Object { $_.adminDescription -eq $TickValue }

    $total = $users.Count
    if ($total -eq 0) {
        Invoke-Output -Type Warning -Message "No disabled users found for tick '$TickValue' under $SearchBase"
        return
    }
    else {
        $previewCount = [Math]::Min(20, $users.Count)
        $users | Get-Random -Count $previewCount |
        Select-Object SID, CanonicalName, Enabled, @{
            Name       = 'whenChanged'
            Expression = {
                if ($null -eq $_.whenChanged) {
                    'n/a'
                }
                else {
                    ([DateTime]$_.whenChanged).ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        }, @{
            Name       = 'pwdLastSet'
            Expression = {
                if ($null -eq $_.pwdLastSet -or [Int64]$_.pwdLastSet -le 0) {
                    'never'
                }
                else {
                    [DateTime]::FromFileTime([Int64]$_.pwdLastSet).ToString('yyyy-MM-dd HH:mm:ss')
                }
            }
        } | Format-Table | Out-Host
    }

    return

    
    $cname = Convert-FromDNToCN -DistinguishedName $SearchBase
    Invoke-Output -Type Quit -Message "Press 'Q' at any time to abort Undo User Manipulation`n      for '$total' users under '$cname' with tick '$TickValue'"

    $startTime = Get-Date

    # LDAP worker to re-enable user without ADWS dependency
    $undoWorker = {
        $dn = $_.DistinguishedName
        $sid = $_.SID.Value
        $canonical = $_.CanonicalName
        $srv = $using:Server

        $errorMsg = $null

        try {
            $entry = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$srv/$dn"
            $uac = [int]$entry.Properties["userAccountControl"].Value
            $entry.Properties["userAccountControl"].Value = ($uac -band (-bnot 2))
            $entry.CommitChanges()
            $entry.Dispose()
        }
        catch {
            $errorMsg = $_.Exception.InnerException.Message
            if ([string]::IsNullOrWhiteSpace($errorMsg)) {
                $errorMsg = $_.Exception.Message
            }
        }

        [PSCustomObject]@{
            User    = "$canonical ($sid)"
            Success = [string]::IsNullOrWhiteSpace($errorMsg)
            Errors  = $errorMsg
        }
    }

    $job = $users | ForEach-Object -Parallel $undoWorker -ThrottleLimit $ThrottleLimit -AsJob

    $allResults = [System.Collections.Generic.List[object]]::new()
    $processed = 0
    $progressTick = 0
    $pulseChars = @('|', '/', '-', '\\')

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

        $pulse = $pulseChars[$progressTick % $pulseChars.Count]
        $progressTick++

        $percent = [math]::Round(($processed / $total) * 100, 2)

        Write-Progress `
            -Activity "Undo User Manipulation (Enable users)" `
            -Status "$pulse Done: $processed/$total | $rate ops/s | ETA: $eta s | Throttle: $ThrottleLimit" `
            -PercentComplete $percent

        Start-Sleep -Milliseconds 250
    }

    $remainingResults = Receive-Job $job
    if ($null -ne $remainingResults) {
        foreach ($r in @($remainingResults)) { $allResults.Add($r) }
    }

    Remove-Job $job -Force
    Write-Progress -Activity "Undo User Manipulation (Enable users)" -Completed

    $succeeded = $allResults | Where-Object { $_.Success -eq $true }
    $failed = $allResults | Where-Object { $_.Success -eq $false }

    if ($succeeded) {
        Invoke-Output -Type TextMaker -Message "Successfully re-enabled $($succeeded.Count) users under $cname`:" -TM $($succeeded.Count)
    }

    if ($failed) {
        Invoke-Output -Type Warning -Message "$($failed.Count) user(s) failed to re-enable:"
        $failed | ForEach-Object {
            Invoke-Output -Type Bullet -Message "$($_.User): $($_.Errors)"
        }
    }

    Invoke-Output -Type Success -Message "Finished Undo User Manipulation for tick '$TickValue'."

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
