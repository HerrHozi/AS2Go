function Add-GroupElementToFileGroupsXml {

    ################################################################################
    #####                                                                      ##### 
    #####    Add a new built-in Group to the Groups.xml file                   #####                                
    #####                                                                      #####
    ################################################################################


    Param([string] $xmlFilePath, [string] $GroupName, [string] $GroupSID)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    [xml]$xml = Get-Content $xmlFilePath

    $newGUID = "{" + (New-Guid).ToString().ToUpper() + "}"

    $newGroup = $xml.CreateElement("Group")
    $newGroup.SetAttribute("clsid", "{6D4A79E4-529C-4481-ABD0-F5BD7EA93BA7}")
    $newGroup.SetAttribute("name", $GroupName)
    $newGroup.SetAttribute("image", "2")
    $newGroup.SetAttribute("changed", "2022-09-28 11:51:44")
    $newGroup.SetAttribute("uid", $newGUID)
    $newGroup.SetAttribute("userContext", "0")
    $newGroup.SetAttribute("removePolicy", "0")

    $newProperties = $xml.CreateElement("Properties")
    $newProperties.SetAttribute("action", "U")
    $newProperties.SetAttribute("newName", "")
    $newProperties.SetAttribute("description", "")
    $newProperties.SetAttribute("deleteAllUsers", "0")
    $newProperties.SetAttribute("deleteAllGroups", "0")
    $newProperties.SetAttribute("removeAccounts", "0")
    $newProperties.SetAttribute("groupSid", $GroupSID)
    $newProperties.SetAttribute("groupName", $GroupName)

    $newMembers = $xml.CreateElement("Members")
    $newProperties.AppendChild($newMembers) | Out-Null
    $newGroup.AppendChild($newProperties) | Out-Null
    $groupsElement = $xml.SelectSingleNode("//Groups")
    $groupsElement.AppendChild($newGroup) | Out-Null

    $xml.Save($xmlFilePath)

    Invoke-Output -Type Success -Message "Added group $GroupName with SID $GroupSID to file $xmlFilePath." -NoExtraLines

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    #  return $true
}
