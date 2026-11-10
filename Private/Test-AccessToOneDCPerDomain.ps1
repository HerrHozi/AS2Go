function Test-AccessToOneDCPerDomain {

    $info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Attempting to access a domain controller's C$ share in each domain"

    $script:AccessToDC = @()
    Foreach ($domain in  (Get-ADForest).domains) {
        $DC = Get-BestDomainController -Domain $domain
        $directory = "\\$DC\c$"
        Get-DirContent -Path $directory
    }
   

    If ($script:AccessToDC.Count -eq 0) {
        Write-AS2GoOutput -Type Bad -Message "No access to any domain controller's C$ share.`n"
    }
    else {
        Write-AS2GoOutput -Type TOP -Message "Domains with successful DC access: $($script:AccessToDC.Count)/$((Get-ADForest).domains.Count) | Tested DC's:`n"
        foreach ($access in $script:AccessToDC) {
            Write-AS2GoOutput -Type Bullet -Message "Accessed path $access successfully!"
        }
    }

    Measure-FunctionRuntime -End -Details $info

}