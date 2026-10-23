function New-HoneytokenActivity {

    $Info = Measure-FunctionRuntime -Begin
    
    $Script:ASHoneyToken = Get-ASConfig -Setting "honeytoken"
    
    If ($script:ASHoneyToken -eq $null -or $script:ASHoneyToken -notlike "CN=*") {
        Write-Log -Message "No honeytoken configured. Skipping honeytoken activity."
        return
    }
    
    $randowmPW = Get-RandomPassword 


    Try {
        $HTSecurePass = ConvertTo-SecureString -String $randowmPW -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential $Script:ASHoneyToken, $HTSecurePass
        Get-ADUser -Filter * -Server $Script:ASDC -Credential $Credential
    }
    Catch {
        $cn = Convert-FromDNToCN -DistinguishedName $Script:ASHoneyToken
        Write-AS2GoOutput -Type Textmaker -Message "Honeytoken activity: Attempted to login and authenticate" -Tm "$cn"
    }
        
    Write-Log -Message "    >> Used $Script:ASHoneyToken with password $randowmPW"
    Measure-FunctionRuntime -End -Details $Info
}
