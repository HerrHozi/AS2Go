<#
.SYNOPSIS
Offers changes to a selected GPO: local group membership, scheduled tasks, or sensitive user rights.

.FUNCTIONALITY
Offers changes to a selected GPO: local group membership, scheduled tasks, or sensitive user rights.
Demonstrates how writable Group Policy Template files can spread privileged settings to computers applying the GPO.
#>
function New-GPOManipulation {

    ################################################################################
    #####                                                                      ##### 
    #####    Start a new GPO Manipulation                                      #####                          
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $domainDNS,
        [string] $server,
        [string] $ID, 
        [String] $name
    )

    $Info = Measure-FunctionRuntime -Begin

    $GPOManipulation = "M"

    Do {
        $repeat = $Script:Yes
        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "GPT Manipulation - Choose your Technique"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
        Write-AS2GoOutput -Type Bullet -Message "During this attack, AS2Go will only add these groups as member " -TM "Domain Users, Authenticated Users or Everyone"

        If ($UnAttended) {
            $answer = $Script:Yes 
        }
        else {

            $title = "GPT Manipulation"
            $message = "Select the attack technique to execute."
            $Options = @(
                [pscustomobject] @{
                    Label = "Add &Members"
                    Help  = "Add members to the built-in Administrators & Remote Desktop Users Group."
                    Value = "M"
                },
                [pscustomobject] @{
                    Label = "&Scheduled Tasks"
                    Help  = "Add a Scheduled Task."
                    Value = "S"
                },
                [pscustomobject] @{
                    Label = "Add User &Rights Assignment"
                    Help  = "like SeDebugPrivilege,SeTcbPrivilege or SeRemoteInteractiveLogonRight."
                    Value = "U"
                },
                [pscustomobject] @{
                    Label = "&Cancel"
                    Help  = "Skip GPT Manipulation."
                    Value = "C"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        }

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
            "C" {
                return
            }
            default {
                Write-Host "out of scope"
            }
        }
        If (-not $SkipClearHost) { Clear-Host }
        Write-Log -Message "    >>  last technique: $answer"
    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $Info
}
