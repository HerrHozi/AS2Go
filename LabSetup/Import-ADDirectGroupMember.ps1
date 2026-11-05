#Requires -Version 5.1
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
Restores direct group memberships from an Export-ADDirectGroupMember JSON file.
.DESCRIPTION
Adds missing member DNs to the original groups without removing existing members.
Validates the forest and domain SIDs before writing. Groups are resolved by SID.
Uses only the export JSON; no AS2Go configuration file is required.
Member objects must still exist at their exported DNs; objects are not created or remapped.
Each attempted addition produces a result. Failed additions cause a terminating error at the end.
.PARAMETER Path
JSON file created by Export-ADDirectGroupMember.ps1.
.PARAMETER Silent
Suppresses diagnostic messages and result objects. Errors and confirmation/WhatIf prompts remain visible.
.EXAMPLE
.\Import-ADDirectGroupMember.ps1 -Path C:\Temp\ADGroupMembers.json -WhatIf
.EXAMPLE
.\Import-ADDirectGroupMember.ps1 -Path C:\Temp\ADGroupMembers.json
.FUNCTIONALITY
Restores missing direct memberships from JSON in the original forest without removing existing members.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [switch]$Silent
)

$ErrorActionPreference = 'Stop'
if ($Silent) {
    $WarningPreference = 'SilentlyContinue'
    $VerbosePreference = 'SilentlyContinue'
    $DebugPreference = 'SilentlyContinue'
    $InformationPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'
}
$Data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
if ($Data.SchemaVersion -ne 1 -or $Data.MembershipType -ne 'DirectMemberAttribute' -or
    -not $Data.Forest -or -not @($Data.Domains).Count) {
    throw 'Unsupported or incomplete group membership JSON.'
}

$Forest = Get-ADForest -Identity $Data.Forest
$Targets = @(
    # Validate every domain and group record before making any changes.
    foreach ($DomainRecord in $Data.Domains) {
        if ($DomainRecord.Domain -notin $Forest.Domains) {
            throw "Domain $($DomainRecord.Domain) is not in forest $($Forest.Name)."
        }
        $Domain = Get-ADDomain -Identity $DomainRecord.Domain -Server $DomainRecord.Domain
        if ($Domain.DomainSID.Value -ne $DomainRecord.DomainSid) {
            throw "Domain SID mismatch for $($DomainRecord.Domain)."
        }
        $DomainController = Get-ADDomainController -Discover -DomainName $DomainRecord.Domain -Writable
        $Server = [string](@($DomainController.HostName)[0])
        if ([string]::IsNullOrWhiteSpace($Server)) {
            throw "No domain controller hostname was returned for $($DomainRecord.Domain)."
        }
        foreach ($GroupRecord in $DomainRecord.Groups) {
            $ParsedRid = [uint32]0
            if (-not [uint32]::TryParse([string]$GroupRecord.Rid, [ref]$ParsedRid) -or
                $ParsedRid -eq 0 -or $GroupRecord.Status -notin 'Exported', 'Missing') {
                throw "Invalid group record in $($DomainRecord.Domain)."
            }
            $ExpectedSid = if ($GroupRecord.Rid -in 548, 549, 550, 551) {
                "S-1-5-32-$($GroupRecord.Rid)"
            }
            else { "$($Domain.DomainSID.Value)-$($GroupRecord.Rid)" }
            if ($GroupRecord.Sid -ne $ExpectedSid) { throw "Unexpected group SID: $($GroupRecord.Sid)." }
            if ($GroupRecord.Status -eq 'Missing') { continue }
            if ($null -eq $GroupRecord.Members -or $GroupRecord.Members -isnot [System.Array]) {
                throw "Missing or invalid member array for $ExpectedSid."
            }
            foreach ($MemberDn in $GroupRecord.Members) {
                if ($MemberDn -isnot [string] -or [string]::IsNullOrWhiteSpace($MemberDn)) {
                    throw "Invalid member DN for $ExpectedSid."
                }
            }
            $Group = Get-ADGroup -Identity $ExpectedSid -Server $Server -Properties member
            [pscustomobject]@{
                Domain = $DomainRecord.Domain
                Server = $Server
                Group = $Group
                Members = $GroupRecord.Members
            }
        }
    }
)

$FailureCount = 0
foreach ($Target in $Targets) {
    $ExistingMembers = @($Target.Group.member)
    foreach ($MemberDn in ($Target.Members | Sort-Object -Unique)) {
        $Status = 'AlreadyMember'
        $ErrorMessage = $null
        if ($MemberDn -notin $ExistingMembers) {
            $Status = 'Skipped'
            if ($PSCmdlet.ShouldProcess("$($Target.Domain): $($Target.Group.Name)", "Add direct member $MemberDn")) {
                try {
                    # Use a typed string array: AD attribute hashtables do not unwrap JSON PSObject values.
                    # Writing the DN directly preserves nested groups and foreign security principals.
                    $MemberValues = [string[]]@("$MemberDn")
                    Set-ADGroup -Identity $Target.Group.DistinguishedName -Server $Target.Server -Add @{ member = $MemberValues } -Confirm:$false
                    $ExistingMembers += $MemberDn
                    $Status = 'Added'
                }
                catch {
                    $Status = 'Failed'
                    $ErrorMessage = $_.Exception.Message
                    $FailureCount++
                    Write-Warning "Cannot add $MemberDn to $($Target.Group.Name): $ErrorMessage"
                }
            }
        }
        if (-not $Silent) {
            [pscustomobject]@{
                Domain = $Target.Domain
                Group = $Target.Group.Name
                GroupSid = $Target.Group.SID.Value
                MemberDn = $MemberDn
                Status = $Status
                Error = $ErrorMessage
            }
        }
    }
}
if ($FailureCount) { throw "Import completed with $FailureCount failed membership additions. Review the results." }
