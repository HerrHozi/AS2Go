<#
.SYNOPSIS
Selects or keeps the account used as the MDI honeytoken.

.DESCRIPTION
Prompts the user to keep the configured honeytoken or select another account, then saves its
distinguished name in module settings.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Prompts for a honeytoken user, then stores the selected distinguished name.
#>
function Set-Honeytoken {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a Account which will be ignored during the AS2Go           #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header "Select a honeytoken account that will be monitored by MDI."
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    $previousDN = Get-ASConfig -Setting "Honeytoken"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the scope from previous selection/attack."
        $message = "Use current account ($previousCN) or select new:"
        Write-AS2GoOutput -Type TextMaker -Message "Current Honeytoken:" -Tm $previousCN
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
        Write-AS2GoOutput -Type TextMaker -Message "New Honeytoken:" -Tm $result
    }
    else {
        Write-AS2GoOutput -Type Info -message "Keep previous Honeytoken!"    
    }   

    Measure-FunctionRuntime -End -Details $Info
}