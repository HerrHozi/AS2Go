<#
.SYNOPSIS
Selects the account to use as the certificate request's Subject Alternative Name.

.DESCRIPTION
Offers the previous target, another user, or a domain's built-in Administrator as the SAN
account. Stores the selected distinguished name in AS2Go settings and returns it.

.FUNCTIONALITY
Selects and stores a target account for the certificate request's Subject Alternative Name.

.COMPONENT
Category: Main Function
#>
function Set-AlternativeAccount {

    ################################################################################
    #####                                                                      ##### 
    #####    Define a Subject Alternative Name (SAN)                           #####                             
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header "Step 2 - Define a Subject Alternative Name (SAN)"
    Invoke-Output -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
  
    $previousDN = Get-ASConfig -Setting "LastAltUser"

    If ($previousDN -match '^CN=' ) {
        $previousCN = Convert-FromDNToCN -DistinguishedName $previousDN
        $HelpP = "Use the target account from previous selection."
        $message = "Use current account ($previousCN) or a select a different one:"
        Invoke-Output -Type TextMaker -Message "Current SAN Target Account:" -Tm $previousCN
    }
    else {
        $message = "Select new Alternative Account:"
        $HelpP = $null
    }

    $Title = "Subject Alternative Name (SAN) - Define Target Account"

    $Options = @(
        [pscustomobject] @{ Label = "&Previous Target Account"; Help = $HelpP ; Value = "Previous" },
        [pscustomobject] @{ Label = "&Change Target Account"; Help = "Choose a dedicated Alternative Account."; Value = "New" },
        [pscustomobject] @{ Label = "&Built-in Admin"; Help = "Choose a dedicated Domain."; Value = "BuiltInAdmin" }
    )
    $Decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $Title

    If ($Decision -eq "New") {
        $result = Select-ADObject -Title $Title -IncludeUsers -MarkTier0
        Set-ASConfig -Setting "LastAltUser" -Value $result
        $CN = Convert-FromDNToCN -DistinguishedName $result
        Invoke-Output -Type TextMaker -Message "New SAN Target Account:" -Tm $CN
    }
    elseif ($Decision -eq "BuiltInAdmin") {
        $dn = Select-ADObject -DomainSelectionOnly -Title "Select Domain for Built-in Admin"

        $domains = Get-DomainsInForest
        $domain = $domains | Where-Object { $_.DistinguishedName -eq $dn }
        $sid = $domain.domainSID + "-500"
        
        $details = Get-ADUserDetails -SearchBySID -Identifier $sid
      
        
        Set-ASConfig -Setting "LastAltUser" -Value $details.DN
        $CN = Convert-FromDNToCN -DistinguishedName $details.DN
        Invoke-Output -Type TextMaker -Message "Built-in Admin SAN Target Account from Domain:" -Tm $CN
        $result = $details.DN
    }
    else {
        Invoke-Output -Type Info -message "Keep previous SAN Target Account!" 
        $result = $previousDN   
    }   

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $result
}