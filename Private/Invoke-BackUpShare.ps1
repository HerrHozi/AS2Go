<#
.SYNOPSIS
Prepares a domain controller share containing simulated AD backup data.

.DESCRIPTION
Uses the configured preferred controller for the current domain and creates the remote AD-Backup SMB share.
The helper creates C:\temp\as2go when needed and grants Domain Admins modify/change access.
Copies the lab ShareContent files into the share, displays its contents, and stores its UNC path as BackupShare.
Reports access-denied and other failures rather than proceeding as though share creation succeeded.

.EXAMPLE
Invoke-BackUpShare
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires PowerShell remoting, SMB access, initialized controller mappings, and the lab ShareContent directory.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Prepares the AD-Backup share on the configured DC and grants Domain Admins access.
Copies and lists sample backup files, then saves the share path for later data-access and exfiltration stages.
#>
function Invoke-BackUpShare {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to create and fill Share on Domain Controller       #####                              
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $Info.FunctionName

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Create a Share for 'fake' AD Backups on Domain Controller"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality


    $value = Get-ASConfig -Setting "BackupShare"
    Write-AS2GoOutput -Type TextMaker -Message "Current Backup Share:" -Tm $value

    If ($Script:Yes -ne $(Show-DecisionPrompt)) {
        Write-Log -Message "User chose not to proceed this operation"
        return
    }


    $server = Select-ADObject -Title "Select Domain Controller" -LocalDomainOnly -IncludeComputers

    If ($null -eq $server) {
        #$TargetServer = $Script:BestDCs[(Get-ADDomain).DNSRoot]
        Write-AS2GoOutput -Type Info -Message "Please select a computer"
        return
    }
    else {
        $CN = Convert-FromDNToCN $server
        $dnsdomain = $CN.split("/")[0]
        $computer = Get-ADComputer -Identity $server -Server $dnsdomain
        $TargetServer = $computer.DNSHostName
    }
 
    
    
    Write-Host
    Write-AS2GoOutput -Type Bullet -Message "Target Domain Controller:" -TM $TargetServer
    
    try {
        New-BackUpShare -Server $TargetServer -ErrorAction Stop

        get-childitem -Recurse | Add-Content "\\$TargetServer\AD-Backup\ntds.dit"
        Copy-Item "$Script:ASSetup\ShareContent\*.*" -Destination "\\$TargetServer\AD-Backup" -Force -ErrorAction Stop
        Get-ChildItem -Path      "\\$TargetServer\AD-Backup" -ErrorAction Stop | Out-Host
        Write-AS2GoOutput -Type TextMaker -Message "Done - New Share is available" -TM  "\\$TargetServer\AD-Backup"
        Set-ASConfig -Setting "BackupShare" -Value "\\$TargetServer\AD-Backup" -ErrorAction Stop
        Set-ASConfig -Setting "AS2GoAppServer" -Value $TargetServer
    }
    catch [System.UnauthorizedAccessException] {
        Write-AS2GoOutput -Type Error -Message "No permission to create or write backup share on $TargetServer. Use an account with local admin/share permissions."
    }
    catch {
        $errMsg = $_.Exception.Message
        if (
            $_.CategoryInfo.Category -eq [System.Management.Automation.ErrorCategory]::PermissionDenied -or
            $errMsg -match '(?i)AS2GO_ACCESS_DENIED|access is denied|cannot connect to cim server|connecting to remote server .* failed'
        ) {
            Write-AS2GoOutput -Type Error -Message "No permission to create or write backup share on $TargetServer. Use an account with local admin/share permissions."
        }
        else {
            Write-Error "Failed to create and fill the backup share on $TargetServer`: $($_.Exception.Message)"
        }
    }    


    Measure-FunctionRuntime -End -Details $Info
}