<#
.SYNOPSIS
Runs the Kerberoasting attack workflow for the current AS2Go stage.

.DESCRIPTION
Sets the Kerberoasting stage, explains the service-ticket attack, and calls the attack routine.
In attended mode, prompts the user to repeat the workflow.

.FUNCTIONALITY
This attack requests Kerberos service tickets for Service Principal Names (SPNs),
allowing weak service account passwords to potentially be cracked offline
and the associated credentials to be recovered.

.COMPONENT
Category: Main Function
#>
function Invoke-KerberoastingAttack {

    ################################################################################
    #####                                                                      ##### 
    #####    Prepare for new Kerberoasting Attack.                             #####
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    Update-WindowTitle -NewTitle $Script:Phase27
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase27
    #Show-Phases -Phase "phase_007.html"
    Do {

        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type  Header -M "Privilege Escalation via Kerberoasting"
        Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        Start-KerberoastingAttack    

        #If (-not $SkipClearHost) { Clear-Host }


        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
        $title = "REPEAT | Privilege Escalation - Kerberoasting Attack"
        $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }

    } Until ($repeat -eq $Script:No)

    Write-Log -Message "    >> using $CAtemplate"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    #
}
