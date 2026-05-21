function Get-UPNSuffix {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the best UPN Suffix best on custom UPN Suffix or root domain  #####                              
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $Domain 
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ([string]::IsNullOrEmpty($Domain)) {
        $domain = (Get-ADDomain).DNSRoot
    }

    $forest = Get-ADForest

    $suffixes = @()
    $Options = @()
    $usedHotkeys = @()

    if ($forest.UPNSuffixes) {
        $suffixes += $forest.UPNSuffixes
    }

    if ($forest.RootDomain -notin $suffixes) {
        $suffixes += $forest.RootDomain
    }

    if ($domain -notin $suffixes) {
        $suffixes += $domain 
    }

    $suffixes = $suffixes | Sort-Object -Unique

    foreach ($suffix in $suffixes) {

        if ($suffix.contains($($forest.RootDomain))) {
            $helpText = "Default UPN suffix for forest $($forest.RootDomain)."
        }
        else {
            $helpText = "Alternative UPN suffix configured in the forest."
        }

        $clean = $suffix -replace '[^a-zA-Z0-9]', ''
        $hotkey = $null

        foreach ($char in $clean.ToCharArray()) {
            $upper = $char.ToString().ToUpper()
            if ($upper -notin $usedHotkeys) {
                $hotkey = $upper
                $usedHotkeys += $upper
                break
            }
        }

        if (-not $hotkey) {
            $hotkey = ($Options.Count + 1).ToString()
        }

        $labelText = "@$suffix"
        $index = $labelText.ToUpper().IndexOf($hotkey)

        if ($index -ge 0) {
            $labelText = $labelText.Insert($index, "&")
        }

        $Options += [pscustomobject]@{
            Label = $labelText
            Help  = $helpText
            Value = "@$suffix"
        }
    }

    $Title = "Available UPN Suffixes in AD Forest $($forest.RootDomain)"
    $message = "Select the UPN namespace to append to newly created user accounts."
    $rootIndex = [array]::IndexOf($Options.Value, "@$($forest.RootDomain)")
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default $rootIndex -Title $Title

    Set-ASConfig -Setting "LastUPNSuffix" -Value $Decision

    Write-Log -Message "    >> Selectec UPN suffix $Decision"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $Decision
}