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

    $Info = Measure-FunctionRuntime -Begin

    $user = $Credential.UserName
    $pwd1 = $Credential.GetNetworkCredential().Password

    $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
    $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext(
        $contextType,
        $domain,
        $DomainController
    )

    Write-log -Message "    >> Check Login for '$domain\$user' against DC $DomainController"
    Measure-FunctionRuntime -End -Details $Info

    return $context.ValidateCredentials($user, $pwd1)
}

