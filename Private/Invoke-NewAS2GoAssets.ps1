<#
.SYNOPSIS
Creates the AS2Go tiered OU and group structure.

.FUNCTIONALITY
Builds the tiered OU/group layout and demo objects.
Moves privileged groups to Tier 0 and applies the lab ACLs.
#>
Function Invoke-NewAS2GoAssets {
    
    ################################################################################
    ######                                                                     #####
    ######   Creates the Tiering OU structure and Groups for the AS2Go         #####
    ######                                                                     #####
    ################################################################################
    
    param([string] $AS2GoOU = "AS2Go", [string] $Scenario = "AS2Go", [string] $UPNSuffix = "@mrhozi.com", [Parameter(Mandatory)][string]$Server)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
    If (-not $SkipClearHost) { Clear-Host }
    #get the Domain Root OU
    $ADRoot = Get-ADRootDSE
    $Domain = Get-ADDomain
    $RootOU = $ADRoot.defaultNamingContext
    $PDC = $Domain.PDCEmulator
    $logonServer = Get-LogonServerFQDN

    # define Tier Sub OUs
    $ouAccounts = "Accounts"
    $ouDevices = "Devices"
    $ouGroups = "Groups"
    $ouSvcAccounts = "Service Accounts"
    $ouServers = "Tier"

    $Tiers = @("0", "1", "2")
    $SubTierOus = @($ouAccounts, $ouGroups, $ouDevices, $ouSvcAccounts, $ouServers)

    # =========================================
    #     PSCustomObject AS2GoGroups
    # =========================================

    $VIGroup = "SG-$Scenario-Victims"            # member of local admins on VICTIM PC
    $HDGroup = "SG-$Scenario-HelpDesk"           # member of local admins on ADMIN PC & VICTIM PC
    $DAGroup = "SG-$Scenario-Admins"             # member of local admins on ADMIN PC

    $VIGroupDscpt = "needed for $Scenario | must be a member of local admins on VICTIM PC"
    $HDGroupDscpt = "needed for $Scenario | must be a member of local admins on ADMIN PC & VICTIM PC"
    $DAGroupDscpt = "needed for $Scenario | must be a member of local admins on ADMIN PC"

    $AS2GoGroups = @(
        [pscustomobject]@{Name = $DAGroup; Description = $DAGroupDscpt; Type = "AS2GoAdmins" }
        [pscustomobject]@{Name = $HDGroup; Description = $HDGroupDscpt; Type = "AS2GoHelpDesk" }
        [pscustomobject]@{Name = $VIGroup; Description = $VIGroupDscpt; Type = "AS2GoVictims" }
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
        [pscustomobject]@{Name = $Tier0; Description = $Tier0Dscpt }
        [pscustomobject]@{Name = $Tier1; Description = $Tier1Dscpt }
        [pscustomobject]@{Name = $Tier2; Description = $Tier2Dscpt }
    )

    ################################################################################
    ######                                                                     #####
    ######            Start creating Tiering OUs & Groups                      #####
    ######                                                                     #####
    ################################################################################
    
    Invoke-Output -T Header -Message "Start creating Tiering OUs & Groups ...."
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Invoke-Output -Type H1 -Message $Functionality

    $cname = Convert-FromDNToCN -DistinguishedName "$RootOU"
        
    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Using defaultNamingContext $cname"; Value = $Script:Yes },
        [pscustomobject] @{ Label = "&No"; Help = "Select a specific organizational unit or an entire domain."; Value = $Script:No }
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip this step."; Value = $Script:Skip }
    )
  
    $title = "The organizational unit '$AS2GoOU' will be created under '$Cname'." 
    $message = "Select 'Yes' to confirm, or 'No' to choose a different organizational unit.`n"
    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title    

    If ($answer -eq $Script:Skip) {
        return
    }

    If ($answer -eq $Script:No) {
        $RootOU = Select-ADObject -Title "Choose  parent OU for '$AS2GoOU'" -LocalDomainOnly
    }

    #Create Partent OU
    $check = $(Get-ADOrganizationalUnit -Filter { name -like $AS2GoOU } -SearchBase $RootOU -SearchScope OneLevel -Server $Server)

    Set-ASConfig -Setting "BDUsersOU"   -Value "OU=$AS2GoOU,$RootOU"

    If ($null -ne $check) {
        $Cname = Convert-FromDNToCN -DistinguishedName "$RootOU"
        Invoke-Output -T Warning -M "OU '$AS2GoOU' alreday exists under $Cname!"
        #return 
    } 
    Else {
        
        try {
            New-ADOrganizationalUnit -Name $AS2GoOU  -Path "$RootOU" -Description "AS2Go Assets" -PostalCode "AS2GoDemoAccounts" -ProtectedFromAccidentalDeletion:$false -Server $Server    
        }
        catch {
            $principal = "$env:USERDOMAIN\$env:USERNAME"
            Invoke-Output -type Error -Message "$_ | Affecting '$principal' on '$RootOU'"
            return
        }
        

        $Cname = Convert-FromDNToCN -DistinguishedName "OU=$AS2GoOU,$RootOU"
        Invoke-Output -T Textmaker -M "Created AS2GO OU:" -Tm $Cname
    
        New-ADOrganizationalUnit -Name "Demo Accounts" -Path "OU=$AS2GoOU,$RootOU" -Description "AS2Go Demo Accounts" -PostalCode "AS2GoDemoAccounts" -Server $Server
        $Cname = Convert-FromDNToCN -DistinguishedName "OU=Demo Accounts,OU=$AS2GoOU,$RootOU"
        Invoke-Output -T Textmaker -M "Created AS2GO OU:" -Tm $Cname
    }

    foreach ($Tier in $Tiers) {

        [int] $space = 30
        [int] $i = $Tier


        #Create Partent OU
        $name = $TieringOUName[$i].Name
        $check = $(Get-ADOrganizationalUnit -Filter { name -like $name } -SearchBase "OU=$AS2GoOU,$RootOU" -SearchScope OneLevel -Server $Server )

        If ($null -ne $check) {
            $Cname = Convert-FromDNToCN -DistinguishedName "OU=$AS2GoOU,$RootOU"
            Invoke-Output -T Success -M "OU '$($TieringOUName[$i].Name)' alreday exists under $Cname!"
            return 
        } 

        New-ADOrganizationalUnit -Name $TieringOUName[$i].Name -Path "OU=$AS2GoOU,$RootOU" -Description $TieringOUName[$i].Description -PostalCode "AS2GOTierung" -Server $Server 
        $ShortDNPAth = "OU=" + $TieringOUName[$i].Name + ",OU=$AS2GoOU,$RootOU"

        Invoke-Output -T Info -M "Creating Tier $Tier Assets ...."

        #Invoke-Output -T TextMaker -M "Created Parent OU" -Tm $TieringOUName[$i].Name

        Write-Host "   Created Parent OU " -NoNewline; Write-Host $TieringOUName[$i].Name -ForegroundColor Yellow

        foreach ($ou in $SubTierOus) {
    
            If ($ou -eq "Tier") {
                If ($Tier -eq "2") {
                    $newOU = "$ou $Tier Workstations"
                    $SrvPrefix = "PC"
                }
                else {
                    $newOU = "$ou $Tier Servers"
                    $SrvPrefix = "SRV"
                }
            }
            else { 
                $newOU = "T$i $ou" 
            }
    
            New-ADOrganizationalUnit -Name "$newOU"  -Path $ShortDNPAth -PostalCode "AS2GOTierung" -Server $Server 
            Write-Host "      Created Sub OU " -NoNewline; Write-Host ([string]$newOU).PadRight(20, ' ') -ForegroundColor Yellow -NoNewline

            Switch ($ou) {
                $ouAccounts { 
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier $ouAccounts" -PostalCode "AS2GOTierung" -Server $Server 
                    Write-Host ""
                }
  
                $ouGroups {
                    $newGroup = $AS2GoGroups[$i].Name
                    $exist = (Get-ADGroup -Filter * -Server $Server | Where-Object { $_.name -eq $newGroup } )
                    If ($null -ne $exist) {
                        Get-ADGroup -Filter * -Server $Server | Where-Object { $_.name -eq $newGroup } | Move-ADObject -TargetPath "OU=$newOU,$ShortDNPAth" -Server $Server 
                        Get-ADGroup -Filter * -Server $Server | Where-Object { $_.name -eq $newGroup } | Set-ADGroup -Description $AS2GoGroups[$i].Description -Server $Server 
                    }
                    else {
                        New-ADGroup -Name $newGroup -GroupScope Global -GroupCategory Security -Description $AS2GoGroups[$i].Description -Path "OU=$newOU,$ShortDNPAth" -OtherAttributes @{ 'adminDescription' = $AS2GoGroups[$i].Type } -ManagedBy $newUser -Server $Server 
                    }
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier $ouGroups" -PostalCode "AS2GOTierung" -Server $Server 
                    Write-Host ([string]" - including group:").PadRight($space, ' ') -NoNewline; Write-Host "$newGroup" -ForegroundColor Yellow
                }
                $ouDevices {
                    # create device e.g. ch10-MyT0Device
                    $NewComputer = "DEV-T" + $Tier + "-" + (Get-Date -Format HHmmssff)
                    New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=$newOU,$ShortDNPAth" -ManagedBy $newGroup -Server $Server 
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier $ouDevices" -Server $Server 
                    Write-Host ([string]" - including computer object:").PadRight($space, ' ') -NoNewline; Write-Host $NewComputer -ForegroundColor Yellow 
                }
                $ouSvcAccounts {
                    # create dummy service account e.g. - CH01-MyT0Admin
                    $SecurePass = ConvertTo-SecureString -String New-RandomPassword -AsPlainText -Force
                    $newUser = "SVC-T" + $Tier + "-" + (Get-Date -Format HHmmssff)
                    $UPN = $newUser + $UPNSuffix
                    New-ADUser -Name $newUser -UserPrincipalName  $UPN -SamAccountName $newUser  -PasswordNeverExpires $false  -AccountPassword $SecurePass -PassThru -Path "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier Service Account" -Server $Server  | Enable-ADAccount           
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier $ouSvcAccounts" -Server $Server 
                    Write-Host ([string]" - including service account:").PadRight($space, ' ') -NoNewline; Write-Host $newUser -ForegroundColor Yellow 
                }
                $ouServers {
                    # create dummy Server
                    $NewComputer = "$SrvPrefix-T" + $Tier + "-" + (Get-Date -Format HHmmssff)
                    New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=$newOU,$ShortDNPAth" -ManagedBy $newGroup -Server $Server 
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description $newOU -Server $Server 
                    Write-Host ([string]" - including computer object:").PadRight($space, ' ') -NoNewline; Write-Host $NewComputer -ForegroundColor Yellow 
                }
                Default {
                    Invoke-Output -type Warning -Message "Unable to determine value of $ou" 

                }
            } # end Switch
        } # foreach $SubTierOus
    } # foreach $Tier

    ################################################################################
    ######                                                                     #####
    ###### Move sensitive groups to Tier 0 Level, except 'Protected Users'     #####
    ######                                                                     #####
    ################################################################################


    Invoke-Output -T Header -Message "Move sensitive groups to Tier 0 Level, except the 'Protected Users' Group ...."

    Get-ADGroup -LDAPFilter "(adminCount=1)" -Properties * -Server $logonServer -SearchBase $ADRoot.defaultNamingContext | Where-Object {
        ($_.SID -like "*-512" -or 
        $_.SID -like "*-518" -or 
        $_.SID -like "*-519" -or 
        $_.SID -like "*-520")
    } | Move-ADObject -TargetPath ("OU=T0 $ouGroups,OU=" + $TieringOUName[0].Name + ",OU=$AS2GoOU,$RootOU")

    Get-ADGroup `
        -LDAPFilter "(adminCount=1)" `
        -SearchBase $ADRoot.DefaultNamingContext `
        -Server $LogonServer `
        -Properties sAMAccountName, canonicalName, objectSid |
    Where-Object {
        ($_.SID -like "*-512" -or 
        $_.SID -like "*-518" -or 
        $_.SID -like "*-519" -or 
        $_.SID -like "*-520" -or 
        $_.SID -like "*-525")
    } | Select-Object sAMAccountName, canonicalName | Format-Table -AutoSize



    ################################################################################
    ######                                                                     #####
    ######  Adding AS2Go Groups to Local Admins                                #####
    ######                                                                     #####
    ################################################################################

    Invoke-Output -T Header -Message "Adding AS2Go Groups to Local Admins on this machine ...."

    $DomainNetBIOS = $Domain.NetBIOSName

    foreach ($group in @($HDGroup, $VIGroup)) {
        try {
            Add-LocalGroupMember -Group "Administrators" -Member "$DomainNetBIOS\$group" -ErrorAction Stop
            Invoke-Output -T Success -M "Added '$group' to local Administrators on $env:COMPUTERNAME" -noExtraLines
        }
        catch [Microsoft.PowerShell.Commands.MemberExistsException] {
            Invoke-Output -T Warning -M "'$group' is already a member of local Administrators"
        }
        catch {
            Invoke-Output -T Warning -M "Failed to add '$group': $_"
        }
    }

    try {
        $DA = $Domain.domainSID.Value + "-512"
        $computerSam = "$env:COMPUTERNAME$"
        Add-ADGroupMember -Identity $DA -Members $computerSam -Server $logonServer -ErrorAction SilentlyContinue
    }
    catch {
        <#Do this if a terminating exception happens#>
    }




    ################################################################################
    ######                                                                     #####
    ######  Finally set DENY Right for SG-AS2Go-Victims on TIER 0 Level        #####
    ######                                                                     #####
    ################################################################################

    Disable-ADOUInheritance -TargetDN ("OU=" + $TieringOUName[0].Name + ",OU=$AS2GoOU,$RootOU") -LogonServer $logonServer
    Set-DenyPermission -TargetDN "OU=T0 Groups,OU=$($TieringOUName[0].Name),OU=$AS2GoOU,$RootOU" -Trustee  $AS2GoGroups[2].Name -LogonServer $logonServer

    Invoke-Output -T Success -Message "Finished creating Tiering OUs & Groups!"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
