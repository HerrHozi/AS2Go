<#
.SYNOPSIS
Manipulates Group Policy Template files for domain-wide compromise.

.DESCRIPTION
Modifies a selected Group Policy Object's templates to distribute malicious configurations
across all domain-joined machines, demonstrating GPO weaponization for lateral movement.

.EXAMPLE
Invoke-GPTManipulation
Runs the Group Policy Template manipulation workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.

.COMPONENT
Category: Attack Function

.FUNCTIONALITY
Manipulates Group Policy Template files in a selected GPO to compromise domain-joined machines.
#>
function Invoke-GPTManipulation {

    $info = Measure-FunctionRuntime -Begin

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Manipulate Group Policy Templates (GPT) files"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {
        $TargetGPO = Get-GPOLinkedOnDomain
        $TargetGPO = Get-TargetGPO

        if ([string]::IsNullOrEmpty($TargetGPO)) {
            Write-AS2GoOutput -Type CodeSnippet -Message "Domain Selection cancelled by user"
        }
        else {
            New-GPOManipulation -ID $TargetGPO.ID.Guid -name $TargetGPO.DisplayName -domainDNS $TargetGPO.DomainDNS -server $TargetGPO.Server
        }
    }

    Measure-FunctionRuntime -End -Details $info
}
