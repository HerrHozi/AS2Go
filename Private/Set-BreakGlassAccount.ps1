function Set-BreakGlassAccount {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a Account which will be ignored during the AS2Go           #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header "Define a Break Glass Account"
    Invoke-Output -Type H1 -Message "The break-glass account is excluded from all attack scenarios and is not considered in any attack path or risk evaluation."

    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the scope from previous selection/attack."
        $message = "Use current account ($previousCN) or select new:"
        Invoke-Output -Type TextMaker -Message "Current Break Glass Account:" -Tm $previousCN
    }
    else {
        $message = "Select new Break Glass Account:"
        $HelpP = $null
    }

    $Title = "Break Glass Account - Define Target Account"

    $Options = @(
        [pscustomobject] @{ Label = "&Previous Break Glass Account"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "&New Break Glass Account"; Help = "Choose a dedicated Break Glass Account."; Value = "New" }
    )
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "New") {
        $result = Select-ADObject -Title $Title -IncludeUsers -MarkTier0
        Set-ASConfig -Setting "BreakGlassAccount" -Value $result
        $result = Convert-FromDNToCN -DistinguishedName $result
        Invoke-Output -Type TextMaker -Message "New Break Glass Account:" -Tm $result
    }
    else {
        Invoke-Output -Type Info -message "Keep previous Break Glass Account!"    
    }   

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}