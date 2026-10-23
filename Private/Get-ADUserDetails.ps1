function Get-ADUserDetails {

    ################################################################################
    #####                                                                      ##### 
    #####    Find AD User Details based on Identifier (SID or DN)              #####                               
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory)]
        [string]$Identifier,
        [switch]$SearchBySID,
        [switch]$SearchByDN   
    )

    $Info = Measure-FunctionRuntime -Begin

    If ($SearchBySID) {
    
        $sidObj = [System.Security.Principal.SecurityIdentifier]$Identifier
        $domainSid = $sidObj.AccountDomainSid.Value
        $ForestDomains = Get-DomainsInForest
        $Domain = $ForestDomains  | Where-Object { $_.DomainSID -eq $domainSid }
        $server = $Domain.FQDN
    }
    elseif ($SearchByDN) {

        $server = (($Identifier -split ',') |
            Where-Object { $_ -like 'DC=*' } |
            ForEach-Object { ($_ -split '=', 2)[1] }) -join '.'
    }
    else {
        Write-Log -Message "    >> No search method specified. Please use either -SearchBySID or -SearchByDN." -Level ERROR
        return
    }
    
    Try {
        $results = Get-ADUser -Identity $Identifier -Properties * -Server $server -ErrorAction stop
        $Details = [PSCustomObject]@{
            UPN            = $results.UserPrincipalName
            SID            = $results.objectSid.Value
            FQDN           = $results.CanonicalName.Split("/")[0]
            CN             = $results.CanonicalName
            samaccountname = $results.SamAccountName
            Enabled        = $results.Enabled
            DN             = $results.DistinguishedName
        } 
    }
    Catch {
        Write-Log -Message "    >> No user found for: $Identifier" -Level WARN
        $Details = [PSCustomObject]@{
            UPN            = "Account Not Found"
            SID            = "Account Not Found"
            FQDN           = "Account Not Found"
            CN             = "Account Not Found"
            samaccountname = "Account Not Found"
            DN             = $Identifier
        }
    }  

    Write-Log -Message "    >> Identified Account: $($Details.CN) based on identifier: $Identifier"
    Measure-FunctionRuntime -End -Details $Info
    return $Details
}