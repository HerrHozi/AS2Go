function Test-ADLogon {
    param(
        [Parameter(Mandatory)]
        [String]$domain,    
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory)]
        [string]$DomainController
    )

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $user = $Credential.UserName
    $pwd1 = $Credential.GetNetworkCredential().Password

    $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
        $contextType,
        $domain,
        $DomainController
    )

    Write-log -Message "    >> Check Login for '$domain\$user' against DC $DomainController"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $context.ValidateCredentials($user, $pwd1)
}

