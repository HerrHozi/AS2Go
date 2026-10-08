<#
.SYNOPSIS

Attack scenario to GO - along the kill-chain (AS2Go)

Requirements:

- Active Direcory PowerShell

.DESCRIPTION


AS2Go is an acronym for Attack Scenario To Go. 
This PoSH script creates the OU structure, the 3 mandotory group,
moves the groups into the corresponding OUs and set the DENY permissions on the TIER 0 assets


.NOTES

last update: 2022-12-01
File Name  : New-AS2GoOUs.ps1 | Version 2.6.0
Author     : Holger Zimmermann | @HerrHozi
https://herrhozi.com

.EXAMPLE

PS> cd C:\temp\AS2GO
PS> .\New-AS2GoOUs.ps1


.LINK
https://herrHoZi.com

#>



#Requires -RunAsAdministrator

param([string] $AS2GoOU="AS2Go", [string] $acronym="AS2Go", [string] $sUPNSuffix="@mrhozi.com")


#get the Domain Roout OU
$ADRoot = Get-ADRootDSE
$Domain = Get-ADDomain
$RootOU = $ADRoot.defaultNamingContext
$PDC    = $Domain.PDCEmulator

# define Target Ou
$AS2GoOU = "AS2Go"
$acronym = "AS2Go"

# define Tier Sub OUs
$ouAccounts     = "Accounts"
$ouDevices      = "Devices"
$ouGroups       = "Groups"
$ouSvcAccounts  = "Service Accounts"
$ouServers      = "Tier"

$Tiers      = @("0", "1", "2")
$SubTierOus = @($ouAccounts,$ouGroups,$ouDevices,$ouSvcAccounts,$ouServers)


# =========================================
#     PSCustomObject AS2GoGroups
# =========================================

$VIGroup = "SG-$acronym-Victims"            # member of local admins on VICTIM PC
$HDGroup = "SG-$acronym-HelpDesk"           # member of local admins on ADMIN PC & VICTIM PC
$DAGroup = "SG-$acronym-Admins"             # member of local admins on ADMIN PC

$VIGroupDscpt = "needed for $acronym | must be a member of local admins on VICTIM PC"
$HDGroupDscpt = "needed for $acronym | must be a member of local admins on ADMIN PC & VICTIM PC"
$DAGroupDscpt = "needed for $acronym | must be a member of local admins on ADMIN PC"


 $AS2GoGroups = @(
       [pscustomobject]@{Name = $DAGroup; Description = $DAGroupDscpt}
       [pscustomobject]@{Name = $HDGroup; Description = $HDGroupDscpt}
       [pscustomobject]@{Name = $VIGroup; Description = $VIGroupDscpt}
   )


# =========================================
#       PSCustomObject $TieringOUName
# =========================================

$Tier0 = "Tier 0 Assets"            
$Tier1 = "Tier 1 Assets"            
$Tier2 = "Tier 2 Assets"           

$Tier0Dscpt = "Tier 0 Assets"
$Tier1Dscpt = "Tier 1 Assets"
$Tier2Dscpt = "Tier 2 Assets"


 $TieringOUName = @(
       [pscustomobject]@{Name = $Tier0; Description = $Tier0Dscpt}
       [pscustomobject]@{Name = $Tier1; Description = $Tier1Dscpt}
       [pscustomobject]@{Name = $Tier2; Description = $Tier2Dscpt}
   )


# =========================================
#          Function New-RandomPassword
# =========================================

Function New-RandomPassword { 

$Hozi   = "HERRHOZI".ToCharArray()
$chars  = "abcdefghijkmnopqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ1234567890".ToCharArray()
$nums   = "1234567890".ToCharArray()
$schars = "+-$!".ToCharArray()

$newPassword = ""
1..9 | ForEach {  $newPassword += $chars | Get-Random }
1..1 | ForEach {  $newPassword += $nums | Get-Random }
1..1 | ForEach {  $newPassword += $schars | Get-Random }
1..1 | ForEach {  $newPassword += $nums | Get-Random }
1..1 | ForEach {  $newPassword += $schars | Get-Random }
1..1 | ForEach {  $newPassword += $Hozi | Get-Random }
return $newPassword
}


################################################################################
######                                                                     #####
######            Start creating Tiering OUs & Groups                      #####
######                                                                     #####
################################################################################

Write-Host "Start creating Tiering OUs & Groups ....`n"

#Create Partent OU
$check = $(Get-ADOrganizationalUnit -Filter {name -like $AS2GoOU} -SearchBase $RootOU -SearchScope OneLevel)

If ($check -ne $null){
   Write-Warning "OU '$AS2GoOU' alreday exists in your domain!" 
   Write-Host "`nProbably you run AS2Go v2.x before. This is no problem!`n"
   pause
} 
Else {
   New-ADOrganizationalUnit -Name $AS2GoOU  -Path "$RootOU" -Description "AS2Go Assets"  -ErrorAction SilentlyContinue -ProtectedFromAccidentalDeletion:$false
   Write-Host "`n  Created Parent OU " -NoNewline;Write-Host "OU=$AS2GoOU,$RootOU" -ForegroundColor Yellow -NoNewline
}

foreach ($Tier in $Tiers) {

[int] $space = 30
[int] $i = $Tier


New-ADOrganizationalUnit -Name $TieringOUName[$i].Name   -Path "OU=$AS2GoOU,$RootOU" -Description $TieringOUName[$i].Description

$ShortDNPAth = "OU="+$TieringOUName[$i].Name+",OU=$AS2GoOU,$RootOU"

Write-Host "`n`n   Creating Tier $Tier Assets ....`n" -ForegroundColor Yellow 

Write-Host "    Created Parent OU " -NoNewline;Write-Host $TieringOUName[$i].Name -ForegroundColor Yellow

  foreach ($ou in $SubTierOus) 
  {
    
   If ($ou -eq "Tier") 
    {
      If ($Tier -eq "2") {
        $newOU = "$ou $Tier Workstations"
        $SrvPrefix = "PC"
        }
      else {
        $newOU = "$ou $Tier Servers"
        $SrvPrefix = "SRV"
        }
    }
    else 
    {$newOU = $ou}
    
    New-ADOrganizationalUnit -Name "$newOU"  -Path $ShortDNPAth
    Write-Host "      Created Sub OU " -NoNewline;Write-Host ([string]$newOU).PadLeft(20,' ') -ForegroundColor Yellow -NoNewline

  Switch ($ou)
  {
   $ouAccounts 
   { 
     Set-ADOrganizationalUnit -Identity "OU=$ouAccounts,$ShortDNPAth" -Description "Tier $Tier $ouAccounts" 
     Write-Host ""
   }
  
   $ouGroups 
   {
     # create group e.g. - CH01-MyTier0Admins
     #get-ADGroup -Filter * | Where-Object -Property name -eq $VIGroup
     $newGroup = $AS2GoGroups[$i].Name
     $exist = (Get-ADGroup -Filter * | where {$_.name -eq $newGroup})
     If ($exist -ne $null){
        Get-ADGroup -Filter * | where {$_.name -eq $newGroup} | Move-ADObject -TargetPath "OU=$ouGroups,$ShortDNPAth"
        Get-ADGroup -Filter * | where {$_.name -eq $newGroup} | Set-ADGroup -Description $AS2GoGroups[$i].Description
     }
     else
     {
       New-ADGroup -Name $newGroup -GroupScope Global -GroupCategory Security -Description $AS2GoGroups[$i].Description -Path "OU=$ouGroups,$ShortDNPAth" -ManagedBy $newUser
     }
     Set-ADOrganizationalUnit -Identity "OU=$ouGroups,$ShortDNPAth" -Description "Tier $Tier $ouGroups"
     Write-Host ([string]" - including group:").PadRight($space,' ') -NoNewline; Write-Host "$newGroup" -ForegroundColor Yellow
   }
   $ouDevices
   {
     
     # create device e.g. ch10-MyT0Device
     $NewComputer = "DEV-T"+ $Tier+ "-" + (Get-Date -Format HHmmssff)
     New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=Devices,$ShortDNPAth" -ManagedBy $newGroup
     Set-ADOrganizationalUnit -Identity "OU=Devices,$ShortDNPAth" -Description "Tier $Tier $ouDevices"
     Write-Host ([string]" - including computer object:").PadRight($space,' ') -NoNewline; Write-Host $NewComputer -ForegroundColor Yellow 
   }
   $ouSvcAccounts
   {
     # create dummy service account e.g. - CH01-MyT0Admin
     $SecurePass = ConvertTo-SecureString -String New-RandomPassword -AsPlainText -Force
     $newUser = "SVC-T"+ $Tier+ "-" + (Get-Date -Format HHmmssff)
     $UPN = $newUser + $sUPNSuffix
     New-ADUser -Name $newUser -UserPrincipalName  $UPN -SamAccountName $newUser  -PasswordNeverExpires $false  -AccountPassword $SecurePass -PassThru -Path "OU=$ouSvcAccounts,$ShortDNPAth" -Description "Tier $Tier Service Account" | Enable-ADAccount           
     Set-ADOrganizationalUnit -Identity "OU=$ouSvcAccounts,$ShortDNPAth" -Description "Tier $Tier $ouSvcAccounts"
     Write-Host ([string]" - including service account:").PadRight($space,' ') -NoNewline; Write-Host $newUser -ForegroundColor Yellow 
   }
   $ouServers
   {
     # create dummy Server
     $NewComputer = "$SrvPrefix-T"+ $Tier+ "-" + (Get-Date -Format HHmmssff)
     New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=$newOU,$ShortDNPAth" -ManagedBy $newGroup
     Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description $newOU
     Write-Host ([string]" - including computer object:").PadRight($space,' ') -NoNewline; Write-Host $NewComputer -ForegroundColor Yellow 
   }
   Default 
   { 
     Write-Warning "unable to determine value of $ou"
   }
  } # end Switch
 } # foreach $SubTierOus
} # foreach $Tier




################################################################################
######                                                                     #####
###### Move sensitive groups to Tier 0 Level, except 'Protected Users'     #####
######                                                                     #####
################################################################################

Write-host "`n`nMoving sensitive groups to Tier 0 Level, except the 'Protected Users' Group" -ForegroundColor yellow


Get-ADGroup -Filter * -Properties * | where {
    ($_.SID -like "*-512" -or 
     $_.SID -like "*-518" -or 
     $_.SID -like "*-519" -or 
     $_.SID -like "*-520")
    } | Move-ADObject -TargetPath ("OU=$ouGroups,OU="+$TieringOUName[0].Name+",OU=$AS2GoOU,$RootOU")


Get-ADGroup -Filter * -Properties * | where {
    ($_.SID -like "*-512" -or 
     $_.SID -like "*-518" -or 
     $_.SID -like "*-519" -or 
     $_.SID -like "*-520" -or 
     $_.SID -like "*-525")
    } | select sAMAccountName, canonicalName | ft 



################################################################################
######                                                                     #####
######  Finally set DENY Right for SG-AS2Go-Victims on TIER 0 Level        #####
######                                                                     #####
################################################################################



$OUdn = ("OU=Groups,OU="+$TieringOUName[0].Name+",OU=$AS2GoOU,$RootOU")
$group = $AS2GoGroups[2].name

Write-Host "Finally set DENY permission on $OUdn for $group" -ForegroundColor yellow -NoNewline

$acl = get-acl "AD:$($OUdn)"
#$acl.access # list access right of the OU
$trustee = get-adgroup $group
$sid = [System.Security.Principal.SecurityIdentifier] $trustee.SID
 
# Create a new access control entry to allow access to the OU
$identity        = [System.Security.Principal.IdentityReference] $SID
$adRights        = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
$type            = [System.Security.AccessControl.AccessControlType] "DENY"
$inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
 
$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType
 
# Add the ACE to the ACL, then set the ACL to save the changes
$acl.AddAccessRule($ace)
Set-acl -aclobject $acl "AD:$($OUdn)"

Write-Host " - Done!`n" -ForegroundColor Green
