<#
.SYNOPSIS
Creates the AS2Go tiered OU and group structure.

.DESCRIPTION
Builds the tiered organizational units and groups, provisions demo objects, moves privileged
groups to Tier 0, and applies the lab permissions.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Builds the tiered OU/group layout and demo objects.
Moves privileged groups to Tier 0 and applies the lab ACLs.
#>
Function Initialize-AS2GoAssets {
    
    ################################################################################
    ######                                                                     #####
    ######   Creates the Tiering OU structure and Groups for the AS2Go         #####
    ######                                                                     #####
    ################################################################################
    
    param(
        [string] $AS2GoOU = "AS2Go", 
        [string] $Scenario = "AS2Go", 
        [string] $UPNSuffix = "@mrhozi.com", 
        [Parameter(Mandatory)]
        [string]$Server
    )

    $Info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $Info.FunctionName
    If (-not $SkipClearHost) { Clear-Host }
    #get the Domain Root OU
    $ADRoot = Get-ADRootDSE
    $Domain = Get-ADDomain
    $RootOU = $ADRoot.defaultNamingContext
    $PDC = $Domain.PDCEmulator
    #$Server = Get-LogonServerFQDN

    # define Tier Sub OUs
    $ouAccounts = "Accounts"
    $ouDevices = "Devices"
    $ouGroups = "Groups"
    $ouSvcAccounts = "ServiceAccounts"
    $ouServers = "Servers"

    $Tiers = @("0", "1", "2")
    $SubTierOus = @($ouAccounts, $ouGroups, $ouDevices, $ouSvcAccounts, $ouServers)

    # =========================================
    #     PSCustomObject AS2GoGroups
    # =========================================

    #$VIGroup = "SG-$Scenario-Victims"            # member of local admins on VICTIM PC
    #$HDGroup = "SG-$Scenario-HelpDesk"           # member of local admins on ADMIN PC & VICTIM PC
    #$DAGroup = "SG-$Scenario-Admins"             # member of local admins on ADMIN PC

    $VIGroup = "SG-$Scenario-Users"            # member of local admins on VICTIM PC
    $HDGroup = "SG-$Scenario-T2-Admins"        # member of local admins on ADMIN PC & VICTIM PC
    $SAGroup = "SG-$Scenario-T1-Admins"
    $DAGroup = "SG-$Scenario-T0-Admins"        # member of local admins on ADMIN PC
    $EAGroup = "UG-$Scenario-T0-Enterprise"

    $VIGroupDscpt = "needed for $Scenario | must be a member of local admins on VICTIM PC"
    $HDGroupDscpt = "needed for $Scenario | must be a member of local admins on ADMIN PC & VICTIM PC"
    $DAGroupDscpt = "needed for $Scenario | must be a member of local admins on ADMIN PC"

    $AS2GoGroups = @(
        [pscustomobject]@{ Name = $DAGroup; Tier = "0"; Scope = "Global"; Description = $DAGroupDscpt; Type = "AS2GoAdmins" }
        [pscustomobject]@{ Name = $EAGroup; Tier = "0"; Scope = "Universal"; Description = "Tier 0 enterprise role for $Scenario"; Type = "AS2GoAdmins" }
        [pscustomobject]@{ Name = $SAGroup; Tier = "1"; Scope = "Global"; Description = "Tier 1 server administration role for $Scenario"; Type = "AS2GoAdmins" }
        [pscustomobject]@{ Name = $HDGroup; Tier = "2"; Scope = "Global"; Description = $HDGroupDscpt; Type = "AS2GoHelpDesk" }
        [pscustomobject]@{ Name = $VIGroup; Tier = "2"; Scope = "Global"; Description = $VIGroupDscpt; Type = "AS2GoVictims" }
    )
    $DeviceManagerByTier = @{ "0" = $DAGroup; "1" = $SAGroup; "2" = $VIGroup }

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
    
    Write-AS2GoOutput -Type  Header -Message "Start creating Tiering OUs & Groups ...."
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality

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
        $RootOU = Select-ADObject -Title "Select or create  parent OU for '$AS2GoOU'" -LocalDomainOnly -AddOU
    }

    If ($null -eq $RootOU) {
        return
    }

    #Create Partent OU
    $check = $(Get-ADOrganizationalUnit -Filter { name -like $AS2GoOU } -SearchBase $RootOU -SearchScope OneLevel -Server $Server)

    Set-ASConfig -Setting "BDUsersOU"   -Value "OU=$AS2GoOU,$RootOU"

    If ($null -ne $check) {
        $Cname = Convert-FromDNToCN -DistinguishedName "$RootOU"
        Write-AS2GoOutput -Type  Warning -M "OU '$AS2GoOU' alreday exists under $Cname!"
        #return 
    } 
    Else {
        
        try {
            New-ADOrganizationalUnit -Name $AS2GoOU  -Path "$RootOU" -Description "AS2Go Assets" -PostalCode "AS2GoDemoAccounts" -ProtectedFromAccidentalDeletion:$false -Server $Server    
        }
        catch {
            $principal = "$env:USERDOMAIN\$env:USERNAME"
            Write-AS2GoOutput -type Error -Message "$_ | Affecting '$principal' on '$RootOU'"
            return
        }
        

        $Cname = Convert-FromDNToCN -DistinguishedName "OU=$AS2GoOU,$RootOU"
        Write-Host ""
        Write-AS2GoOutput -Type  Textmaker -M "Created AS2GO OU:" -Tm $Cname -NoExtraLines
    
        New-ADOrganizationalUnit -Name "Demo Accounts" -Path "OU=$AS2GoOU,$RootOU" -Description "AS2Go Demo Accounts" -PostalCode "AS2GoDemoAccounts" -Server $Server
        $Cname = Convert-FromDNToCN -DistinguishedName "OU=Demo Accounts,OU=$AS2GoOU,$RootOU"
        Write-AS2GoOutput -Type  Textmaker -M "Created AS2GO OU:" -Tm $Cname -NoExtraLines
    }

    $ExistingTierFound = $false
    foreach ($Tier in $Tiers) {

        [int] $space = 30
        [int] $i = $Tier


        #Create Partent OU
        $name = $TieringOUName[$i].Name
        $TierOU = Get-ADOrganizationalUnit -Filter { Name -eq $name } -SearchBase "OU=$AS2GoOU,$RootOU" -SearchScope OneLevel -Server $Server -ErrorAction Stop
        $TierSubOUs = $SubTierOus

        if ($null -ne $TierOU) {
            Write-AS2GoOutput -Type Info -Message "OU '$name' already exists. Checking its scenario groups."
            $ExistingTierFound = $true
            $TierSubOUs = @($ouGroups)
        }
        else {
            New-ADOrganizationalUnit -Name $name -Path "OU=$AS2GoOU,$RootOU" -Description $TieringOUName[$i].Description -PostalCode "AS2GOTierung" -Server $Server -ErrorAction Stop
            Write-AS2GoOutput -Type Info -Message "Created Tier $Tier Assets."
        }
        $ShortDNPAth = "OU=" + $TieringOUName[$i].Name + ",OU=$AS2GoOU,$RootOU"
        $DeviceManager = $DeviceManagerByTier[$Tier]

        foreach ($ou in $TierSubOUs) {
    
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
    
            $ExistingSubOU = $null
            if ($null -ne $TierOU) {
                $ExistingSubOU = Get-ADOrganizationalUnit -Filter { Name -eq $newOU } -SearchBase $ShortDNPAth -SearchScope OneLevel -Server $Server -ErrorAction Stop
            }
            if ($null -eq $ExistingSubOU) {
                New-ADOrganizationalUnit -Name $newOU -Path $ShortDNPAth -PostalCode "AS2GOTierung" -Server $Server -ErrorAction Stop
                Write-Host "      Created Sub OU " -NoNewline; Write-Host ([string]$newOU).PadRight(20, ' ') -ForegroundColor Yellow -NoNewline
            }
            else {
                Write-Host "      Found Sub OU   " -NoNewline; Write-Host ([string]$newOU).PadRight(20, ' ') -ForegroundColor Yellow -NoNewline
            }

            Switch ($ou) {
                $ouAccounts { 
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description "Tier $Tier $ouAccounts" -PostalCode "AS2GOTierung" -Server $Server 
                    
                    if ($newOU -eq "T0 Accounts") {
                        Set-ASConfig -Setting "T0AccountsOU" -Value "OU=$newOU,$ShortDNPAth"
                    }
                    elseif ($newOU -eq "T1 Accounts") {
                        Set-ASConfig -Setting "T1AccountsOU" -Value "OU=$newOU,$ShortDNPAth"
                    }
                    elseif ($newOU -eq "T2 Accounts") {
                        Set-ASConfig -Setting "T2AccountsOU" -Value "OU=$newOU,$ShortDNPAth"
                    }
                                      
                    
                    
                    
                    
                    
                    Write-Host ""
                }
  
                $ouGroups {
                    $GroupOU = "OU=$newOU,$ShortDNPAth"
                    foreach ($GroupDefinition in ($AS2GoGroups | Where-Object Tier -eq $Tier)) {
                        $GroupName = $GroupDefinition.Name
                        $ExistingGroup = Get-ADGroup -Filter { SamAccountName -eq $GroupName } -Properties adminDescription -Server $Server -ErrorAction Stop
                        if ($null -eq $ExistingGroup) {
                            New-ADGroup -Name $GroupName -SamAccountName $GroupName -GroupScope $GroupDefinition.Scope -GroupCategory Security -Description $GroupDefinition.Description -Path $GroupOU -OtherAttributes @{ 'adminDescription' = $GroupDefinition.Type } -Server $Server -ErrorAction Stop
                            if ($GroupName.EndsWith("-T0-Enterprise")) {
                                Set-ASConfig -Setting "EAGroup" -Value $GroupName
                            }
                            elseif ($GroupName.EndsWith("-T0-Admins")) {
                                Set-ASConfig -Setting "DAGroup" -Value $GroupName
                            }
                            elseif ($GroupName.EndsWith("-T1-Admins")) {
                                Set-ASConfig -Setting "SAGroup" -Value $GroupName
                            }
                            elseif ($GroupName.EndsWith("-T2-Admins")) {
                                Set-ASConfig -Setting "HDGroup" -Value $GroupName
                            }
                            else {
                                Set-ASConfig -Setting "VIGroup" -Value $GroupName
                            }

                            continue
                        }
                        if ($ExistingGroup.Name -ne $GroupName -or $ExistingGroup.adminDescription -ne $GroupDefinition.Type -or
                            $ExistingGroup.GroupScope -ne $GroupDefinition.Scope -or $ExistingGroup.GroupCategory -ne "Security") {
                            throw "Existing group '$GroupName' does not match the expected AS2Go name, role, scope, or category."
                        }

                        $GroupInTargetOU = Get-ADGroup -Filter { SamAccountName -eq $GroupName } -SearchBase $GroupOU -SearchScope OneLevel -Server $Server -ErrorAction Stop
                        if ($null -eq $GroupInTargetOU) {
                            Move-ADObject -Identity $ExistingGroup.DistinguishedName -TargetPath $GroupOU -Server $Server -ErrorAction Stop
                        }
                    }
                    if ($null -eq $ExistingSubOU) {
                        Set-ADOrganizationalUnit -Identity $GroupOU -Description "Tier $Tier $ouGroups" -Server $Server
                    }
                    Write-Host " - scenario groups verified" -ForegroundColor Yellow
                }
                $ouDevices {
                    # create device e.g. ch10-MyT0Device
                    $NewComputer = "DEV-T" + $Tier + "-" + (Get-Date -Format HHmmssff)
                    New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=$newOU,$ShortDNPAth" -ManagedBy $DeviceManager -Server $Server
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
                    
                    if ($newOU -eq "T0 ServiceAccounts") {
                        Set-ASConfig -Setting "T0ServiceAccountsOU" -Value "OU=$newOU,$ShortDNPAth"
                    }
                }
                $ouServers {
                    # create dummy Server
                    $NewComputer = "$SrvPrefix-T" + $Tier + "-" + (Get-Date -Format HHmmssff)
                    New-ADComputer -Name $NewComputer -Description "Tier $Tier Device" -Path "OU=$newOU,$ShortDNPAth" -ManagedBy $DeviceManager -Server $Server
                    Set-ADOrganizationalUnit -Identity "OU=$newOU,$ShortDNPAth" -Description $newOU -Server $Server 
                    Write-Host ([string]" - including computer object:").PadRight($space, ' ') -NoNewline; Write-Host $NewComputer -ForegroundColor Yellow 
                }
                Default {
                    Write-AS2GoOutput -type Warning -Message "Unable to determine value of $ou" 

                }
            } # end Switch
        } # foreach $SubTierOus
    } # foreach $Tier

    if ($ExistingTierFound) {
        Write-AS2GoOutput -Type Success -Message "Finished checking the tiered scenario groups."
        Measure-FunctionRuntime -End -Details $Info
        return
    }





    ################################################################################
    ######                                                                     #####
    ######  Adding AS2Go Groups to Local Admins                                #####
    ######                                                                     #####
    ################################################################################

    Write-AS2GoOutput -Type  Header -Message "Adding AS2Go Groups to Local Admins on this machine ...."

    $DomainNetBIOS = $Domain.NetBIOSName

    foreach ($group in @($HDGroup, $VIGroup)) {
        try {
            Add-LocalGroupMember -Group "Administrators" -Member "$DomainNetBIOS\$group" -ErrorAction Stop
            Write-AS2GoOutput -Type  Success -M "Added '$group' to local Administrators on $env:COMPUTERNAME" -noExtraLines
        }
        catch [Microsoft.PowerShell.Commands.MemberExistsException] {
            Write-AS2GoOutput -Type  Warning -M "'$group' is already a member of local Administrators"
        }
        catch {
            Write-AS2GoOutput -Type  Warning -M "Failed to add '$group': $_"
        }
    }

    try {
        $DA = $Domain.domainSID.Value + "-512"
        $computerSam = "$env:COMPUTERNAME$"
        Add-ADGroupMember -Identity $DA -Members $computerSam -Server $Server -ErrorAction SilentlyContinue
    }
    catch {
        <#Do this if a terminating exception happens#>
    }


    ################################################################################
    ######                                                                     #####
    ###### Adding AS2Go Groups to Enterprise Admins, Domain Admins & Server Ops#####
    ######                                                                     #####
    ################################################################################

    #SG-$Scenario-T0-Admins --> add to -512 (Domain Admins | Current Domain)
    #SG-$Scenario-T1-Admins --> add to -549 (Server Operators)
    #UG-$Scenario-T0-Enterprise --> add to -519 (Enterprise Admins | Root Domain)

    $DomainAdminsSID = $Domain.DomainSid.Value + "-512"
    $ServerOperatorsSID = "S-1-5-32-549"

    $RootDC = Get-BestDomainController -Domain ((Get-ADForest).RootDomain)
    $EnterpriseAdminsSID = (Get-ADDomain -Server $RootDC).DomainSid.Value + "-519"

    Write-AS2GoOutput -Type Header -Message "Adding AS2Go groups to Domain Admins, Server Operators & Enterprise Admins ...."

    $Nestings = @(
        [pscustomobject]@{ Name = $DAGroup; Parent = "Domain Admins"; ParentSID = $DomainAdminsSID; Server = $Server }
        [pscustomobject]@{ Name = $SAGroup; Parent = "Server Operators"; ParentSID = $ServerOperatorsSID; Server = $Server }
        [pscustomobject]@{ Name = $EAGroup; Parent = "Enterprise Admins"; ParentSID = $EnterpriseAdminsSID; Server = $RootDC }
    )

    foreach ($Nesting in $Nestings) {

        $MemberDN = (Get-ADGroup -Identity $Nesting.Name -Server $Server).DistinguishedName
        $ParentGroup = Get-ADGroup -Identity $Nesting.ParentSID -Server $Nesting.Server -Properties member

        if ($ParentGroup.member -contains $MemberDN) {
            Write-AS2GoOutput -Type Warning -M "'$($Nesting.Name)' is already a member of the '$($Nesting.Parent)' group" -NoExtraLines
            continue
        }

        try {
            if ($Nesting.Server -eq $Server) {
                Add-ADGroupMember -Identity $Nesting.ParentSID -Members $Nesting.Name -Server $Nesting.Server -ErrorAction Stop
            }
            else {
                # Cross-domain nesting (Enterprise Admins on the root DC): write the member attribute directly
                Start-Sleep -Seconds 10
                Set-ADGroup -Identity $ParentGroup.DistinguishedName -Add @{ member = $MemberDN } -Server $Nesting.Server -ErrorAction Stop
            }
            Write-AS2GoOutput -Type Success -M "Added '$($Nesting.Name)' to the '$($Nesting.Parent)' group" -NoExtraLines
        }
        catch {
            Write-AS2GoOutput -Type Warning -M "Failed to add '$($Nesting.Name)' to the '$($Nesting.Parent)' group: $_"
        }
    }

    ################################################################################
    ######                                                                     #####
    ######  Finally set the deny permission for scenario users in Tier 0      #####
    ######                                                                     #####
    ################################################################################

    Disable-ADOUInheritance -TargetDN ("OU=" + $TieringOUName[0].Name + ",OU=$AS2GoOU,$RootOU") -LogonServer $Server
    Set-DenyPermission -TargetDN "OU=T0 Groups,OU=$($TieringOUName[0].Name),OU=$AS2GoOU,$RootOU" -Trustee $VIGroup -LogonServer $Server

    Write-AS2GoOutput -Type  Success -Message "Finished creating Tiering OUs & Groups!"
    Measure-FunctionRuntime -End -Details $Info


    ################################################################################
    ######                                                                     #####
    ###### Move sensitive groups to Tier 0 Level, except 'Protected Users'     #####
    ######                                                                     #####
    ################################################################################

    $Dn = "OU=T0 $ouGroups,OU=" + $TieringOUName[0].Name + ",OU=$AS2GoOU,$RootOU"

    $CN = Convert-FromDNToCN -DistinguishedName $Dn 

    Write-AS2GoOutput -Type  Header -Message "Move sensitive groups to Tier 0 Assets -T0 Groups"
    Write-AS2GoOutput -Type Info -Message "Restrict visibility of group membership for AS2Go users (SG-Lotte9-Users)."


    
    $Options = @(
        [pscustomobject] @{
            Label = "&Yes"
            Help  = "Target OU $CN"
            Value = $Script:Yes
        },
        [pscustomobject] @{
            Label = "&No"
            Help  = "Do not move sensitive groups to Tier 0"
            Value = $Script:No
        }
    )

    $answer = Show-DecisionPrompt -Options $Options -Default 1

    If ($answer -eq $Script:Yes) {


        Get-ADGroup -LDAPFilter "(adminCount=1)" -Properties * -Server $Server -SearchBase $ADRoot.defaultNamingContext | Where-Object {
            ($_.SID -like "*-512" -or 
            $_.SID -like "*-518" -or 
            $_.SID -like "*-519" -or 
            $_.SID -like "*-520")
        } | Move-ADObject -TargetPath ("OU=T0 $ouGroups,OU=" + $TieringOUName[0].Name + ",OU=$AS2GoOU,$RootOU")

        Get-ADGroup `
            -LDAPFilter "(adminCount=1)" `
            -SearchBase $ADRoot.DefaultNamingContext `
            -Server $Server `
            -Properties sAMAccountName, canonicalName, objectSid |
        Where-Object {
            ($_.SID -like "*-512" -or 
            $_.SID -like "*-518" -or 
            $_.SID -like "*-519" -or 
            $_.SID -like "*-520" -or 
            $_.SID -like "*-525")
        } | Select-Object sAMAccountName, canonicalName | Format-Table -AutoSize

    }
}
