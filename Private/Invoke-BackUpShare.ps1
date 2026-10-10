<#
.SYNOPSIS
Creates a domain controller share with sample AD backup files.

.FUNCTIONALITY
Selects the preferred DC and creates an AD-Backup share.
Copies and lists sample backup files, then saves the share path in module settings.
#>
function Invoke-BackUpShare {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to create and fill Share on Domain Controller       #####                              
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type Header -Message "Create a Share for 'fake' AD Backups on Domain Controller"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Invoke-Output -Type H1 -Message $Functionality

    $TargetServer = $Script:BestDCs[(Get-ADDomain).DNSRoot]

    Invoke-output -Type Bullet -Message "Target Domain Controller:" -TM $TargetServer
    try {
        New-BackUpShare -Server $TargetServer -ErrorAction Stop
        Copy-Item "$Script:ASSetup\ShareContent\*.*" -Destination "\\$TargetServer\AD-Backup" -Force -ErrorAction Stop
        Get-ChildItem -Path      "\\$TargetServer\AD-Backup" -ErrorAction Stop | Out-Host
        Invoke-Output -Type TextMaker -Message "Done - New Share is available" -TM  "\\$TargetServer\AD-Backup"
        Set-ASConfig -Setting "OfflineDITFile" -Value "\\$TargetServer\AD-Backup" -ErrorAction Stop
    }
    catch [System.UnauthorizedAccessException] {
        Invoke-Output -Type Error -Message "No permission to create or write backup share on $TargetServer. Use an account with local admin/share permissions."
    }
    catch {
        $errMsg = $_.Exception.Message
        if (
            $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::PermissionDenied -or
            $errMsg -match '(?i)AS2GO_ACCESS_DENIED|access is denied|cannot connect to cim server|connecting to remote server .* failed'
        ) {
            Invoke-Output -Type Error -Message "No permission to create or write backup share on $TargetServer. Use an account with local admin/share permissions."
        }
        else {
            Write-Error "Failed to create and fill the backup share on $TargetServer`: $($_.Exception.Message)"
        }
    }    


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}