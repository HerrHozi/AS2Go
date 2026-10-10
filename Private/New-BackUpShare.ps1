<#
.SYNOPSIS
Creates the AS2Go sample backup share on a domain controller.

.FUNCTIONALITY
Creates the remote folder, grants Domain Admins modify access, and creates the SMB share.
#>
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

    try {
        Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
            
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
        
        $shares = Get-SmbShare -CimSession $Server -ErrorAction Stop | Where-Object { $_.Special -eq $false }
        $shares | Select-Object PSComputerName, Name, Path, Description | Out-Host

        $4logfile = $shares | Select-Object PSComputerName, Name, Path, Description | Out-String
        Write-Log -Message "    >> Identified the follwing shares: $4logfile"
    }
    catch {
        $errMsg = $_.Exception.Message
        if ($errMsg -match '(?i)access is denied|cannot connect to cim server|connecting to remote server .* failed') {
            throw "AS2GO_ACCESS_DENIED: Missing permissions for WinRM/CIM or share management on $Server. Use an account with local admin rights on the target DC."
        }

        throw
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}