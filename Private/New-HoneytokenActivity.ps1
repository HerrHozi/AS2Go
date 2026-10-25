function New-HoneytokenActivity {

    $Info = Measure-FunctionRuntime -Begin
    
    $Script:ASHoneyToken = Get-ASConfig -Setting "honeytoken"
    
    If ($null -eq $script:ASHoneyToken -or $script:ASHoneyToken -notlike "CN=*") {
        Write-Log -Message "No honeytoken configured. Skipping honeytoken activity."
        return
    }
        
    Write-AS2GoOutput -Type Header -Message "Execute Honeytoken Activity"
    Write-AS2GoOutput -Type H1 -Message "Generated random password for honeytoken activity"
    $randowmPW = Get-RandomPassword

    Try {
        $HTSecurePass = ConvertTo-SecureString -String $randowmPW -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential $Script:ASHoneyToken, $HTSecurePass
        Get-ADUser -Filter * -Server $Script:ASDC -Credential $Credential
    }
    Catch {
        $cn = Convert-FromDNToCN -DistinguishedName $Script:ASHoneyToken
        Write-AS2GoOutput -Type Textmaker -Message "Attempted to login and authenticate for principal " -Tm "$cn"
    }
    Measure-FunctionRuntime -End -Details $Info
}
