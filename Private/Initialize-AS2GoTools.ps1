<#
.SYNOPSIS
Prepares a folder for AS2Go training tools.

.DESCRIPTION
Prompts for a destination, configures Defender exclusions, copies protected tool archives, and
displays guidance for extracting the training tools.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Selects a tools folder, configures Defender exclusions, copies archives, and guides extraction.
#>
function Initialize-AS2GoTools {

    ################################################################################
    #####                                                                      ##### 
    #####    Start Process to set up Malicious Tools environment                #####                              
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin
    $CurrentFunction = $Info.FunctionName

    $MaliciousTools = @(
        (Join-Path -Path $Script:ASTools -ChildPath 'AS2Go-Tools_v2.7z'),
        (Join-Path -Path $Script:ASTools -ChildPath 'AS2Go-Tools_v2.zip'),
        (Join-Path -Path $Script:ASTools -ChildPath '_readme.md')
    )

    If (-not $SkipClearHost) { Clear-Host }
    Write-AS2GoOutput -Type Header -Message "Prepare folder for Malicious Tools"
    $Functionality = (Get-Help $CurrentFunction).Functionality
    Write-AS2GoOutput -Type H1 -Message $Functionality
    Write-AS2GoOutput -Type Bullet -Message "Define or create a folder to store malicious tools, such as Rubeus, Certify"
    Write-AS2GoOutput -Type Bullet -Message "Microsoft Defender: Disable real-time monitoring."
    Write-AS2GoOutput -Type Bullet -Message "Microsoft Defender: Add exclusions for the tools folder."
    Write-AS2GoOutput -Type Bullet -Message "Extract malicious tools to the designated folder."

    If ($Script:Yes -ne $(Show-DecisionPrompt)) {
        Write-Log -Message "User chose not to proceed this operation"
        return
    }

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
            Write-AS2GoOutput -Type Success -Message "Selected folder for malicious tools: $defaultFolder" -noextralines
        }
        else {
            Write-AS2GoOutput -Type Warning -Message "No folder selected. Using default folder: $defaultFolder"
        }
    }
    else {
        Write-AS2GoOutput -Type Success -Message "Using default folder for malicious tools: $defaultFolder" -noextralines
    }

    Set-ASConfig -Setting "Tools" -Value $defaultFolder

    Set-MpPreference -DisableRealtimeMonitoring $true
    Write-AS2GoOutput -Type Success -Message "Microsoft Defender: Disabled real-time monitoring." -noextralines

    Add-MpPreference -ExclusionPath $defaultFolder
    Write-AS2GoOutput -Type Success -Message "Microsoft Defender: Added exclusion for $defaultFolder." -noextralines

    Foreach ($tool in $MaliciousTools) {
        if (-not (Test-Path -Path $tool)) {
            Write-AS2GoOutput -Type Warning -Message "Tool not found: $tool. Please ensure the file exists." -noextralines
        }
        Copy-Item -Path $tool -Destination $defaultFolder -Recurse -Force
        Write-AS2GoOutput -Type Success -Message "Copied $tool to $defaultFolder." -noextralines
    }

    ## AS2Go-Tools_v2.zip and AS2Go-Tools_v2.7z (PW: HerrHozi!)
    Write-Host
    Write-AS2GoOutput -Type H1 -Message "The password-protected ZIP or 7z archive contains the following tools:"
    Write-Host

    Write-AS2GoOutput -Type Bullet -Message "NetSess.exe    Release: 2.0.0.46 (last build 20220105)"
    Write-AS2GoOutput -Type Bullet -Message "Mimikatz.exe   Release: 2.2.0.0  (last build 20220809)"
    Write-AS2GoOutput -Type Bullet -Message "Rubeus.exe     Release: 2.3.3.0  (last build 20251009)"
    Write-AS2GoOutput -Type Bullet -Message "Certify.exe    Release: 2.0.0.0  (last build 20251009)"
    Write-AS2GoOutput -Type Bullet -Message "PsExec.exe     Release: 2.4      (last build 20220719)"

    Write-AS2GoOutput -Type TextMaker -Message "Please extract manually the tools from the ZIP or 7z archive to the folder '$defaultFolder'.`n      The archive password is: " -TM "HerrHozi!"
    Invoke-Item $defaultFolder

    $title = "Confirm that the malicious tools have been extracted from one of the following archives:"
    $message = "AS2Go-Tools_v2.7z or AS2Go-Tools_v2.zip"
    $Options = @(
        [pscustomobject] @{ Label = "&OK"; Help = "Files have been extracted."; Value = "OK" },
        [pscustomobject] @{ Label = "&Cancel"; Help = "Return to the main setup."; Value = "Skip" }
    )

    $answer = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

    Measure-FunctionRuntime -End -Details $Info
}