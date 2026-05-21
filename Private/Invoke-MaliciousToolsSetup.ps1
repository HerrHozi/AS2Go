function Invoke-MaliciousToolsSetup {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to set up Malicious Tools environment                #####                              
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $MaliciousTools = @(
        (Join-Path -Path $Script:ASTools -ChildPath 'AS2Go-Tools_v2.7z'),
        (Join-Path -Path $Script:ASTools -ChildPath 'AS2Go-Tools_v2.zip'),
        (Join-Path -Path $Script:ASTools -ChildPath '_readme.md')
    )

    If (-not $SkipClearHost) { Clear-Host }
    Invoke-Output -Type Header -Message "Prepare folder for Malicious Tools"
    Invoke-Output -Type H1 -Message "Steps to do:`n"
    Invoke-output -Type Bullet -Message "Define or create a folder to store malicious tools, such as Rubeus, Certify"
    Invoke-output -Type Bullet -Message "Microsoft Defender: Disable real-time monitoring."
    Invoke-output -Type Bullet -Message "Microsoft Defender: Add exclusions for the tools folder."
    Invoke-output -Type Bullet -Message "Extract malicious tools to the designated folder."

    $answer = Show-DecisionPrompt
    If ($answer -ne $script:Yes) { return }

    $defaultFolder = "$($Script:AS2GoPublicDir)\MaliciousTools"
    $title = "Confirm or change folder for malicious tools."
    $message = $defaultFolder

    $Options = @(
        [pscustomobject] @{ Label = "&OK"; Help = "Use default folder."; Value = "OK" },
        [pscustomobject] @{ Label = "&Select other folder"; Help = "Open a object browser to select or create a different folder for malicious tools."; Value = "OtherFolder" },     
        [pscustomobject] @{ Label = "&Cancel"; Help = "Return to main setup."; Value = "Skip" }
    )

    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title
    Write-Host

    If ($answer -eq "Skip") {
        return 
    }
    elseif ($answer -eq "OtherFolder") {
        $newfolder = Get-FolderPath -InitialDirectory $defaultFolder -Description "Select or create a folder for malicious tools. Default is $defaultFolder"

        if ($null -ne $newfolder) {
            $defaultFolder = $newfolder
            Invoke-output -Type Success -Message "Selected folder for malicious tools: $defaultFolder" -noextralines
        }
        else {
            Invoke-output -Type Warning -Message "No folder selected. Using default folder: $defaultFolder"
        }
    }
    else {
        Invoke-output -Type Success -Message "Using default folder for malicious tools: $defaultFolder" -noextralines
    }

    Set-ASConfig -Setting "Tools" -Value $defaultFolder

    Set-MpPreference -DisableRealtimeMonitoring $true
    Invoke-output -Type Success -Message "Microsoft Defender: Disabled real-time monitoring." -noextralines

    Add-MpPreference -ExclusionPath $defaultFolder
    Invoke-output -Type Success -Message "Microsoft Defender: Added exclusion for $defaultFolder." -noextralines

    Foreach ($tool in $MaliciousTools) {
        if (-not (Test-Path -Path $tool)) {
            Invoke-output -Type Warning -Message "Tool not found: $tool. Please ensure the file exists." -noextralines
        }
        Copy-Item -Path $tool -Destination $defaultFolder -Recurse -Force
        Invoke-output -Type Success -Message "Copied $tool to $defaultFolder." -noextralines
    }

    ## AS2Go-Tools_v2.zip and AS2Go-Tools_v2.7z (PW: HerrHozi!)
    Write-Host
    Invoke-output -Type H1 -Message "The password-protected ZIP or 7z archive contains the following tools:"
    Write-Host

    Invoke-output -Type Bullet -Message "NetSess.exe    Release: 2.0.0.46 (last build 20220105)"
    Invoke-output -Type Bullet -Message "Mimikatz.exe   Release: 2.2.0.0  (last build 20220809)"
    Invoke-output -Type Bullet -Message "Rubeus.exe     Release: 2.3.3.0  (last build 20251009)"
    Invoke-output -Type Bullet -Message "Certify.exe    Release: 2.0.0.0  (last build 20251009)"
    Invoke-output -Type Bullet -Message "PsExec.exe     Release: 2.4      (last build 20220719)"

    Invoke-Output -Type TextMaker -Message "Please extract manually the tools from the ZIP or 7z archive to the folder '$defaultFolder'.`n      The archive password is: " -TM "HerrHozi!"
    Invoke-Item $defaultFolder

    $title = "Confirm that the malicious tools have been extracted from one of the following archives:"
    $message = "AS2Go-Tools_v2.7z or AS2Go-Tools_v2.zip"
    $Options = @(
        [pscustomobject] @{ Label = "&OK"; Help = "Files have been extracted."; Value = "OK" },
        [pscustomobject] @{ Label = "&Cancel"; Help = "Return to the main setup."; Value = "Skip" }
    )

    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}