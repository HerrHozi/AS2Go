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

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    $GPOManipulation = "M"

    Do {
        $repeat = $Script:Yes
        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type Header -Message "GPT Manipulation - Choose your Technique"
        Invoke-Output -Type Bullet -Message "During this attack, AS2Go will only add these groups as member " -TM "Domain Users, Authenticated Users or Everyone"

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

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
