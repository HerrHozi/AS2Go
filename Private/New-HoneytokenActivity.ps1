function New-HoneytokenActivity {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    
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
        Write-Host "Created Honeytoken activity for $Script:ASHoneyToken | Attempted to login and authenticate" -ForegroundColor $Script:FGCHighLight
        Write-Log -Message "Created Honeytoken activity for $Script:ASHoneyToken"
    }
        
    Write-Log -Message "    >> Used $Script:ASHoneyToken with password $randowmPW"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
