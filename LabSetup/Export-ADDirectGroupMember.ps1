#Requires -Version 5.1
#Requires -Modules ActiveDirectory
<#
.SYNOPSIS
Exports direct members of selected groups in every forest domain to JSON.
.DESCRIPTION
Reads the member attribute without recursion. Primary group membership is not included.
Missing groups are recorded explicitly. Other lookup failures stop the export.
The JSON is intended for restoring memberships in the same forest with unchanged member DNs.
.PARAMETER Path
Destination JSON file. Existing files are not overwritten.
.PARAMETER Forest
Forest DNS name. Defaults to the forest of the current user.
.PARAMETER ConfigPath
AS2Go JSON configuration. Defaults to .\AS2Go.json in the current working directory.
.PARAMETER Silent
Suppresses diagnostic messages and result objects. Errors and confirmation/WhatIf prompts remain visible.
.EXAMPLE
.\Export-ADDirectGroupMember.ps1 -Path C:\Temp\ADGroupMembers.json
.FUNCTIONALITY
Exports direct group member DNs for selected RIDs across every domain in a forest.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Path,

    [string]$Forest,

    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = '.\AS2Go.json',

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
$Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$RidSettings = @($Config.DefaultParameter.Setting | Where-Object { $_.Name -eq 'PriviledgeGroupRIDs' })
if ($RidSettings.Count -ne 1 -or $RidSettings[0].Value -isnot [string]) {
    throw "Expected exactly one PriviledgeGroupRIDs string setting in $ConfigPath."
}
$GroupRids = @(
    foreach ($Token in ($RidSettings[0].Value -split ',')) {
        if ($Token -notmatch "^\s*(?:'([0-9]+)'|([0-9]+))\s*$") {
            throw "Invalid RID entry in PriviledgeGroupRIDs: $Token"
        }
        $RidText = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
        $ParsedRid = [uint32]0
        if (-not [uint32]::TryParse($RidText, [ref]$ParsedRid) -or $ParsedRid -eq 0) {
            throw "RID must be a positive 32-bit unsigned integer: $RidText"
        }
        $ParsedRid
    }
) | Sort-Object -Unique
$ForestParameters = @{}
if ($Forest) { $ForestParameters.Identity = $Forest }
$ForestInfo = Get-ADForest @ForestParameters

$Domains = @(
    foreach ($DomainName in ($ForestInfo.Domains | Sort-Object)) {
        $Domain = Get-ADDomain -Identity $DomainName -Server $DomainName
        $DomainController = Get-ADDomainController -Discover -DomainName $DomainName -Writable
        $Server = [string](@($DomainController.HostName)[0])
        if ([string]::IsNullOrWhiteSpace($Server)) {
            throw "No domain controller hostname was returned for $DomainName."
        }
        $DomainSid = $Domain.DomainSID.Value
        $Groups = @(
            foreach ($Rid in $GroupRids) {
                $Sid = if ($Rid -in 548, 549, 550, 551) { "S-1-5-32-$Rid" } else { "$DomainSid-$Rid" }
                try {
                    $Group = Get-ADGroup -Identity $Sid -Server $Server -Properties member
                    [pscustomobject]@{
                        Rid = $Rid
                        Sid = $Sid
                        Name = $Group.Name
                        DistinguishedName = $Group.DistinguishedName
                        Status = 'Exported'
                        Members = @($Group.member | Sort-Object)
                    }
                }
                catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                    Write-Warning "Group $Sid does not exist in $DomainName."
                    [pscustomobject]@{
                        Rid = $Rid
                        Sid = $Sid
                        Name = $null
                        DistinguishedName = $null
                        Status = 'Missing'
                        Members = @()
                    }
                }
            }
        )
        [pscustomobject]@{
            Domain = [string]$DomainName
            DomainSid = $DomainSid
            Groups = $Groups
        }
    }
)

[pscustomobject]@{
    SchemaVersion = 1
    Forest = $ForestInfo.Name
    ExportedAtUtc = [DateTime]::UtcNow.ToString('o')
    MembershipType = 'DirectMemberAttribute'
    Domains = $Domains
} | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $Path -Encoding utf8 -NoClobber

Write-Verbose "Exported direct memberships for $($Domains.Count) domains to $Path."
