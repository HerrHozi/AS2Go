function Start-ReconnaissanceExtended {
    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    ####
    If (-not $SkipClearHost) { Clear-Host }
    

    If ($null -eq $Script:ASDC) {
        $Script:ASDC = Get-ASConfig -Setting "myDC" -ErrorAction SilentlyContinue
    }

    If ($null -eq $Script:ASFQDN) {
        $Script:ASFQDN = Get-ASConfig -Setting "fqdn"
    }


    Invoke-Output -T Header -M "TRY to enumerate 10 members of the '$($Script:GroupDNSA.samaccountname)' group"
 

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'$($Script:GroupDNSA.sid)' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupDNSA
    Write-Host ""
    Write-Host ""
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -T Header -M "TRY to enumerate 10 members of the '$($Script:GroupEA.samaccountname)' group"

    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'Enterprise Admins' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    
    #Write-Host " Get-ADGroupMember -Identity 'Enterprise Admins' -Recursive | ft" -ForegroundColor $Script:FGCCommand
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupEA
    Write-Host ""
    
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "      Open a new window to perform a domain zone transfer               "
    Write-Host "____________________________________________________________________`n" 
    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "nslookup | ", "ls ", "-d ", "$Script:ASFQDN" `
        -Color $fgcC, $fgcC, $fgcS, $fgcV
    Write-Host  ""

    try {
        Write-Output "ls -d $Script:ASFQDN" | Set-Clipboard
    }
    catch {
        Write-Output "ls -d $Script:ASFQDN" | clip
    }


    Start-Process nslookup
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-Host "____________________________________________________________________`n" 
    Write-Host "          TRY to list NetBIOS sessions on Domain Controller         "
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\NetSess.exe ", "$Script:ASDC" `
        -Color $fgcC, $fgcV
    Write-Host  ""
    Write-Host ""
    Get-SessionsOnDC -server $Script:ASDC
    Write-Host ""
    Write-Host ""

    ### hidden alert ####
    New-HoneytokenActivity
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    ####
    Write-Log -Message "### End Function $CurrentFunction ###"
}
