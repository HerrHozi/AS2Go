<#
.SYNOPSIS
Demonstrates additional reconnaissance and honeytoken authentication activity.

.DESCRIPTION
Enumerates DNSAdmins and Enterprise Admins memberships using configured group information.
Copies an ls -d domain command to the clipboard and opens nslookup for the user to perform a DNS zone transfer.
Runs NetSess against the configured DC and attempts an AD query with the selected honeytoken and a random password.
Attended mode pauses between steps; unattended mode uses timed delays but does not enter commands into nslookup.

.EXAMPLE
Invoke-ReconnaissanceExtended
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires initialized privileged-group and honeytoken settings, NetSess, and access to the configured DC.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Enumerates DNSAdmins and Enterprise Admins, opens nslookup for a manual zone transfer, and lists DC NetBIOS sessions.
Attempts a honeytoken-authenticated AD query with a random password to demonstrate detection activity.
#>
function Invoke-ReconnaissanceExtended {

    $Info = Measure-FunctionRuntime -Begin
    ####
    If (-not $SkipClearHost) { Clear-Host }
    

    If ($null -eq $Script:ASDC) {
        $Script:ASDC = Get-ASConfig -Setting "myDC" -ErrorAction SilentlyContinue
    }

    If ($null -eq $Script:ASFQDN) {
        $Script:ASFQDN = Get-ASConfig -Setting "fqdn"
    }


    Write-AS2GoOutput -Type  Header -M "TRY to enumerate 10 members of the '$($Script:GroupDNSA.samaccountname)' group"
 

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'$($Script:GroupDNSA.sid)' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupDNSA
    Write-Host ""
    Write-Host ""
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -M "TRY to enumerate 10 members of the '$($Script:GroupEA.samaccountname)' group"

    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'Enterprise Admins' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    
    #Write-Host " Get-ADGroupMember -Identity 'Enterprise Admins' -Recursive | ft" -ForegroundColor $Script:FGCCommand
    Write-Host ""
    Get-PriviledgeGroupMember -group $Script:GroupEA
    Write-Host ""
    
    
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type  Header -Message "TRY to perform a domain zone transfer"
    Write-AS2GoOutput -Type H1 -Message "This step attempts to perform a domain zone transfer using nslookup.`n"

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
    Write-AS2GoOutput -Type  Header -Message "TRY to list NetBIOS sessions on Domain Controller"
    Write-AS2GoOutput -Type H1 -Message "This step attempts to list NetBIOS sessions on the domain controller using NetSess.exe.`n" 

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
