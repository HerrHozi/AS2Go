function Set-UPNSuffix {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a UPNSuffix                                                #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $previousUPN = Get-ASConfig -Setting "LastUPNSuffix"

    If ($previousUPN.contains("@") ) {
        $HelpP = "Use the previous selection."
        $message = "Use current UPN suffix ($previousUPN) or select new:"
        #       Invoke-Output -Type TextMaker -Message "Current UPN suffix:" -Tm $previousUPN
    }
    else {
        $message = "Select new UPN suffix:"
        $HelpP = $null
    }

    $Title = "UPN suffix - Define Target Account"

    $Options = @(
        [pscustomobject] @{ Label = "&Previous UPN suffix"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "&New UPN suffix"; Help = "Choose a dedicated UPN suffix."; Value = "New" }
    )
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "New") {
        $result = Get-UPNSuffix
        Invoke-Output -Type TextMaker -Message "New UPN suffix:" -Tm $result
    }
    else {

        $result = $previousUPN
        Invoke-Output -Type Info -message "Keep previous UPN suffix!"    
    }   

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
    
}