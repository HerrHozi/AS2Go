<#
.SYNOPSIS
Restores missing direct memberships of privileged Active Directory groups from JSON.

.DESCRIPTION
Reads a backup created by Export-ADPrivilegedGroupDirectMember. Validates the recorded
forest, domain SIDs, and group records before adding members. Resolves groups by SID
and skips groups recorded as missing in the backup.

Member objects must still exist at their original distinguished names. The import
preserves existing memberships. Providing a path bypasses the AS2Go configuration.

.PARAMETER Path
Specifies the JSON backup file. If omitted, offers the latest backup saved under
ADPrivilegedGroupDirectMember in AS2Go.json. Opens a file selection dialog if the
saved backup is unavailable or you decline to use it.

.PARAMETER Silent
Suppresses routine console output, diagnostic streams, and result objects.
Errors and confirmation or WhatIf messages remain visible.

.PARAMETER Preview
Displays the planned steps without opening the file picker, reading a backup, or querying Active Directory.

.EXAMPLE
Import-ADPrivilegedGroupDirectMember -Path 'C:\Temp\ADGroupMembers.json' -WhatIf

Validates the backup against Active Directory and shows which memberships would be added.

.EXAMPLE
Import-ADPrivilegedGroupDirectMember -Path 'C:\Temp\ADGroupMembers.json'

Prompts for confirmation before adding missing members to the original groups.

.EXAMPLE
Import-ADPrivilegedGroupDirectMember | where-object {$_.Status -ne 'AlreadyMember'} | Select-Object Status, Domain, Group, MemberDn | ft

Offers the saved backup or opens the file picker, then displays the import results in a table.

.OUTPUTS
System.Management.Automation.PSCustomObject
Returns one result per distinct member in each restored group. Status is AlreadyMember,
Skipped, Added, or Failed. A failed addition includes the error message.

.NOTES
Requires the ActiveDirectory PowerShell module for import. Failed additions are reported
as they occur. The function raises a terminating error after processing the remaining members.

.LINK
Export-ADPrivilegedGroupDirectMember

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Restores missing direct memberships of privileged groups from a JSON backup in the original forest.
Preserves existing group memberships.
#>
function Import-ADPrivilegedGroupDirectMember {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Position = 0)]
        [string]$Path,
        [switch]$Silent,
        [switch]$Preview
    )

    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Import-ADPrivilegedGroupDirectMember'
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
            Write-AS2GoOutput -Type Header -Message 'Import Privileged Group Memberships'
            Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
        }

        if (-not $Path) {
            $SavedPath = Get-ASConfig -Setting 'ADPrivilegedGroupDirectMember'
            if ($SavedPath -match '\.json$' -and (Test-Path -LiteralPath $SavedPath -PathType Leaf)) {
                $Title = 'Use the latest membership backup?'
                $Message = "The AS2Go configuration points to this backup:`n$SavedPath`n`nDo you want to use it?"
                $Answer = Show-DecisionPrompt -Title $Title -Message $Message

                if ($Answer -eq $Script:Yes) {
                    $Path = $SavedPath
                }
            }
        }

        if (-not $Path) {
            Add-Type -AssemblyName System.Windows.Forms

            $Dialog = New-Object -TypeName System.Windows.Forms.OpenFileDialog
            try {
                $Dialog.Title = 'Select a group membership backup'
                $Dialog.Filter = 'JSON files (*.json)|*.json'
                $Dialog.Multiselect = $false
                $Dialog.CheckFileExists = $true
                $Dialog.InitialDirectory = (Get-Location).Path

                $DialogResult = $Dialog.ShowDialog()
                if ($DialogResult -ne [System.Windows.Forms.DialogResult]::OK -or
                    [string]::IsNullOrWhiteSpace($Dialog.FileName)) {
                    if (-not $Silent) {
                        Write-AS2GoOutput -Type Info -Message 'Import canceled. No backup file was selected.'
                    }
                    return
                }

                $Path = $Dialog.FileName
            }
            finally {
                $Dialog.Dispose()
            }
        }

        if ($Path -notmatch '(?i)\.json$') {
            throw "The configured or selected path '$Path' is not a JSON backup file."
        }

        $Data = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        if ($Data.SchemaVersion -ne 1 -or $Data.MembershipType -ne 'DirectMemberAttribute' -or
            -not $Data.Forest -or -not @($Data.Domains).Count) {
            throw 'Unsupported or incomplete group membership JSON.'
        }

        Import-Module -Name ActiveDirectory -Scope Local
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
                    else {
                        "$($Domain.DomainSID.Value)-$($GroupRecord.Rid)"
                    }
                    if ($GroupRecord.Sid -ne $ExpectedSid) {
                        throw "Unexpected group SID: $($GroupRecord.Sid)."
                    }
                    if ($GroupRecord.Status -eq 'Missing') {
                        continue
                    }
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
                        Domain  = $DomainRecord.Domain
                        Server  = $Server
                        Group   = $Group
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
                        Domain   = $Target.Domain
                        Group    = $Target.Group.Name
                        GroupSid = $Target.Group.SID.Value
                        MemberDn = $MemberDn
                        Status   = $Status
                        Error    = $ErrorMessage
                    }
                }
            }
        }

        if ($FailureCount) {
            throw "Import completed with $FailureCount failed membership additions. Review the results."
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
