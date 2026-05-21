function New-TargetBase {

    ################################################################################
    #####                                                                      ##### 
    #####    Select a base based on OU, Domain or Forest                             
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $Title = "Define Target Base",
        [switch] $ExcludeForestLevel
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $previousDN = Get-KeyValue "PreviousBase"

    If ($previousDN -match 'OU=|CN=|DC=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the base from previous selection/attack."
        $message = "Use previous base ($previousCN) or select new:"

    }
    else {
        $message = "Select new target base:"
        $HelpP = $null
    }

    if ($ExcludeForestLevel) {
        $HelpF = $null
    }
    else {
        $HelpF = "The whole forest."
    }

    $Options = @(
        [pscustomobject] @{ Label = "&Previous Base"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "&OU Level"; Help = "Choose a OU or Domain."; Value = "OU" },
        [pscustomobject] @{ Label = "&Domain Level"; Help = "Choose a domain."; Value = "Domain" },
        [pscustomobject] @{ Label = "&Forest Level"; Help = $HelpF; Value = "Forest" },
        [pscustomobject] @{ Label = "&Current Domain"; Help = "Only in the current domain."; Value = "CurrentDomain" }
    )
        
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    $result = switch ($Decision) {
        "Previous" { $previousDN }
        "Forest" { (Get-ADForest).Domains }
        "Domain" { Select-ADObject -DomainSelectionOnly -Title $Title }
        "OU" { Select-ADObject -MarkTier0 -Title $Title }
        "CurrentDomain" { (Get-ADDomain).DistinguishedName }
        default { (Get-ADDomain).UsersContainer }
    }
   
    Set-ASConfig -Setting "PreviousBase" -Value  $result
    
    Write-Log -Message "    >> Selected base '$Decision' returns $result"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
}