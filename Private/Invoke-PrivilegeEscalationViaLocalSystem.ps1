<#
.SYNOPSIS
Starts a selected PsExec session for a privilege-context demonstration.

.DESCRIPTION
Updates the saved lab stage and presents Local System, Help Desk, Domain Admin, and Skip choices.
Local System starts an interactive local pwsh.exe session using PsExec.
The Help Desk and Domain Admin options launch a local cmd.exe session with the configured account credentials.
Offers to repeat the selection after a command is started. Skip returns from the workflow.

.EXAMPLE
Invoke-PrivilegeEscalationViaLocalSystem
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires PsExec and the permissions or account credentials needed by the selected session.
No remote computer argument is supplied by this function.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Offers local PsExec sessions as Local System, the configured Help Desk user, or the configured Domain Admin.
Starts the selected PowerShell or command prompt session and offers to repeat the selection.
#>
function Invoke-PrivilegeEscalationViaLocalSystem {

    ################################################################################
    #####                                                                      ##### 
    #####    Start a process as a different user on the victim machine         #####                                
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle "PsExec Attack"
    Set-ASConfig -Setting "LastStage" -Value "PsExec Attack"

    Do {

        $domain = $env:USERDOMAIN

        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "Select your preferred PSExec Command"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)


        Write-Host "`nEnter " -NoNewline 
        Write-Host "H " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$Global:ASHelpDeskUser ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

        Write-Host "Enter " -NoNewline 
        Write-Host "D " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$Global:ASDomainAdmin ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

        Write-Host "Enter " -NoNewline 
        Write-Host "L " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-d -s -i ", "pwsh.exe") -Color $fgcC, $fgcS, $fgcV


        $title = "Privilege Escalation"
        $message = "Select the attack technique to execute."
        $Options = @(
            [pscustomobject] @{
                Label = "&Local System"
                Help  = "Run a PsExec attack to execute a command prompt with Local System privileges."
                Value = "LocalSystem"
            },
            [pscustomobject] @{
                Label = "&HelpDeskUser"
                Help  = "Run a PsExec attack to execute a command prompt with Help Desk User privileges."
                Value = "HelpDeskUser"
            },
            [pscustomobject] @{
                Label = "&Domain Admin"
                Help  = "Run a PsExec attack to execute a command prompt with Domain Admin privileges."
                Value = "DomainAdmin"
            },
            [pscustomobject] @{
                Label = "&Skip"
                Help  = "Skip Privilege Escalation."
                Value = "S"
            }
        )
        $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
                
        write-host "`n"
        If ($answer -eq "HelpDeskUser") {
            Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$Global:ASHelpDeskUser ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { & "$($Script:ASTools)\PsExec.exe" -u $domain\$Global:ASHelpDeskUser -d -h -i cmd.exe -nobanner } #| Out-Host

        }
        elseif ($answer -eq "LocalSystem") {
            Write-Highlight -Text (".\PSExec.exe ", "-d -s -i ", "pwsh.exe") -Color $fgcC, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { & "$($Script:ASTools)\PsExec.exe" -d -s -i pwsh.exe -nobanner } #| Out-Host

        }
        elseif ($answer -eq "DomainAdmin") {
            Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$Global:ASDomainAdmin ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { & "$($Script:ASTools)\PsExec.exe" -u $domain\$Global:ASDomainAdmin -d -h -i cmd.exe -nobanner } #| Out-Host

        }
        else {
            return
        }

        $title = "REPEAT | PSExec Command"
        $repeat = Show-DecisionPrompt -Default 1 -Title $title

    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $Info
}
