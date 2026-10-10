<#
.SYNOPSIS
Runs extended Active Directory reconnaissance tasks.

.DESCRIPTION
Enumerates privileged group members, attempts a DNS zone transfer, and lists NetBIOS sessions
on the domain controller. The workflow also triggers honeytoken activity and supports attended
or unattended execution.

.FUNCTIONALITY
Enumerates privileged group members, attempts a DNS zone transfer, and lists DC NetBIOS sessions.
Triggers honeytoken activity as part of extended Active Directory reconnaissance.

.COMPONENT
Category: Main Function
#>
function Start-ReconnaissanceExtended {

    $Info = Measure-FunctionRuntime -Begin
    ####
    If (-not $SkipClearHost) { Clear-Host }
    

    If ($null -eq $Script:ASDC) {
        $Script:ASDC = Get-ASConfig -Setting "myDC" -ErrorAction SilentlyContinue
    }

    If ($null -eq $Script:ASFQDN) {
        $Script:ASFQDN = Get-ASConfig -Setting "fqdn"
    }


    Invoke-Output -Type  Header -M "TRY to enumerate 10 members of the '$($Script:GroupDNSA.samaccountname)' group"
 

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'$($Script:GroupDNSA.sid)' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupDNSA
    Write-Host ""
    Write-Host ""
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type  Header -M "TRY to enumerate 10 members of the '$($Script:GroupEA.samaccountname)' group"

    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'Enterprise Admins' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    
    #Write-Host " Get-ADGroupMember -Identity 'Enterprise Admins' -Recursive | ft" -ForegroundColor $Script:FGCCommand
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupEA
    Write-Host ""
    
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type  Header -Message "TRY to perform a domain zone transfer"
    Invoke-Output -Type H1 -Message "This step attempts to perform a domain zone transfer using nslookup.`n"

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
    Invoke-Output -Type  Header -Message "TRY to list NetBIOS sessions on Domain Controller"
    Invoke-Output -Type H1 -Message "This step attempts to list NetBIOS sessions on the domain controller using NetSess.exe.`n" 

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
    Measure-FunctionRuntime -End -Details $Info
}
