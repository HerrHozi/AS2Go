function Set-HoneyToken {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a Account which will be ignored during the AS2Go           #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header "Select a honeytoken account that will be monitored by MDI."
    Invoke-Output -Type H1 -Message "Microsoft Defender for Identity (MDI) honeytokens are decoy accounts tagged to trigger immediate alerts on any authentication attempt, `nserving as early warning traps for attackers targeting Active Directory credentials."

    $previousDN = Get-ASConfig -Setting "Honeytoken"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the scope from previous selection/attack."
        $message = "Use current account ($previousCN) or select new:"
        Invoke-Output -Type TextMaker -Message "Current Honeytoken:" -Tm $previousCN
    }
    else {
        $message = "Select new Honeytoken:"
        $HelpP = $null
    }

    $Title = "Honeytoken - Define Target Account"

    $Options = @(
        [pscustomobject] @{ Label = "&Previous Honeytoken"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "&New Honeytoken"; Help = "Choose a dedicated Honeytoken."; Value = "New" }
    )
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "New") {
        $result = Select-ADObject -Title $Title -IncludeUsers -MarkTier0
        Set-ASConfig -Setting "Honeytoken" -Value $result
        $result = Convert-FromDNToCN -DistinguishedName $result
        Invoke-Output -Type TextMaker -Message "New Honeytoken:" -Tm $result
    }
    else {
        Invoke-Output -Type Info -message "Keep previous Honeytoken!"    
    }   

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}