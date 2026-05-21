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

        Invoke-Output -T Header -M "Privilege Escalation via Kerberoasting"

        $message = @"
This attack requests Kerberos service tickets for Service Principal Names (SPNs),
    allowing weak service account passwords to potentially be cracked offline
    and the associated credentials to be recovered.
"@
        Invoke-Output -T Bullet -M $message
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
