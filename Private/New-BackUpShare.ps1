function New-BackUpShare {

    ################################################################################
    #####                                                                      ##### 
    #####    Create Share on DC for fake Backups                               #####                          
    #####                                                                      #####
    ################################################################################

    Param([string] $Server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Command -ComputerName $Server  -ScriptBlock {
        
        $sharePath = "C:\temp\as2go"

        if (-not (Test-Path $sharePath)) {
            New-Item -Path $sharePath -ItemType Directory -Force | Out-Null
        }

        # Optional: grant permissions for Domain Admins
        $acl = Get-Acl $sharePath
        $permission = "Domain Admins", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $sharePath $acl

        if (-not (Get-SmbShare -Name "AD-Backup" -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name "AD-Backup" -Path $sharePath `
                -ChangeAccess "Domain Admins" `
                -Description "Needed for AS2Go"
        }
    }
    
    Get-SmbShare -CimSession $Server | Where-Object { $_.Special -eq $false } | Select-Object PSComputerName, Name, Path, Description | out-host

    $4logfile = Get-SmbShare -CimSession $Server | Where-Object { $_.Special -eq $false } | Select-Object PSComputerName, Name, Path, Description | Out-String
    Write-Log -Message "    >> Identified the follwing shares: $4logfile"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}