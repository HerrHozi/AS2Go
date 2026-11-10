<#
.SYNOPSIS
Runs the privileged group membership purge workflow.

.DESCRIPTION
In attended mode, offers to proceed with the current membership backup, export a fresh
backup before proceeding, or skip the purge. The purge workflow selects a scope and asks
for confirmation before removing direct memberships, preserving the protected account SIDs.

.EXAMPLE
Invoke-PrivilegeGroupPurge
Runs the privilege group purge workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Offers to keep or refresh the membership backup before removing direct members from selected privileged groups.
#>
function Invoke-PrivilegeGroupPurge {

    $info = Measure-FunctionRuntime -Begin

    try {
        if (-not $SkipClearHost) { Clear-Host }
        Write-AS2GoOutput -Type Header -Message 'Purge privileged group memberships'
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $SavedPath = Get-ASConfig -Setting 'ADPrivilegedGroupDirectMember'
        Write-AS2GoOutput -Type TextMaker -Message 'Current backup file' -TextMaker $SavedPath -NoExtraLines

        $Answer = $Script:Yes
        if (-not $UnAttended) {
            $Options = @(
                [pscustomobject]@{
                    Label = '&Run (with current backup)'
                    Help  = 'Keep the current backup and continue to purge scope selection.'
                    Value = $Script:Yes
                }
                [pscustomobject]@{
                    Label = 'R&un (but update before)'
                    Help  = 'Export a new membership backup before continuing to purge scope selection.'
                    Value = 'RefreshAndRun'
                }
                [pscustomobject]@{
                    Label = '&Skip'
                    Help  = 'Return without exporting a backup or purging memberships.'
                    Value = $Script:No
                }
            )
            $Answer = Show-DecisionPrompt -Title 'Purge privileged group memberships' -Options $Options

            if ($Answer -eq $Script:Yes -and
                (-not $SavedPath -or -not (Test-Path -LiteralPath $SavedPath -PathType Leaf))) {
                Write-AS2GoOutput -Type Warning -Message 'The current backup is unavailable. Choose the update option to create a backup before purging.'
                return
            }
        }

        if ($Answer -eq 'RefreshAndRun') {
            try {
                Export-ADPrivilegedGroupDirectMember -ErrorAction Stop
            }
            catch {
                Write-AS2GoOutput -Type Error -Message "The backup could not be updated. The purge was skipped. $($_.Exception.Message)"
                return
            }
        }

        if ($Answer -in $Script:Yes, 'RefreshAndRun') {
            Invoke-GroupManipulation
            if ($UnAttended) { Start-Sleep -Seconds 2 } else { Pause }
        }
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}
