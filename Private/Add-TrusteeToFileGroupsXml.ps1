function Add-TrusteeToFileGroupsXml {

    ################################################################################
    #####                                                                      ##### 
    #####    Add a Trustee incl. SID to the Groups.xml file                    #####                                
    #####                                                                      #####
    ################################################################################

    Param([string] $xmlFilePath, [string] $LocalGroup, [string] $Trustee, [string] $SID)

    $Info = Measure-FunctionRuntime -Begin

    If (!(Test-Path $xmlFilePath)) {
        Write-AS2GoOutput -Type Error -Message "File Groups.xml not found at $xmlFilePath - cannot add trustee $Trustee to local group $LocalGroup." -NoExtraLines
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    Try {
        [xml]$xml = Get-Content $xmlFilePath -ErrorAction Stop
        $remoteDesktopUsersGroup = $xml.SelectSingleNode("//Group[@name='$LocalGroup']")
        $membersElement = $remoteDesktopUsersGroup.SelectSingleNode("Properties/Members")
        If ($null -eq $membersElement) { Throw "Local group $LocalGroup with Properties/Members not found." }

        $newMember = $xml.CreateElement("Member")
        $newMember.SetAttribute("name", $Trustee)
        $newMember.SetAttribute("action", "ADD")
        $newMember.SetAttribute("sid", $SID)
        $membersElement.AppendChild($newMember) | Out-Null
        $xml.Save($xmlFilePath)
    }
    Catch {
        Write-AS2GoOutput -Type Error -Message "Failed to add trustee $Trustee with SID $SID to local group ${LocalGroup}: $($_.Exception.Message)"
        Measure-FunctionRuntime -End -Details $Info
        return
    }

    Write-AS2GoOutput -Type Success -Message "Added trustee $Trustee with SID $SID to local group $LocalGroup within file Groups.xml under Properties/Members." -NoExtraLines

    Measure-FunctionRuntime -End -Details $Info

}
