<#
.SYNOPSIS
Selects the UPN suffix for new demo accounts.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Keeps the saved suffix or prompts for a new one and returns the selected value.
#>
function Set-UPNSuffix {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a UPNSuffix                                                #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    $previousUPN = Get-ASConfig -Setting "LastUPNSuffix"

    If ($previousUPN.contains("@") ) {
        $HelpP = "Use the previous selection."
        $message = "Use current UPN suffix ($previousUPN) or select new:"
        #       Write-AS2GoOutput -Type TextMaker -Message "Current UPN suffix:" -Tm $previousUPN
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
        Write-AS2GoOutput -Type TextMaker -Message "New UPN suffix:" -Tm $result
    }
    else {

        $result = $previousUPN
        Write-AS2GoOutput -Type Info -message "Keep previous UPN suffix!"    
    }   

    Measure-FunctionRuntime -End -Details $Info

    return $result
    
}