<#
.SYNOPSIS
Exports direct membership of configured privileged Active Directory groups to JSON.

.DESCRIPTION
Checks the configured group RIDs in each domain of the selected forest and records the
distinguished names of direct members. Nested groups are recorded as members without
expanding their membership. Primary group membership is excluded.

The backup records missing groups. Other directory lookup failures stop the export.
After a successful export, the full backup path is saved in the module's AS2Go.json
under ADPrivilegedGroupDirectMember. Import-ADPrivilegedGroupDirectMember offers this
backup when run without a path.

.PARAMETER Path
Specifies the destination JSON file. The destination must not already exist.
If omitted, saves to $Script:AS2GOConfigDir\AS2Go-<root-domain>MemberShipBackup-yyyyMMdd-HHmmss.json.
The name uses the forest root domain's DNS name and the local date and time.

.PARAMETER Forest
Specifies the forest DNS name. Defaults to the forest of the current user.

.PARAMETER ConfigPath
Specifies the AS2Go JSON configuration containing the PriviledgeGroupRIDs setting.
Defaults to the module's configured AS2Go.json file.

.PARAMETER Silent
Suppresses routine console output and diagnostic streams. Errors remain visible.

.PARAMETER Preview
Displays the planned steps without querying Active Directory or writing a backup.

.EXAMPLE
Export-ADPrivilegedGroupDirectMember

Saves a timestamped backup in the AS2Go configuration directory and records its path.

.EXAMPLE
Export-ADPrivilegedGroupDirectMember -Path 'C:\Temp\ADGroupMembers.json'

Exports direct memberships in the current user's forest using the module configuration.

.OUTPUTS
None. The function writes the backup to the specified JSON file.

.NOTES
Requires the ActiveDirectory PowerShell module for export.

.LINK
Import-ADPrivilegedGroupDirectMember

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Backs up direct members of configured privileged groups across an Active Directory forest.
Records missing groups in the backup and saves the latest backup path in the AS2Go configuration.
#>
function Export-ADPrivilegedGroupDirectMember {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [string]$Forest,

        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath = $Script:ConfigFile,

        [switch]$Silent,

        [switch]$Preview
    )

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Export-ADPrivilegedGroupDirectMember'
        return
    }

    $info = Measure-FunctionRuntime -Begin

    try {
        $ErrorActionPreference = 'Stop'
        if ($Silent) {
            $WarningPreference = 'SilentlyContinue'
            $VerbosePreference = 'SilentlyContinue'
            $DebugPreference = 'SilentlyContinue'
            $InformationPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'
        }
        else {
            Write-AS2GoOutput -Type Header -Message 'Export Privileged Group Memberships'
            Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
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
        if ($Forest) {
            $ForestParameters.Identity = $Forest
        }
        Import-Module -Name ActiveDirectory -Scope Local
        $ForestInfo = Get-ADForest @ForestParameters

        if (-not $Path) {
            $Timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
            $BackupName = "AS2Go-$($ForestInfo.RootDomain)-PrivilegedGroupDirectMembers-$Timestamp.json"
            $Path = Join-Path -Path $Script:AS2GOConfigDir -ChildPath $BackupName
        }

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
                        $Sid = if ($Rid -in 548, 549, 550, 551) {
                            "S-1-5-32-$Rid"
                        }
                        else {
                            "$DomainSid-$Rid"
                        }

                        try {
                            $Group = Get-ADGroup -Identity $Sid -Server $Server -Properties member
                            [pscustomobject]@{
                                Rid               = $Rid
                                Sid               = $Sid
                                Name              = $Group.Name
                                DistinguishedName = $Group.DistinguishedName
                                Status            = 'Exported'
                                Members           = @($Group.member | Sort-Object)
                            }
                        }
                        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                            Write-Warning "Group $Sid does not exist in $DomainName."
                            [pscustomobject]@{
                                Rid               = $Rid
                                Sid               = $Sid
                                Name              = $null
                                DistinguishedName = $null
                                Status            = 'Missing'
                                Members           = @()
                            }
                        }
                    }
                )
                [pscustomobject]@{
                    Domain    = [string]$DomainName
                    DomainSid = $DomainSid
                    Groups    = $Groups
                }
            }
        )

        [pscustomobject]@{
            SchemaVersion  = 1
            Forest         = $ForestInfo.Name
            ExportedAtUtc  = [DateTime]::UtcNow.ToString('o')
            MembershipType = 'DirectMemberAttribute'
            Domains        = $Domains
        } | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $Path -Encoding utf8 -NoClobber

        $BackupPath = (Resolve-Path -LiteralPath $Path).ProviderPath
        Write-Verbose "Exported direct memberships for $($Domains.Count) domains to $BackupPath."
        Set-ASConfig -Setting 'ADPrivilegedGroupDirectMember' -Value $BackupPath
        Write-AS2GoOutput -Type Success -Message "Exported direct Group Membership to $BackupPath"
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
