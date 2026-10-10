<#
.SYNOPSIS
Adds a deny access rule for a trustee on an organizational unit.

.DESCRIPTION
Applies an inherited DENY GenericAll access rule to the selected OU for the specified trustee,
then verifies the resulting permission state.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Applies and verifies an inherited DENY GenericAll ACE on the selected OU.
#>
function Set-DenyPermission {

    ################################################################################
    #####                                                                      ##### 
    #####    Set DENY Right for SG-AS2Go-Victims on TIER 0 Level               #####                           
    #####                                                                      #####
    ################################################################################

    Param([string]$TargetDN, [string]$Trustee, [string] $LogonServer)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type  Header -Message "Set DENY permission for $Trustee"

    $cname = Convert-FromDNToCN -DistinguishedName $TargetDN
    Invoke-Output -Type  TextMaker -M "on OU:" -Tm $cname

    # --- Get OU Security Descriptor from correct DC ---
    $OUObject = Get-ADObject `
        -Identity $TargetDN `
        -Server $LogonServer `
        -Properties nTSecurityDescriptor

    $acl = $OUObject.nTSecurityDescriptor

    $maxRetries = 5
    $trustee1 = $null

    for ($i = 1; $i -le $maxRetries; $i++) {
        write-log -Message "counter $i"
        $trustee1 = Get-ADGroup `
            -Filter "SamAccountName -eq '$Trustee'" `
            -Server $logonServer `
            -Properties SID

        if ($trustee1) { 
            $sid = [System.Security.Principal.SecurityIdentifier]$trustee1.SID
            $identity = [System.Security.Principal.IdentityReference]$sid
            break 
        }

        Start-Sleep -Seconds 2
    }

    if (-not $trustee1) {
        throw "Trustee '$Trustee' exists, but is not yet visible on DC '$logonServer'."
    }



    write-log -Message "    >> Adding DENY ACE for $Trustee (SID: $($sid.Value)) on OU '$TargetDN'"

    # --- DENY ACE ---
    $adRights = [System.DirectoryServices.ActiveDirectoryRights]::GenericAll
    $type = [System.Security.AccessControl.AccessControlType]::Deny
    $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($identity, $adRights, $type, $inheritanceType)
    $acl.AddAccessRule($ACE)

    Set-ADObject `
        -Identity $TargetDN `
        -Server $LogonServer `
        -Replace @{ nTSecurityDescriptor = $acl }
  
    # --- Get OU Security Descriptor from correct DC ---
    Start-Sleep 1 # Short delay to ensure changes are applied
    $OUObject = Get-ADObject `
        -Identity $TargetDN `
        -Server $LogonServer `
        -Properties nTSecurityDescriptor

    $acl = $OUObject.nTSecurityDescriptor
  
    $acl.Access | Where-Object { $_.IdentityReference -eq $identity.Value -or $_.IdentityReference -match $Trustee }  | 
    Select-Object @{N = 'SamAccountName'; E = { $Trustee } }, IdentityReference, AccessControlType, ActiveDirectoryRights, IsInherited | Format-Table | Out-Host

    $4logfile = $acl.Access | Where-Object { $_.IdentityReference -eq $identity.Value -or $_.IdentityReference -match $Trustee } | 
    Select-Object @{N = 'SamAccountName'; E = { $Trustee } }, IdentityReference, AccessControlType, ActiveDirectoryRights, IsInherited | Format-Table -AutoSize | Out-String
    Write-Log -Message "    >> New ACL Settings: $4logfile"

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}