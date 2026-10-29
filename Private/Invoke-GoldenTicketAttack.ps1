<#
.SYNOPSIS
Forges and injects a Golden Ticket for unrestricted Kerberos dominance.

.DESCRIPTION
Creates a forged Kerberos TGT (Golden Ticket) using the krbtgt account hash to demonstrate
unrestricted access to any resource in the domain with arbitrary identity and permissions.

.EXAMPLE
Invoke-GoldenTicketAttack
Runs the Golden Ticket forging and injection workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires the NTLM hash of the krbtgt account.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Forges a Golden Ticket using the krbtgt hash to achieve unrestricted Kerberos dominance.
#>
function Invoke-GoldenTicketAttack {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet -M "Step 1: Dump the NTLM Hash for 'krbtgt' account"
    Write-AS2GoOutput -Type Bullet -M "Step 2: Forge Golden Ticket"
    Write-AS2GoOutput -Type Bullet -M "Step 3: Use the Golden Ticket to achieve unrestricted Kerberos dominance"

    If ($UnAttended) {
        $answer = $Script:No
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        Invoke-GoldenTicket
    }

    Measure-FunctionRuntime -End -Details $info
}
