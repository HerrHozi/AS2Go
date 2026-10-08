<#
.SYNOPSIS
    Executes a password spray attack against Active Directory users in a specified scope.

.DESCRIPTION
    This function performs a password spray attack by attempting to authenticate multiple Active Directory users
    with one or more passwords. It provides multiple scope options (Forest, Root Domain, Current Domain, or specific OU)
    and allows the user to configure the attack parameters interactively or in unattended mode.
    
    The function performs password spray attacks using both standard authentication methods and Rubeus (if available).
    It checks domain password policies to calculate maximum safe spray attempts without locking accounts.

.PARAMETER UnAttended
    When specified, skips all interactive prompts and uses default values for automated execution.

.PARAMETER DeveloperMode
    When specified, displays additional debug information including successful credential matches.

.EXAMPLE
    PS C:\> Invoke-ASPhase04BruteForceAttack
    Runs an interactive password spray attack with prompts for scope and password selection.

.EXAMPLE
    PS C:\> Invoke-ASPhase04BruteForceAttack -UnAttended
    Runs an automated password spray attack using default settings (current domain, last stored password & the samaccount name as password).

.NOTES
    - Requires the ActiveDirectory PowerShell module
    - Displays current domain password policies before executing the attack
    - Logs all activities and execution times
    - Supports targeting Forest, Root Domain, Current Domain, or specific OUs
    - Optional Rubeus integration for Kerberos-based attacks

.LINK
    Invoke-Phase04BruteForceAttack

#>

function Invoke-ASPhase04BruteForceAttack {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Brute Force Account                        #####                               
    #####                                                                      #####
    ################################################################################
    
    [Alias("ASP04", "PwSpray")]
    Param (  
        [switch]$UnAttended,
        [switch]$Continue,
        [Switch]$EnableLogging,
        [switch]$SkipImages,
        [switch]$SkipClearHost,
        [switch]$AS2GoDemo,
        [switch]$Simulation,
        [Alias("DelevoperMode")]
        [switch]$DeveloperMode
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ($DeveloperMode) {
        $SkipImages = $true
        $SkipClearHost = $true
        $EnableLogging = $true
    }

    If (-not $AS2GoDemo) { Set-NewColorSchema -NewStage $Script:InitialStart }
    If (-not $SkipClearHost) { Clear-Host }
    
    Update-WindowTitle -NewTitle $Script:Phase04
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase04
    
    If (-not $SkipImages) { Show-Phases -Phase "phase_004.html" }
    
    Do {
        # If ($skipstep) { break }            
        
        If (-not $SkipClearHost) { Clear-Host }
        Invoke-Output -T Header -M "Attack Phase - $($Script:Phase04.toupper())"
        Invoke-output -T Bullet -M "Perform a password spraying attack (a form of brute-force) to validate detection and response."
                
        If ($AS2GoDemo) {
            if ($UnAttended -eq $true) {
                If ($SkipPasswordSpray -eq $false)
                { $answer = $Script:Yes }
                else
                { $answer = $Script:No }
            }
            else {
                $answer = Show-DecisionPrompt
            }
        }
        else {
            $answer = $Script:Yes
        }

        If ($answer -eq $Script:Yes) {
            New-PasswordSprayAttack
        }
        elseIf ($answer -eq $Script:Exit) {
            Stop-AS2GoDemo
        }
        else {
        }

        If (-not $AS2GoDemo) { break }

        #If (-not $SkipClearHost) { Clear-Host }


        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Attack Phase - $($Script:Phase04)"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }

    } Until ($repeat -eq $Script:No)


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
