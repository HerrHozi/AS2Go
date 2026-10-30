<#
.SYNOPSIS
Runs Phase 12 of the AS2Go attack simulation: Domain Compromise and Persistence.

.DESCRIPTION
Invoke-ASPhase12DomainCompromisePersistence executes the final attack phase in the AS2Go workflow.
It prepares the phase context, shows the phase banner, and starts the Phase 12 action chain after
interactive confirmation (or automatically in unattended mode).

The phase demonstrates persistence and impact actions such as:
- Creating a persistent backdoor domain account
- User account manipulation (disable/reset)
- Tier 0 group membership manipulation
- Group Policy Template tampering
- Encrypting backup files on a domain controller
- Exporting a DPAPI master key
- Forging a Kerberos Golden Ticket
- Rebooting available domain machines

.PARAMETER Preview
Browses descriptions and workflow steps offline without executing actions.
Uses a separate preview menu; runtime selection and skip parameters are not evaluated.

.PARAMETER UnAttended
Runs the phase without interactive confirmation prompts.

.PARAMETER Continue
Reserved switch for workflow continuation handling.

.PARAMETER EnableLogging
Enables extended logging for this phase execution.

.PARAMETER SkipImages
Skips visual phase assets (for example, phase HTML images/pages).

.PARAMETER SkipClearHost
Prevents clearing the console during phase execution.

.PARAMETER AS2GoDemo
Runs the phase in AS2Go demo mode and skips selected setup interactions.

.PARAMETER DeveloperMode
Developer convenience mode.
When set, this switch enables logging and automatically skips images and host clearing.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence

Runs Phase 12 interactively.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence -UnAttended -EnableLogging

Runs Phase 12 without prompts and with logging enabled.

.EXAMPLE
Invoke-ASPhase12DomainCompromisePersistence -DeveloperMode

Runs Phase 12 with developer defaults (logging on, images skipped, no clear-host).

.NOTES
Alias: P12, Compromise
Part of: AS2Go attack phase orchestration

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Offers backdoor creation, GPO changes, privileged membership removal, and user disabling or password resets.
Also offers staged file encryption, domain DPAPI backup-key export, and Golden Ticket creation and injection.
Runs the selected workflow, requests restarts of configured Domain Controllers, or closes the demonstration.
#>
function Invoke-ASPhase12DomainCompromisePersistence {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Domain Compromise & Persistence            #####                               
    #####                                                                      #####
    ################################################################################
    [Alias("ASP12", "Compromise")]
    Param (  
        [switch]$Preview,
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$DeveloperMode,
        [validateSet("Encrypt", "Reboot", "BackdoorUser", "GPT", "UserManipulation", "GroupManipulation")]
        [String]$DomainPersistence
    )
    
    if ($Preview) {
        Show-AS2GoPreview -FunctionName 'Invoke-ASPhase12DomainCompromisePersistence' -UnAttended:([bool]$PSBoundParameters['UnAttended'])
        return
    }

    $info = Measure-FunctionRuntime -Begin
    Show-CurrentPhase -Phase "phase_12.html"
    
    $functionCallParameters = Get-FunctionCallParameters -FunctionName $MyInvocation.MyCommand.Name -BoundParameters $PSBoundParameters
    $4logfile = $functionCallParameters.Parameters | Out-String
    Write-Log -Message "    >> Used parameter: $4logfile"

    If ($DeveloperMode) {
        $SkipImages = $true
        $SkipClearHost = $true
        $EnableLogging = $true
    }
        
    If (-not $SkipClearHost) { Clear-Host }
    If (-not $AS2GoDemo) {
        Clear-ExfiltrationFolder 
        Set-NewColorSchema -NewStage $Script:InitialStart
        Get-AS2GoSettings
    }
        
    Update-WindowTitle -NewTitle $Script:Phase12 
        
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase12
    $result = Get-ASConfig -Setting "BreakGlassAccount"
    $result = Convert-FromDNToCN -DistinguishedName $result

        
    Set-NewColorSchema -NewStage $Script:InitialStart
    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -M "Attack Phase - $($Script:Phase12.toupper())"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type Bullet "Create a persistent backdoor domain account"
    Write-AS2GoOutput -Type Bullet "Perform user account manipulation (disable accounts and/or reset passwords)"
    Write-AS2GoOutput -Type Bullet "Perform Tier 0 group membership manipulation (remove all admins except backdoor and break-glass accounts)"
    Write-AS2GoOutput -Type Bullet "Tamper with Group Policy Template (GPT) files to push malicious settings"
    Write-AS2GoOutput -Type Bullet "Encrypt backup files stored on the domain controller"
    Write-AS2GoOutput -Type Bullet "Export the DPAPI master key for offline decryption of secrets"
    Write-AS2GoOutput -Type Bullet "Forge a Kerberos Golden Ticket for long-term domain persistence"
    Write-AS2GoOutput -Type Bullet "Reboot all available machines in the domain"


    Write-AS2GoOutput -Type H1 -Message "`n`nThe configured break-glass account will be excluded, can be modified during this phase."
    Write-AS2GoOutput -Type TextMaker -Message "Current Break Glass Account:" -Tm $result -NoExtraLines


    If ($UnAttended) {
        $answer = $Script:Yes
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -ne $Script:Yes) {
        Measure-FunctionRuntime -End -Details $info
        return
    }
    
    
    If (-not $AS2GoDemo) {
        $Script:MoGPO = Test-PoSHModuleAvailability -PSModule "GroupPolicy"  
        Show-ForestOverview 
        Get-ForestInfo

    }
        
        
    #Invoke-ASPhase12DomainCompromise 


    Update-WindowTitle -NewTitle $Script:Phase12
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase12

    Do {



        #Write-AS2GoOutput -Type H1 -Message "Domain Dominance & Persistence"
        #Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $topicBackdoor = "Establish persistent domain access through a covert backdoor account"
        $topicBreakGlass = "Select or change the protected break-glass account"
        $topicGPT = "Weaponize Group Policy Template (GPT) files for domain-wide compromise"
        $topicPurge = "Purge all privileged group memberships to grant exclusive control to the backdoor account"
        $topicUserAccount = "Disable user accounts or enforce password resets (retain backdoor control)"
        $topicEncrypt = "Encrypt critical Domain Controller assets for strategic leverage"
        $topicMasterKey = "Extract the DPAPI master key for credential and secret recovery"
        $topicGoldenTicket = "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
        $topicReboot = "Trigger coordinated reboot across accessible Domain Controllers"
        $topicExit = "Exit AS2Go."

        If ($UnAttended) {
            $answer = $DomainPersistence
        }
        else {

            If (-not $Script:MoGPO) {
                $topicGPT = $null
            }

            $title = "Domain Dominance & Persistence"
            $message = "Select the action to execute. Options with unmet requirements are hidden."
            $Options = @(
                [pscustomobject] @{
                    Label = "&Change BGA"
                    Help  = $topicBreakGlass
                    Value = "BreakGlass"
                },
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
            If (-not $SkipClearHost) { Clear-Host }
        }

        switch ($answer) {

            "Backdoor" {
                Invoke-BackdoorUserCreation
                $repeat = $Script:Yes
            }
            "BreakGlass" {
                Set-BreakGlassAccount
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
                Invoke-Encryption
                $repeat = $Script:Yes
            }
            "MasterKey" {
                Invoke-DPAPIMasterKeyExport
                $repeat = $Script:Yes
            }
            "Reboot" {
                Invoke-Shutdown
                $repeat = $Script:No
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

        If ($UnAttended) {
            $repeat = $Script:No
        }

    } Until ($repeat -eq $Script:No)
    
    

    Measure-FunctionRuntime -End -Details $info
}
