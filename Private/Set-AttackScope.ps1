function Set-AttackScope {

    ################################################################################
    #####                                                                      ##### 
    #####    Select the scope OU, DOMAIN or Forest for the next action         #####                               
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory)]
        [string] $Action
    )

    $lastSelection = Get-ASConfig -Setting "MySearchBase"
   
    If ($UnAttended) {
        $DomainSearchBase = (get-Addomain).DistinguishedName
    }
    else {
        do {        
            
            $Options = @(
                [pscustomobject] @{ Label = "&Forest Level"; Help = "Entire Forest (all domains)."; Value = "Forest" },
                [pscustomobject] @{ Label = "&Domain Level"; Help = "Select specific domain."; Value = "D" },
                [pscustomobject] @{ Label = "&Current Domain"; Help = "Target only current domain (default)."; Value = "C" },
                [pscustomobject] @{ Label = "&OU Level"; Help = "Select specific organization unit."; Value = "OU" },
                [pscustomobject] @{ Label = "&Skip"; Help = "Skip this attack."; Value = "S" }
            )
            $title = "Define the attack scope for - $action!"
            $message = "Target scope:"
            $scope = Show-DecisionPrompt -Message $message  -Options $Options -Default 2 -Title $title

            If ($scope -eq "OU") {
                $Options = @(
                    [pscustomobject] @{ Label = "&Yes"; Help = "Yes."; Value = $Script:Yes },
                    [pscustomobject] @{ Label = "&No"; Help = "Select specific OU via OU picker."; Value = $Script:No }
                )
                $title = "Last selected search base: $lastSelection"
                $message = "Do you want to keep this search base?"
                $prompt = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

                if ($prompt -ne $Script:Yes) {
                
                    $result = Select-ADObject -Title "Choose Organization Unit!" -MarkTier0
                    If ($null -ne $result) {
                        $DomainSearchBase = $result
                    }
                }
                else {
                    $DomainSearchBase = $lastSelection
                }
            } 
            elseif ($scope -eq "D") {
                $prompt = $Script:No
                $DomainSearchBase = Select-ADObject -Title "Choose Domain" -DomainSelectionOnly

                If ($null -ne $resultxxx) {
                    $DomainSearchBase = $result
                    $cname = Convert-FromDNToCN -DistinguishedName $DomainSearchBase
                    Write-host
                    Invoke-Output -Type Bullet -Message "Scope updated to:" -TM $cname
                    $prompt = $Script:Yes
                }
            }
            elseif ($scope -eq "C") {
                $DomainSearchBase = (get-Addomain).DistinguishedName
            }
            elseif ($scope -eq "Forest") {
                $DomainSearchBase = "All Domains in Forest"
            }
            else {
                $DomainSearchBase = "SKIP"
            }
            
            If ($null -ne $DomainSearchBase) {
                $cname = Convert-FromDNToCN -DistinguishedName $DomainSearchBase
                Write-host
                Invoke-Output -Type Bullet -Message "Scope updated to:" -TM $cname

                $Options = @(
                    [pscustomobject] @{ Label = "&Proceed"; Help = "Yes."; Value = $Script:Yes },
                    [pscustomobject] @{ Label = "&Skip"; Help = "Yes."; Value = $Script:No },
                    [pscustomobject] @{ Label = "&Change Scope"; Help = "Select specific OU via OU picker."; Value = "NewScope" }
                )
                $prompt = Show-DecisionPrompt -Options $Options
                If ($prompt -eq $Script:No) { $DomainSearchBase = "SKIP"}
            }
        } Until ($prompt -eq $Script:Yes)
    }
    Set-ASConfig -Setting "MySearchBase" -Value $DomainSearchBase
    
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $DomainSearchBase
}