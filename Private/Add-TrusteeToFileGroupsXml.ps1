function Add-TrusteeToFileGroupsXml {

    ################################################################################
    #####                                                                      ##### 
    #####    Add a Trustee incl. SID to the Groups.xml file                    #####                                
    #####                                                                      #####
    ################################################################################

    Param([string] $xmlFilePath, [string] $LocalGroup, [string] $Trustee, [string] $SID)

    $Info = Measure-FunctionRuntime -Begin

    [xml]$xml = Get-Content $xmlFilePath
    $remoteDesktopUsersGroup = $xml.SelectSingleNode("//Group[@name='$LocalGroup']")           
    $newMember = $xml.CreateElement("Member")
    $newMember.SetAttribute("name", $Trustee)
    $newMember.SetAttribute("action", "ADD")
    $newMember.SetAttribute("sid", $SID )
    $membersElement = $remoteDesktopUsersGroup.SelectSingleNode("Properties/Members")
    $membersElement.AppendChild($newMember) | Out-Null
    $xml.Save($xmlFilePath)

    Write-AS2GoOutput -Type Success -Message "Added trustee $Trustee with SID $SID to local group $LocalGroup within file Groups.xml under Properties/Members." -NoExtraLines
    
    Measure-FunctionRuntime -End -Details $Info

}
