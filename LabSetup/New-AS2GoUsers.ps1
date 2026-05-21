<#
.SYNOPSIS
Create four accounts (Victim, Helpdesk, Service Account & Domain Admin) for the attack demo.

.DESCRIPTION

These accounts are needed for the attack.


.NOTES

last update: 2022-12-01
File Name  : New-AS2GoUsers.ps1 | Version 2.6.0
Author     : Holger Zimmermann | @HerrHozi
https://herrhozi.com

.PARAMETER Shortname

Define the name for the accounts. "y" is the default.
Y - yyyyMMdd
N - yyyyMMdd.hhmmss
<your name> 

.SWITCH SkipDomainAdmin
Skip the creation of the DA-xxxxx Domain Admin account.

.SWITCH SkipHelpDesk
Skip the creation of the HelpDesk account.

.SWITCH SkipVictim
Skip the creation of the Victim account.

.EXAMPLE
PS> cd C:\Temp\AS2Go
PS> .\New-AS2GoUsers.ps1

.EXAMPLE
PS> .\New-AS2GoUsers.ps1 -Shortname n

.EXAMPLE
PS> .\New-AS2GoUsers.ps1 -Shortname HerrHoZi

.EXAMPLE
PS> .\New-AS2GoUsers.ps1 -SkipVictim -Shortname HerrHoZi

creates the only the domain admin & help desk account with an dedicated name, DA-HerrHoZi & HD-HerrHoZi

.LINK
https://herrhozi.com
#>

#Check if the current Windows PowerShell session is running as Administrator. 
#If not Start Windows PowerShell by  using the Run as Administrator option, and then try running the script again.

#Requires -RunAsAdministrator

param([string] $Shortname='y',[switch]$SkipDomainAdmin,[switch]$SkipHelpDesk, [switch]$SkipVictim )

#get current Posh Name & path
$PoSHPath    = Get-Location
$scriptName  = $MyInvocation.MyCommand.Name
$logfile     = "$PoSHPath\$scriptName.log"
$NTDSDITFILE = "$PoSHPath\ntds.dit"

#get the Domain Roout OU
Import-Module ActiveDirectory
$ADRoot = Get-ADRootDSE
$Domain = Get-ADDomain
$RootOU = $ADRoot.defaultNamingContext


 $AS2GoUser = @(
       [pscustomobject]@{SVCAccounts = "OU=Service Accounts,OU=Tier 0 Assets,OU=AS2Go,$RootOU";Path = "OU=Accounts,OU=Tier 0 Assets,OU=AS2Go,$RootOU"; ComputerPath = "OU=Tier 0 Servers,OU=Tier 0 Assets,OU=AS2Go,$RootOU"}
       [pscustomobject]@{SVCAccounts = "OU=Service Accounts,OU=Tier 1 Assets,OU=AS2Go,$RootOU";Path = "OU=Accounts,OU=Tier 1 Assets,OU=AS2Go,$RootOU"; ComputerPath = "OU=Devices,OU=Tier 1 Assets,OU=AS2Go,$RootOU"}
       [pscustomobject]@{SVCAccounts = "OU=Service Accounts,OU=Tier 2 Assets,OU=AS2Go,$RootOU";Path = "OU=Accounts,OU=Tier 2 Assets,OU=AS2Go,$RootOU"; ComputerPath = "OU=Devices,OU=Tier 2 Assets,OU=AS2Go,$RootOU"}
   )

# OU Path for new Users
$UPNSuffix = "@HerrHozi.com"

# Store the user passwords as variables
$master = 'PassW0rd'
$DASecurePass = ConvertTo-SecureString -String $master'da' -AsPlainText -Force
$HDSecurePass = ConvertTo-SecureString -String $master'hd' -AsPlainText -Force
$VISecurePass = ConvertTo-SecureString -String $master'vi' -AsPlainText -Force

# Manager's must exist in the AD
$DAManager = (get-aduser -filter * | Get-Random).samaccountname
$HDManager = (get-aduser -filter * | Get-Random).samaccountname
$VIManager = (get-aduser -filter * | Get-Random).samaccountname

# User thumbnail Photo
$DAPhoto = "$PoSHPath\As2Go-admin.jpg"
$HDPhoto = "$PoSHPath\As2Go-helpdesk.jpg"
$VIPhoto = "$PoSHPath\As2Go-victim.jpg"

# Active Directory Security Groups
$VIGroup       = "SG-AS2Go-Victims"            # member of local admins on VICTIM PC
$HDGroup       = "SG-AS2Go-HelpDesk"           # member of local admins on ADMIN PC & VICTIM PC
$DAGroup       = "SG-AS2Go-Admins"             # member of local admins on ADMIN PC
$DomainAdmins  = (Get-ADGroup -Filter * | where {($_.SID -like "*-512")}).name
$ProtectedUser = (Get-ADGroup -Filter * | where {($_.SID -like "*-525")}).name

#define the user first & last name
$sFirstName = Get-Date -Format HHmmssff  # create the first name based on hours, minutes, seconds & milli seconds
$sLastname  = Get-Date -Format yyyyMMdd  # create the last name based on year, month, days

#Account expires after xx Days
$TimeSpan = New-TimeSpan -Days 7 -Hours 0 -Minutes 0

#Service to create SPN
$services = ("HTTPS","FTP","CIFS","kafka","MSSQL","POP3","HTTP")

Function New-AG2GoUserAccount()
{

param([string] $sUserPrincipalName, 
      [string] $sName, 
      [string] $sSamaccountName,  
      [string] $sFirstName, 
      [string] $sLastname, 
      [string] $sDisplayName, 
      [string] $sPath, 
      [SecureString] $secure_string_pwd)


New-aduser -UserPrincipalName $sUserPrincipalName -Name $sName -SamAccountName $sSamaccountName -PasswordNeverExpires $false -Path $sPath -AccountPassword $secure_string_pwd -PassThru | Enable-ADAccount


#additional attributes same for all

  $UserProperties = @{
  "mobile"            = Get-Date -Format HHmmssffff
  "telephoneNumber"   = Get-Date -Format HHmmssffff
  "employeenumber"    = Get-Date -Format HHmmssffff
  "GivenName"         = $sFirstName
  "sn"                = $sLastname
  "DisplayName"       = $sDisplayName
  "Company"           = "Herr Hozi INC."
  "Description"       = "AS2Go Dummy User"
  "c"                 = "DE"
  "countryCode"       = 276
  "co"                = "Germany"
  "l"                 = "somewhere in Germany"
  "wWWHomePage"       = "https://HerrHozi.com"
  "physicalDeliveryOfficeName" = "AS2Go Lab"
  }

sleep -Milliseconds 1000
Set-ADUser -Identity $sSamaccountName  -Replace $UserProperties 
Set-ADAccountExpiration -Identity $sSamaccountName -TimeSpan $TimeSpan
}

If ($Shortname -eq 'y')
{
   $sNewName = ($sLastname)
  
}
elseif ($Shortname -eq 'n')
{
   $sNewName = ($sLastname + "." + $sFirstName)
}
else
{
   $sNewName = $Shortname
}


$sNewUserPrincipalName = ($sNewName + $UPNSuffix)


Write-Host "`nStart creating 4 users for use case '$sNewName'. Accounts expire after $TimeSpan days`n" -ForegroundColo Yellow


if ($SkipVictim -eq $false)
  {
  # create Victim User (like VI-HerrHozi)
  # =========================================

  $sUserPrincipalName  = "VI-" + $sNewUserPrincipalName
  $sName               = $sNewName + "-VI"
  $sSamAccountName     = "VI-" + $sNewName
  $sDisplayName        = "Compromised Credentials ($sSamAccountName)"
  $bthumbnailPhoto     = $VIPhoto
  $sPath               = $AS2GoUser[2].Path

  New-AG2GoUserAccount -sUserPrincipalName $sUserPrincipalName -sName $sName -sSamaccountName $sSamAccountName -sFirstName $sFirstName -sLastname $sLastname -sDisplayName $sDisplayName -sPath $sPath -secure_string_pwd $VISecurePass
  $sName = $sSamAccountName

  Add-ADGroupMember -Identity $VIGroup -Members $sName
  Set-ADUser $sName -Replace @{thumbnailPhoto=([byte[]](Get-Content $bthumbnailPhoto -Encoding byte))} -Manager $VIManager -Initials "VI" -Title "Normal User" -Department "Tier 2"
  Write-Host "... created new user - $sName | Compromised User account (Victim)"
  }

  
if ($SkipHelpDesk -eq $false)
  {
  # create Helpdesk User (like HD-HerrHozi)
  # =========================================

  $sUserPrincipalName  = "HD-" + $sNewUserPrincipalName
  $sName               = $sNewName + "-HD"
  $sSamAccountName     = "HD-" + $sNewName
  $sDisplayName        = "Helpdesk User ($sSamAccountName)"
  $bthumbnailPhoto     = $HDPhoto
  $sPath               = $AS2GoUser[1].Path

  
  New-AG2GoUserAccount -sUserPrincipalName $sUserPrincipalName -sName $sName -sSamaccountName $sSamAccountName -sFirstName $sFirstName -sLastname $sLastname -sDisplayName $sDisplayName -sPath $sPath -secure_string_pwd $HDSecurePass
  $sName = $sSamAccountName
  Add-ADGroupMember -Identity $HDGroup  -Members $sName
  Set-ADUser $sName -Replace @{thumbnailPhoto=([byte[]](Get-Content $bthumbnailPhoto -Encoding byte))} -Manager $HDManager -Initials "HD" -Title "Helpdesk" -Department "Tier 1"
  Write-Host "... created new user - $sName | Helpdesk User"


  # additionally Helpdesk User (HD-HerrHoziP)
  # member of the protected users group
    
  $sUserPrincipalName  = "SVC-" + $sNewName + $UPNSuffix
  $sName               = $sNewName + "-SVC"
  $sSamAccountName     = "SVC-" + $sNewName
  $sDisplayName        = "Service Account ($sSamAccountName)"
  $bthumbnailPhoto     = $HDPhoto
  $sPath               = $AS2GoUser[0].SVCAccounts

  New-AG2GoUserAccount -sUserPrincipalName $sUserPrincipalName -sName $sName -sSamaccountName $sSamAccountName -sFirstName $sFirstName -sLastname $sLastname -sDisplayName $sDisplayName -sPath $sPath -secure_string_pwd $HDSecurePass
  $sName = $sSamAccountName
    Add-ADGroupMember -Identity $ProtectedUser -Members $sName
  Add-ADGroupMember -Identity $DomainAdmins  -Members $sName
  Set-ADUser $sName -Replace @{thumbnailPhoto=([byte[]](Get-Content $bthumbnailPhoto -Encoding byte))} -Manager $HDManager -Initials "HD" -Title "Helpdesk" -Department "Tier 0"
  Write-Host "... created new user - $sName | Service Account"
  
  #create new computer
  $NewComputer = "SRV-$sNewName"
  New-ADComputer -Name $NewComputer -Description "needed for Kerberoasting Attack" -Path $AS2GoUser[1].ComputerPath  -Location $sNewName -OperatingSystem "Windows 10 Enterprise"

  #set ServicePrincipalNames to a random service
  $service = $services | get-Random
  $NewSPN = "$service/$NewComputer"
  Set-ADUser -Identity $sName -ServicePrincipalNames @{Add=$NewSPN} 

  }

 
if ($SkipDomainAdmin -eq $false)
  {
  # create Domain Admin User (like DA-HerrHozi)
  # =============================================

  $sUserPrincipalName  = "DA-" + $sNewUserPrincipalName
  $sName               = $sNewName + "-DA"
  $sSamAccountName     = "DA-" + $sNewName
  $sDisplayName        = ("Domain Admin ($sSamAccountName)")
  $bthumbnailPhoto     = $DAPhoto
  $sPath               = $AS2GoUser[0].Path

  New-AG2GoUserAccount -sUserPrincipalName $sUserPrincipalName -sName $sName -sSamaccountName $sSamAccountName -sFirstName $sFirstName -sLastname $sLastname -sDisplayName $sDisplayName -sPath $sPath -secure_string_pwd $DASecurePass

  $sName = $sSamAccountName
  Add-ADGroupMember -Identity $DomainAdmins -Members $sName
  Add-ADGroupMember -Identity $DAGroup -Members $sName

  Set-ADUser $sName -Replace @{thumbnailPhoto=([byte[]](Get-Content $bthumbnailPhoto -Encoding byte))} -Manager $DAManager -Initials "DA" -Title "Domain Admin" -Department "Tier 0"
  Write-Host "... created new user - $sName | Domain Admin"

  #create new computer object
  $NewComputer = "PAW-$sNewName"
  New-ADComputer -Name $NewComputer -Description "needed for Kerberoasting Attack" -Path $AS2GoUser[0].ComputerPath  -Location $sNewName -OperatingSystem "Windows Server 2019 Standard"
  
  #set ServicePrincipalNames to a random service
  $service = $services | get-Random
  $NewSPN = "$service/$NewComputer"
  Set-ADUser -Identity $sName -ServicePrincipalNames @{Add=$NewSPN} 
  
  }



# SUMMMARY
# ========
$attributesU = @("samaccountname","servicePrincipalName","name","canonicalName","department")
$attributesC = @("samaccountname","servicePrincipalName","name","canonicalName","description")
 
Write-Host "`n`nSUMMARY for new User + Computer Objects:" -ForegroundColor Yellow
Write-Host     "========================================" -ForegroundColor Yellow

Get-ADComputer -LDAPFilter "(sAMAccountName=*-$sNewName*)" -Properties $attributesC | select $attributesC | ft
Get-ADUser     -LDAPFilter "(sAMAccountName=*$sNewName*)"   -Properties $attributesU | select $attributesU | ft

$NewUserAccounts = Get-ADUser -LDAPFilter "(sAMAccountName=*$sNewName*)" 
Foreach ($trustee in $NewUserAccounts)
{
  Write-Host $trustee.samAccountname "is now member of the following groups:" -ForegroundColor Yellow
  Get-ADPrincipalGroupMembership -Identity $trustee.samAccountname | ft name, GroupCategory, GroupScope, sid
}

$MyScript = $MyInvocation.MyCommand.Definition
$OnServer = " on server [" + [Environment]::machinename + "]" 
$byUser   = " by user [" + [Environment]::UserName + "]"
$UseCase  = " Usecase [" + $sNewName + "]"

Write-Host "`n`nReminder:" -ForegroundColor Yellow
Write-Host "If you changed the default password, do NOT forget to update the XML file!!!!!!!" -ForegroundColor Yellow

# update the log file
# ===================
" " | Out-File -FilePath $logfile -Append -Encoding default 
(Get-Date).ToString() + " last run: " + $MyScript + $onserver + $byUser + $UseCase  | Out-File -FilePath $logfile -Append -Encoding default 
Get-ADUser -LDAPFilter "(sAMAccountName=*$sNewName)" -Properties canonicalName, Created  | select sAMAccountName, Created, userPrincipalName, name, canonicalName | ft | Out-File -FilePath $logfile -Append -Encoding default

# update the dummy NTDS.DIT file
# ==============================
$NTDSDITFILE = "$PoSHPath\ntds.dit"
Get-ChildItem -Path c:\windows | Out-File -FilePath $NTDSDITFILE -Append -Encoding default 