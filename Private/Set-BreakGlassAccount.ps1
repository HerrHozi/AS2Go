<#
.SYNOPSIS
Selects or keeps the lab's break-glass account.

.DESCRIPTION
Selects or keeps the lab's break-glass account. 
This account is excluded from all attack scenarios and is not considered in any attack path or risk evaluation.

.FUNCTIONALITY
Stores the selected account DN so the account can be excluded from attack scenarios.

.COMPONENT
Category: Main Function
#>
function Set-BreakGlassAccount {

    $Info = Measure-FunctionRuntime -Begin
    Write-AS2GoOutput -Type Header -Message "Define a Break Glass Account"
    Write-AS2GoOutput -Type H1 -Message $((get-help (Get-FunctionName)).Functionality)

   
    $previousDN = Get-ASConfig -Setting "BreakGlassAccount"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the scope from previous selection/attack."
        $message = "Use current account ($previousCN) or select new:"
        Write-AS2GoOutput -Type TextMaker -Message "Current Break Glass Account:" -Tm $previousCN
    }
    else {
        $message = "Select new Break Glass Account:"
        $HelpP = $null
    }

    $Title = "Break Glass Account - Define Target Account"

    $Options = @(
        [pscustomobject] @{ Label = "&Previous Break Glass Account"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "Select &new Break Glass Account"; Help = "Choose a dedicated Break Glass Account."; Value = "New" },
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip selecting a Break Glass Account."; Value = "Skip" }
    )
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "New") {
        $result = Select-ADObject -Title $Title -IncludeUsers -MarkTier0
        Set-ASConfig -Setting "BreakGlassAccount" -Value $result
        $result = Convert-FromDNToCN -DistinguishedName $result
        Write-AS2GoOutput -Type TextMaker -Message "New Break Glass Account:" -Tm $result
    }
    elseif ($Decision -eq "Previous") {
        Write-AS2GoOutput -Type Info -message "Keep previous Break Glass Account!"    
    }
    else {
        Write-AS2GoOutput -Type Info -message "Skipping Break Glass Account selection!"
    }
    #end main code
    
    Measure-FunctionRuntime -End -Details $Info 
}