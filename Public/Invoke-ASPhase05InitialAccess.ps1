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
    PS C:\> Invoke-ASPhase05InitialAccess
    Runs an interactive password spray attack with prompts for scope and password selection.

.EXAMPLE
    PS C:\> Invoke-ASPhase05InitialAccess -UnAttended
    Runs an automated password spray attack using default settings (current domain, last stored password & the samaccount name as password).

.NOTES
    - Requires the ActiveDirectory PowerShell module
    - Displays current domain password policies before executing the attack
    - Logs all activities and execution times
    - Supports targeting Forest, Root Domain, Current Domain, or specific OUs
    - Optional Rubeus integration for Kerberos-based attacks

.LINK
    Invoke-ASPhase05InitialAccess

.FUNCTIONALITY
    Displays the current user's Active Directory account, domain, password policy, and group membership
    information using Get-CurrentADUserInfo, then reports local administrator membership and token
    elevation status using Test-LocalAdministrator.

#>

function Invoke-ASPhase05InitialAccess {

    ################################################################################
    #####                                                                      ##### 
    #####    Run the Attack Phase - Initial Access                              #####                               
    #####                                                                      #####
    ################################################################################
    
    [Alias("ASP05")]
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

    $Info = Measure-FunctionRuntime -Begin

    If ($DeveloperMode) {
        $SkipImages = $true
        $SkipClearHost = $true
        $EnableLogging = $true
    }

    If (-not $AS2GoDemo) { Set-NewColorSchema -NewStage $Script:InitialStart }
    If (-not $SkipClearHost) { Clear-Host }
    
    Update-WindowTitle -NewTitle $Script:Phase05
    Set-ASConfig -Setting "LastStage" -Value $Script:Phase05
    
    Show-CurrentPhase -Phase "phase_05.html"
    

    # If ($skipstep) { break }            
        
    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type  Header -M "Attack Phase - $($Script:Phase05.toupper())"
    Invoke-Output -Type H1 -Message $((get-help (Get-FunctionName)).Functionality)

                

    invoke-output -Type Command -M "begin code for 5"

    Update-WindowTitle -NewTitle $Script:Phase05

    Get-CurrentADUserInfo | Format-List


    Test-LocalAdministrator | Format-List
    <#
pause
    Do {



        If (-not $SkipClearHost) { Clear-Host }

        Invoke-Output -Type  Header -M "Attack Phase - COMPROMISED User Account"
        $Functionality = "This phase involves handling a compromised user account, determining if it has privileged access, `nand taking appropriate actions based on the account's sensitivity."
        Invoke-Output -Type H1 -Message $Functionality

        If ($UnAttended) {
            $answer = $Script:PrivledgeAccount
        }
        else {



            $title = "Was the compromised account a privileged account?"
            $message = "Target scope:"
            
            $Options = @(
                [pscustomobject] @{ 
                    Label = "&Yes"
                    Help  = 'the account had administrative or elevated privileges'
                    Value = $Script:Yes 
                },
                [pscustomobject] @{ 
                    Label = "&No"
                    Help  = 'the account was a standard user account'
                    Value = $Script:No 
                }
            )
            
            $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 1 -Title $title

        }


        If ($answer -eq $Script:Yes) {
            Write-Log -Message "Starting with a PRIVLEDGE(!) COMPROMISED User Account"
            $UserPic = "phase_08.html"
            $Account = "PRIVLEDGE(!) Compromised "
            $Script:PrivledgeAccount = $Script:Yes
            $PrivilegeEscalation = $Script:PtT
            $reconnaissance = $Script:Yes
            Set-NewColorSchema -NewStage $Script:PtH
            #Color Schema for the next command
            #$fgcS = "Black" # Switch
            #$fgcC = "Darkblue"   # Command
            #$fgcF = "Black"
            #$fgcV = "DarkMagenta" # Value
            #$fgcH = "Darkblue" 
        }
        else {
   
            Write-Log -Message "Starting with a non-sensitive COMPROMISED User Account"
            $UserPic = "phase_05.html"
            $Account = "non-sensitive Compromised"
            $Script:PrivledgeAccount = $Script:No
            $PrivilegeEscalation = $Script:PtH
            $reconnaissance = $Script:No
            Set-NewColorSchema -NewStage $Script:InitialStart
        }

        #Pause
        Show-CurrentPhase -Phase $UserPic 
        Get-SessionsOnDC -server $Script:ASDC

        If (-not $SkipClearHost) { Clear-Host }
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        Starting with $Account User Account        "
        Write-Host "____________________________________________________________________`n" 

        $currentUser = $Global:ASVictim
        $currentUser = $env:UserName

        Write-Host -NoNewline "  Command: "
        Write-Highlight -Text ("Get-ADUser ", "-Identity ", "$currentUser") -Color $fgcC, $fgcS, $fgcV

        If ($UnAttended) {
            If ($UseRUBEUS) { $answer = $Script:Yes }else { $answer = $Script:No }
        }
        else {
            $question = "Would you like to run this step - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $Script:Yes
        }

        If ($answer -eq $Script:Yes) {
            Write-Host "`n`n"
            $error.Clear()
            Try {
                $attributes = @("AccountExpirationDate", "CannotChangePassword", "CanonicalName", "cn", "Created", "Department", "Description", "DisplayName", "EmployeeNumber", "Enabled", "Country", "l", "Manager", "MemberOf", "MobilePhone", "userAccountControl", "UserPrincipalName", "LastBadPasswordAttempt", "title")
                get-aduser -Identity $currentUser -Properties $attributes | Format-List | Out-String -ErrorAction Stop
  
            }
            catch {
                $message = $_
                Write-Host " "$message.CategoryInfo.Reason:" " -NoNewline
                $message.Exception
  
                Write-Host ""
                Write-host "  Account restrictions are preventing this user from signing in." -ForegroundColor $fgcH
                Write-HosT "  Probably helpdesk user '$Global:ASHelpDeskUser' is member of the 'Protected Users' Group!`n`n" -ForegroundColor $fgcH
                pause
                #Stop-AS2GoDemo
            }
    


    
            Write-Host ""
            Pause
            If (-not $SkipClearHost) { Clear-Host }
            invoke-output -type Header -message "Displays a list of currently cached Kerberos tickets"

            Write-Host ""             
            Write-Host -NoNewline "  Command: "
            Write-Highlight -Text ('klist') -Color $fgcC
            Write-Host ""           
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            Write-Host ""
            $tickets = Get-KlistTicket
            $tickets | Format-Table TicketNumber, Client, Server, EncryptionType, EndTime -AutoSize
            Invoke-Output -Type Info -Message "Last Ticket"
            $tickets | Select-object -Last 1 | Format-List
            
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            #If (-not $SkipClearHost) { Clear-Host }
        }
        elseIf ($answer -eq $Script:Exit) {
            Stop-AS2GoDemo
        }
        else {
        }

        # If ($skipstep) {break}

        #Invoke-Output -Type  Header -M "??? REPEAT | Attack Phase - COMPROMISED User Account ???"


        If ($UnAttended) {
            $repeat = $Script:No
        }
        else {
            $title = "REPEAT | Attack Phase - $($Script:Phase05)"
            $repeat = Show-DecisionPrompt -Default 1 -Title $title
        }
   
    } Until ($repeat -eq $Script:No)


#>


    Measure-FunctionRuntime -End -Details $Info 
}
