Function Get-SYSVOLGPOPerms
{
    param(
    [string]
	$execLogFilePath,
    [string]
    $scriptOutputPath,
    [string]
    $execName,
    [string]
    $execFilePath,
    [string]
    $Domain,
    [string]
    $dcToTarget,
    $tableOfADDomainsInADForest
    )

    $DomainDN = ($tableOfADDomainsInADForest | Where-Object{$_.DomainFQDN -eq $Domain}).DomainDN
    $sidADDomain = ($tableOfADDomainsInADForest | Where-Object{$_.DomainFQDN -eq $Domain}).DomainSID
	$sidRootADDomain = $($tableOfADDomainsInADForest | Where-Object { $_.IsRootDomain -eq "TRUE" }).DomainSID

	

	$policiesFolderOnSysvolShare = "\\$dcToTarget\SYSVOL\$Domain\Policies"


	$defaultGPTRightsCSV = @"
"FileSystemRights","AccessControlType","IdentityReference","IsInherited","InheritanceFlags","PropagationFlags"
"FullControl","Allow","S-1-3-0","False","ContainerInherit, ObjectInherit","InheritOnly"
"ReadAndExecute, Synchronize","Allow","S-1-5-9","False","ContainerInherit, ObjectInherit","None"
"ReadAndExecute, Synchronize","Allow","S-1-5-11","False","ContainerInherit, ObjectInherit","None"
"FullControl","Allow","S-1-5-18","False","ContainerInherit, ObjectInherit","None"
"FullControl","Allow","$sidADDomain-512","False","ContainerInherit, ObjectInherit","None"
"FullControl","Allow","$sidRootADDomain-519","False","ContainerInherit, ObjectInherit","None"
"268435456","Allow","S-1-3-0","False","ContainerInherit, ObjectInherit","InheritOnly"
"-1610612736","Allow","S-1-5-11","False","ContainerInherit, ObjectInherit","InheritOnly"
"ReadAndExecute, Synchronize","Allow","S-1-5-11","False","None","None"
"268435456","Allow","S-1-5-18","False","ContainerInherit, ObjectInherit","InheritOnly"
"FullControl","Allow","S-1-5-18","False","None","None"
"268435456","Allow","S-1-5-32-544","False","ContainerInherit, ObjectInherit","InheritOnly"
"Write, ReadAndExecute, ChangePermissions, TakeOwnership, Synchronize","Allow","S-1-5-32-544","False","None","None"
"-1610612736","Allow","S-1-5-32-549","False","ContainerInherit, ObjectInherit","InheritOnly"
"ReadAndExecute, Synchronize","Allow","S-1-5-32-549","False","None","None"
"Write, ReadAndExecute, Synchronize","Allow","$sidADDomain-512","False","None","None"
"-536870912","Allow","$sidADDomain-512","False","ContainerInherit, ObjectInherit","InheritOnly"
"@
	$defaultGPTRightsOBJ = $defaultGPTRightsCSV | ConvertFrom-Csv
	$builtInGroupsOnDCs = @{}
	$builtInGroupsOnDCs["S-1-5-32-544"] = "BUILTIN\Administrators"
	$builtInGroupsOnDCs["S-1-5-32-545"] = "BUILTIN\Users"
	$builtInGroupsOnDCs["S-1-5-32-546"] = "BUILTIN\Guests"
	$builtInGroupsOnDCs["S-1-5-32-547"] = "BUILTIN\Power Users"
	$builtInGroupsOnDCs["S-1-5-32-548"] = "BUILTIN\Account Operators"
	$builtInGroupsOnDCs["S-1-5-32-549"] = "BUILTIN\Server Operators"
	$builtInGroupsOnDCs["S-1-5-32-550"] = "BUILTIN\Print Operators"
	$builtInGroupsOnDCs["S-1-5-32-551"] = "BUILTIN\Backup Operators"
	$builtInGroupsOnDCs["S-1-5-32-552"] = "BUILTIN\Replicators"
	$builtInGroupsOnDCs["S-1-5-32-554"] = "BUILTIN\Pre-Windows 2000 Compatible Access"
	$builtInGroupsOnDCs["S-1-5-32-555"] = "BUILTIN\Remote Desktop Users"
	$builtInGroupsOnDCs["S-1-5-32-556"] = "BUILTIN\Network Configuration Operators"
	$builtInGroupsOnDCs["S-1-5-32-557"] = "BUILTIN\Incoming Forest Trust Builders"
	$builtInGroupsOnDCs["S-1-5-32-558"] = "BUILTIN\Performance Monitor Users"
	$builtInGroupsOnDCs["S-1-5-32-559"] = "BUILTIN\Performance Log Users"
	$builtInGroupsOnDCs["S-1-5-32-560"] = "BUILTIN\Windows Authorization Access Group"
	$builtInGroupsOnDCs["S-1-5-32-561"] = "BUILTIN\Terminal Server License Servers"
	$builtInGroupsOnDCs["S-1-5-32-562"] = "BUILTIN\Distributed COM Users"
	$builtInGroupsOnDCs["S-1-5-32-568"] = "BUILTIN\IIS_IUSRS"
	$builtInGroupsOnDCs["S-1-5-32-569"] = "BUILTIN\Cryptographic Operators"
	$builtInGroupsOnDCs["S-1-5-32-573"] = "BUILTIN\Event Log Readers"
	$builtInGroupsOnDCs["S-1-5-32-574"] = "BUILTIN\Certificate Service DCOM Access"
	$builtInGroupsOnDCs["S-1-5-32-575"] = "BUILTIN\RDS Remote Access Servers"
	$builtInGroupsOnDCs["S-1-5-32-576"] = "BUILTIN\RDS Endpoint Servers"
	$builtInGroupsOnDCs["S-1-5-32-577"] = "BUILTIN\RDS Management Servers"
	$builtInGroupsOnDCs["S-1-5-32-578"] = "BUILTIN\Hyper-V Administrators"
	$builtInGroupsOnDCs["S-1-5-32-579"] = "BUILTIN\Access Control Assistance Operators"
	$builtInGroupsOnDCs["S-1-5-32-580"] = "BUILTIN\Remote Management Users"

	$gpoFoldersInPoliciesFolder = Get-ChildItem -Path $policiesFolderOnSysvolShare -Directory -Force
	$gpoFolderAndPermissions = @()
	$gpoFoldersInPoliciesFolder | ForEach-Object {
		$folderFullPath = $null
		$folderFullPath = $_.FullName
		# WARNING: This Is Needed Like This As If There Is An Error On Individual Folders, Due To E.g. Permissions, Then It Will Only Fail On That Folder And NOT The Whole Process!

			$folderAcl = Get-Acl -Path $folderFullPath -ErrorAction Stop
			$folderAcl.Access | ForEach-Object {
				$matchDefaultPerms = $false
				$defaultPermsIndex = 0
				While ($defaultPermsIndex -le $($defaultGPTRightsOBJ | Measure-Object).count - 1) {
					If ($_.IdentityReference.Value -match "^S-1-") {
						# If A SID Is Displayed As An Identity Reference Because It CANNOT Be Resolved
						If (($_.FileSystemRights -eq $defaultGPTRightsOBJ[$defaultPermsIndex].FileSystemRights) -And ($_.AccessControlType -eq $defaultGPTRightsOBJ[$defaultPermsIndex].AccessControlType) -And ($_.IdentityReference.Value -eq $defaultGPTRightsOBJ[$defaultPermsIndex].IdentityReference) -And ($_.IsInherited.toString() -eq $defaultGPTRightsOBJ[$defaultPermsIndex].IsInherited) -And ($_.InheritanceFlags -eq $defaultGPTRightsOBJ[$defaultPermsIndex].InheritanceFlags) -And ($_.PropagationFlags -eq $defaultGPTRightsOBJ[$defaultPermsIndex].PropagationFlags)) {
							$matchDefaultPerms = $true
						}
					} Else {
						# If A SID Is Displayed As An Identity Reference Because It CAN Be Resolved
						If (($_.FileSystemRights -eq $defaultGPTRightsOBJ[$defaultPermsIndex].FileSystemRights) -And ($_.AccessControlType -eq $defaultGPTRightsOBJ[$defaultPermsIndex].AccessControlType) -And (($(New-Object System.Security.Principal.NTAccount($_.IdentityReference.Value)).Translate([System.Security.Principal.SecurityIdentifier])).Value -eq $defaultGPTRightsOBJ[$defaultPermsIndex].IdentityReference) -And ($_.IsInherited.toString() -eq $defaultGPTRightsOBJ[$defaultPermsIndex].IsInherited) -And ($_.InheritanceFlags -eq $defaultGPTRightsOBJ[$defaultPermsIndex].InheritanceFlags) -And ($_.PropagationFlags -eq $defaultGPTRightsOBJ[$defaultPermsIndex].PropagationFlags)) {
							$matchDefaultPerms = $true
						}
					}
					$defaultPermsIndex++
				}
                    
                $NTFSPermissionsString = $(if( $_.FileSystemRights.ToString() -match '^-?[0-9]+$'){Convert-FSPermission $_.FileSystemRights}else{$_.FileSystemRights})
                $folderAclProperties = [PSCustomObject][Ordered] @{
                'Path' = $folderFullPath;
                'Security Principal (SID)' = $(If ($_.IdentityReference.Value -match "^S-1-") {$_.IdentityReference.Value} Else {($(New-Object System.Security.Principal.NTAccount($_.IdentityReference.Value)).Translate([System.Security.Principal.SecurityIdentifier])).Value});
                'Security Principal (Name)' = $(If ($_.IdentityReference.Value -match "^S-1-") {"$($builtInGroupsOnDCs[$_.IdentityReference.Value]) "} Else {$_.IdentityReference.Value});
                'Owner' = $folderAcl.Owner ;
                'Access'=  $($_.AccessControlType);
                'Permission' = $NTFSPermissionsString ;
                'Apply To' =  $(Get-NTFSAppliesTo -InheritanceFlags $_.InheritanceFlags.ToString() -PropagationFlags $_.PropagationFlags.ToString() );
                'Inherited' = $($_.IsInherited); 
                'Default' = $matchDefaultPerms ;
                'Criticality Level' = $(Get-CriticalityLevel -CollectedPermissions $NTFSPermissionsString)}

				$gpoFolderAndPermissions += $folderAclProperties 
			}

	}

    if($gpoFolderAndPermissions)
    {
		$gpoFolderAndPermissions | Export-Csv $execLogFilePath -NoClobber -NoTypeInformation
    } else {
        [PSCustomObject]@{data = "... no data found ..."} | Export-Csv -Path $execLogFilePath -NoClobber -NoTypeInformation
    }


}