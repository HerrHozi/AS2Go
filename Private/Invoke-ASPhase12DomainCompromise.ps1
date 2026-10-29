<#
.SYNOPSIS
Offers domain persistence, disruption, and demonstration-closing actions.

.DESCRIPTION
Presents a repeatable menu of final AS2Go actions and invokes the selected workflow.
Options include creating an administrative backdoor user, modifying a selected GPO, removing privileged group
memberships, disabling users or resetting passwords, and encrypting files through the ransomware demonstration.
Other options export domain DPAPI backup keys, forge and inject a Golden Ticket, or restart configured victims.
Exit invokes the demo-closing workflow. Unattended mode selects the backdoor step followed by the reboot step.

.EXAMPLE
Invoke-ASPhase12DomainCompromise
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Available actions depend on initialized module settings, tools, modules, and current permissions.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Offers backdoor creation, GPO changes, privileged membership removal, and user disabling or password resets.
Also offers staged file encryption, domain DPAPI backup-key export, and Golden Ticket creation and injection.
Runs the selected workflow, requests restarts of configured victim machines, or closes the demonstration.
#>
function Invoke-ASPhase12DomainCompromise {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 12 Domain Compromise
    #####                                                                      #####
    ################################################################################

    $info = Measure-FunctionRuntime -Begin

    Update-WindowTitle -NewTitle $Script:Phase12
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase12

    Do {

        If (-not $SkipClearHost) { Clear-Host }

        Write-AS2GoOutput -Type Header -Message "Domain Dominance & Persistence"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $topicBackdoor = "Establish persistent domain access through a covert backdoor account"
        $topicGPT = "Weaponize Group Policy Template (GPT) files for domain-wide compromise"
        $topicPurge = "Purge all privileged group memberships to grant exclusive control to the backdoor account"
        $topicUserAccount = "Disable user accounts or enforce password resets (retain backdoor control)"
        $topicEncrypt = "Encrypt critical Domain Controller assets for strategic leverage"
        $topicMasterKey = "Extract the DPAPI master key for credential and secret recovery"
        $topicGoldenTicket = "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
        $topicReboot = "Trigger coordinated reboot across accessible Domain Controllers"
        $topicExit = "Exit AS2Go."

        If ($UnAttended) {
            $answer = "B"
        }
        else {

            If (-not $Script:MoGPO) {
                $topicGPT = $null
            }

            $title = "Domain Dominance & Persistence"
            $message = "Select the action to execute. Options with unmet requirements are hidden."
            $Options = @(
                [pscustomobject] @{
                    Label = "&Backdoor"
                    Help  = $topicBackdoor
                    Value = "Backdoor"
                },
                [pscustomobject] @{
                    Label = "GP&T"
                    Help  = $topicGPT
                    Value = "GPT"
                },
                [pscustomobject] @{
                    Label = "&Purge"
                    Help  = $topicPurge
                    Value = "Purge"
                },
                [pscustomobject] @{
                    Label = "&User Account"
                    Help  = $topicUserAccount
                    Value = "UserAccount"
                },
                [pscustomobject] @{
                    Label = "Master &Key"
                    Help  = $topicMasterKey
                    Value = "MasterKey"
                },
                [pscustomobject] @{
                    Label = "&Golden Ticket"
                    Help  = $topicGoldenTicket
                    Value = "GoldenTicket"
                },
                [pscustomobject] @{
                    Label = "&Encrypt"
                    Help  = $topicEncrypt
                    Value = "Encrypt"
                },
                [pscustomobject] @{
                    Label = "&Reboot"
                    Help  = $topicReboot
                    Value = "Reboot"
                },
                [pscustomobject] @{
                    Label = "E&xit"
                    Help  = $topicExit
                    Value = "Exit"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
        }

        switch ($answer) {

            "Backdoor" {
                Invoke-BackdoorUserCreation
                $repeat = $Script:Yes
            }
            "Purge" {
                Invoke-PrivilegeGroupPurge
                $repeat = $Script:Yes
            }
            "GPT" {
                Invoke-GPTManipulation
                $repeat = $Script:Yes
            }
            "UserAccount" {
                Invoke-UserAccountDisruption
                $repeat = $Script:Yes
            }
            "GoldenTicket" {
                Invoke-GoldenTicketAttack
                $repeat = $Script:Yes
            }
            "Encrypt" {
                Invoke-DomainEncryptionAttack
                $repeat = $Script:Yes
            }
            "MasterKey" {
                Invoke-DPAPIMasterKeyExport
                $repeat = $Script:Yes
            }
            "Reboot" {
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type Header -M "Trigger coordinated reboot across accessible Domain Controllers"
                Restart-VictimMachines
                $repeat = $Script:Yes
            }
            "Exit" {
                Stop-AS2GoDemo -NextStepReboot $Script:No
                $repeat = $Script:No
                pause
            }

            default {
                Write-Host "out of scope"
                $repeat = $Script:Yes
            }
        }

        If (-not $SkipClearHost) { Clear-Host }

    } Until ($repeat -eq $Script:No)

    Measure-FunctionRuntime -End -Details $info
}
