function Get-AS2GoSettings {
    [CmdletBinding()]
    param(
        [switch]$ReadOnly = $false
    )


    ################################################################################
    #####                                                                      ##### 
    #####   Read & Update global AS2Go Settings from JSON file                 #####                                 
    #####                                                                      #####
    ################################################################################

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -T Header -M "Verify and Update global AS2Go Settings"

    # -------------------------------
    # Helper: build settings definition
    # -------------------------------
    function New-AS2GoSetting {
        param(
            [Parameter(Mandatory)][int]$Index,
            [Parameter(Mandatory)][string]$Label,
            [Parameter(Mandatory)][string]$Key,
            [ValidateSet('Text', 'ADObject', 'Folder')]
            [string]$InputType = 'Text',
            [string]$ScriptVar # optional: name of $Script: variable to sync
        )
        [pscustomobject]@{
            Index     = $Index
            Label     = $Label
            Key       = $Key
            InputType = $InputType
            ScriptVar = $ScriptVar
            Value     = $null
        }
    }

    # -------------------------------
    # Helper: read all config keys once
    # -------------------------------
    function Read-AS2GoConfig {
        param(
            [Parameter(Mandatory)][object[]]$Settings
        )
        $cfg = [ordered]@{}
        foreach ($s in $Settings) {
            try {
                $cfg[$s.Key] = Get-ASConfig -Setting $s.Key
            }
            catch {
                $cfg[$s.Key] = $null
            }
        }
        return $cfg
    }

    # -------------------------------
    # Helper: assign values to $Settings from config hashtable
    # -------------------------------
    function Update-AS2GoSettingValues {
        param(
            [Parameter(Mandatory)][object[]]$Settings,
            [Parameter(Mandatory)][hashtable]$Config
        )
        foreach ($s in $Settings) {
            $s.Value = $Config[$s.Key]
        }
    }

    # -------------------------------
    # Helper: display settings table
    # -------------------------------
    function Show-AS2GoSettingsTable {
        param(
            [Parameter(Mandatory)][object[]]$Settings
        )
        foreach ($s in $Settings | Sort-Object Index) {
            "{0,3}: {1,-30} = {2}" -f $s.Index, $s.Label, $s.Value | Write-Host
        }
    }

    # -------------------------------
    # Helper: edit one setting (UI input)
    # -------------------------------
    function Edit-AS2GoSetting {
        param(
            [Parameter(Mandatory)]$Setting
        )

        Write-Host ""
        Write-Host ("  Change value for '{0}' = {1}" -f $Setting.Label.Trim(), $Setting.Value) -ForegroundColor $Script:FGCCommand

        $newValue = $null
        switch ($Setting.InputType) {
            'ADObject' {
                If ($Setting.key -match 'honeytoken') {
                    $newValue = Select-ADObject -IncludeUsers
                }
                else {
                    $newValue = Select-ADObject
                }

            }
            'Folder' {
                $newValue = Get-FolderPath -InitialDirectory 'C:\' -Description 'Please select the tools folder (with mimikatz.exe)'
            }
            default {
                $newValue = Invoke-Output -Type Input -Message "Please enter the new value"
            }
        }

        if ($null -ne $newValue -and ($newValue.ToString().Trim()).Length -gt 0) {
            Set-ASConfig -Setting $Setting.Key -Value $newValue
        }
        else {
            Write-Host "  No value provided. Nothing changed." -ForegroundColor Yellow
        }
    }

    # -------------------------------
    # Settings definition (single source of truth)
    # Keep the Index numbers stable (your UI references them)
    # -------------------------------
    $Settings = @(
        (New-AS2GoSetting -Index 0  -Label "Logon Server / DC"          -Key "myDC"          -InputType Text    -ScriptVar "ASDC"),
        (New-AS2GoSetting -Index 1  -Label "Victim PC"                  -Key "myViPC"        -InputType Text    -ScriptVar "ASVictimMaschine"),
        (New-AS2GoSetting -Index 2  -Label "Admin PC"                   -Key "mySAW"         -InputType Text    -ScriptVar "ASSAW"),
        (New-AS2GoSetting -Index 3  -Label "Application Server"         -Key "myAppServer"   -InputType Text    -ScriptVar "ASAppServer"),
        (New-AS2GoSetting -Index 4  -Label "Help Desk Group"            -Key "globalHelpDesk"-InputType Text    -ScriptVar "ASHelpDesk"),
        (New-AS2GoSetting -Index 5  -Label "MDI Honeytoken"             -Key "honeytoken"    -InputType ADObject -ScriptVar "ASHoneyToken"),
        (New-AS2GoSetting -Index 6  -Label "Domain Name"                -Key "fqdn"          -InputType Text    -ScriptVar "ASDomain"),
        (New-AS2GoSetting -Index 7  -Label "Domain SID"                 -Key "DomainSID"     -InputType Text    -ScriptVar "ASDomainSID"),
        (New-AS2GoSetting -Index 8  -Label "NTLM Hash Helpdesk"         -Key "pthntml"       -InputType Text    -ScriptVar "ASPtHntml"),
        (New-AS2GoSetting -Index 9  -Label "NTLM Hash krbtgt"           -Key "krbtgtntml"    -InputType Text    -ScriptVar "ASKrbtgtNtml"),
        (New-AS2GoSetting -Index 10 -Label "Seconds to reboot"          -Key "time2reboot"   -InputType Text    -ScriptVar "ASTime2Reboot"),
        (New-AS2GoSetting -Index 11 -Label "AD Search Base"             -Key "MySearchBase"  -InputType ADObject -ScriptVar "ASSearchBase"),
        (New-AS2GoSetting -Index 12 -Label "OU for BD User"             -Key "BDUsersOU"     -InputType ADObject -ScriptVar "ASOUofBackDoorUser"),
        (New-AS2GoSetting -Index 13 -Label "Tickets UNC Path (suffix)"  -Key "ticketsPath"   -InputType Text    -ScriptVar "ASTicketsUNCPath"),
        (New-AS2GoSetting -Index 14 -Label "Tickets Directory"          -Key "ticketsDir"    -InputType Text    -ScriptVar "ASTicketsDirectory"),
        (New-AS2GoSetting -Index 15 -Label "NTDS Dit File (Backup)"     -Key "OfflineDITFile"-InputType Text    -ScriptVar "ASOfflineDITFile"),
        (New-AS2GoSetting -Index 16 -Label "Tools (e.g. Certity, Rubeus)" -Key "Tools"        -InputType Folder  -ScriptVar "ASTools")
        # (New-AS2GoSetting -Index 17 -Label "OpenSSL start path"         -Key "OpenSSL"       -InputType Text    -ScriptVar "ASOPenSSL")
    )

    # -------------------------------
    # Prompt
    # -------------------------------
    $title = "Verify and Update Global AS2Go Settings"
    $message = "Are all values correct?"
    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Yes - All values are correct."; Value = "Yes" },
        [pscustomobject] @{ Label = "&No"; Help = "No - At least one value is wrong."; Value = "No" },
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip this task."; Value = "Quit" }
    )

    $firstRun = $true
    $repeat = $Script:Yes

    do {
        if (-not $firstRun) {
            Clear-Host
            Invoke-Output -Type Info -message "Updated Values"
        }
        $firstRun = $false

        # -------------------------------
        # Dynamic defaults (AD + local env) — set once per loop
        # -------------------------------
        $Domain = $null
        try { $Domain = Get-ADDomain } catch { }

        if ($Domain) {
            try { Set-ASConfig -Setting "fqdn"      -Value $Domain.DNSRoot } catch { }
            try { Set-ASConfig -Setting "DomainSID" -Value $Domain.DomainSID.Value } catch { }
        }

        # env defaults
        try { 
            $value = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
            Set-ASConfig -Setting "myViPC" -Value $value
        }
        catch {
            Set-ASConfig -Setting "myViPC" -Value $env:COMPUTERNAME 
        }
        try {
            $server = Get-LogonServerFQDN
            Set-ASConfig -Setting "myDC" -Value $server
        }
        catch { }

        # -------------------------------
        # Read config once, apply normalization rules, re-read if changed
        # -------------------------------
        $Config = Read-AS2GoConfig -Settings $Settings

        # Normalize: BDUsersOU placeholder -> actual UsersContainer (if domain is available)
        if ($Domain) {
            $bd = [string]$Config["BDUsersOU"]
            if ($bd -and ($bd -ieq "CN=Users,DC=xxx,DC=xxx")) {
                try { Set-ASConfig -Setting "BDUsersOU" -Value $Domain.UsersContainer } catch { }
                $Config = Read-AS2GoConfig -Settings $Settings
            }
        }

        # Normalize: Tools path placeholder ".\tools" -> resolve if possible (otherwise keep as-is)
        $tools = [string]$Config["Tools"]
        if ($tools -and ($tools -ieq ".\tools")) {
            try {
                $resolved = Resolve-Path ".\tools" -ErrorAction Stop
                Set-ASConfig -Setting "Tools" -Value $resolved.Path
                $Config = Read-AS2GoConfig -Settings $Settings
            }
            catch {
                # keep ".\tools" if not resolvable
            }
        }

        # apply config to settings values
        Update-AS2GoSettingValues -Settings $Settings -Config $Config

        # Sync $Script: variables (so existing code keeps working)
        foreach ($s in $Settings) {
            if ($s.ScriptVar) {
                Set-Variable -Scope Script -Name $s.ScriptVar -Value $s.Value -Force
            }
        }

        if ($ReadOnly) {
            # Return a rich object in readonly mode (useful for callers)
            $runtime = Get-RunTime -StartRunTime $StartRunTime
            Write-Log -Message "    Run Time: $runtime [h] ###"
            Write-Log -Message "### End Function $CurrentFunction ###"

            return [pscustomobject]@{
                Settings = $Settings | Sort-Object Index
                Config   = $Config
            }
        }

        # Show settings
        Show-AS2GoSettingsTable -Settings $Settings

        $decision = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title

        switch ($decision) {
            "Yes" { $repeat = $Script:No }
            "Quit" {
                Write-Log -Message "Skipped AS2Go Settings verification/update!"
                $repeat = $Script:No
            }
            "No" {
                # Ask which setting index to edit
                $defaultIndex = 10
                $question = "Please enter the desired setting number. Default "
                $answer = Get-Answer -question $question -defaultValue $defaultIndex

                $idx = $defaultIndex
                if ($answer -match '^\d{1,2}$') {
                    $idx = [int]$answer
                }

                $target = $Settings | Where-Object { $_.Index -eq $idx } | Select-Object -First 1
                if (-not $target) {
                    Write-Host "  Invalid setting number '$idx'." -ForegroundColor Yellow
                }
                else {
                    try {
                        Edit-AS2GoSetting -Setting $target
                    }
                    catch {
                        Write-Host "  Failed to update setting '$($target.Label)'." -ForegroundColor Red
                    }
                }

                # loop continues -> values will be reloaded & displayed
            }
            default {
                # Safety: treat unknown as quit
                $repeat = $Script:No
            }
        }

        Clear-Host
    } until ($repeat -eq $Script:No)

    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    # Return final snapshot (useful for automation/tests)
    #return [pscustomobject]@{
    #    Settings = $Settings | Sort-Object Index
    #    Config   = (Read-AS2GoConfig -Settings $Settings)
    #}
}


function Get-AS2GoSettings_old {

    Param([switch]$ReadOnly = $false)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -T Header -M "Verify and Update global AS2Go Settings"

    $title = "Verify and Update Global AS2Go Settings"
    $message = "Are all values correct?"

    $Options = @(
        [pscustomobject] @{ Label = "&Yes"; Help = "Yes - All values are correct."; Value = "Yes" },
        [pscustomobject] @{ Label = "&No"; Help = "No - At least one value is wrong."; Value = "No" },
        [pscustomobject] @{ Label = "&Skip"; Help = "Skip this task."; Value = "Quit" }
    )

    $repeat = $Script:Yes
    [bool]$firstrun = $true

    Do {
        If ($firstrun -ne $true) {
            Clear-Host
            Invoke-output -Type H1 "Updated Values"
        }
        else {
            $firstrun = $false
        }

        try {
            $Script:ASDomain = (Get-ADDomain).DNSRoot
            Set-ASConfig -Setting "fqdn" -Value $Script:ASDomain 
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        
        try {
            $Script:ASDomainSID = (Get-ADDomain).DomainSID.Value
            Set-ASConfig -Setting "DomainSID" -Value $Script:ASDomainSID
        }
        catch {
            <#Do this if a terminating exception happens#>
        }
        
        $Script:ASVictimMaschine = $env:COMPUTERNAME
        $Script:ASDC = Get-LogonServerFQDN

        #Set-ASConfig -Setting "fqdn" -Value $Script:ASDomain
        #Set-ASConfig -Setting "DomainSID" -Value $Script:ASDomainSID
        Set-ASConfig -Setting "myViPC" -Value $Script:ASVictimMaschine
        Set-ASConfig -Setting "mydc" -Value $Script:ASDC

        #read values from AS2Go.json config file
        $Script:ASDC = Get-ASConfig -Setting "myDC" 
        $Script:ASSAW = Get-ASConfig -Setting "mySAW" 
        $Script:ASVictimMaschine = Get-ASConfig -Setting "myViPC"
        $Script:ASFQDN = Get-ASConfig -Setting "fqdn"
        $Script:ASPtHntml = Get-ASConfig -Setting "pthntml"
        $Script:ASKrbtgtNtml = Get-ASConfig -Setting "krbtgtntml"
        #$Script:ASOPenSSL = Get-ASConfig -Setting "OpenSSL"
        $Script:ASHelpDesk = Get-ASConfig -Setting "globalHelpDesk"
        $Script:ASTicketsUNCPath = Get-ASConfig -Setting "ticketsPath"
        $Script:ASTicketsDirectory = Get-ASConfig -Setting "ticketsDir"
        $Script:ASTime2Reboot = Get-ASConfig -Setting "time2reboot"
        $Script:ASOUofBackDoorUser = Get-ASConfig -Setting "BDUsersOU"
        $Script:ASSearchBase = Get-ASConfig -Setting "MySearchBase"
        $Script:ASOfflineDITFile = Get-ASConfig -Setting "OfflineDITFile"
        $Script:ASAppServer = Get-ASConfig -Setting "myAppServer"
        $Script:ASHoneyToken = Get-ASConfig -Setting  "honeytoken"
        $Script:ASOUofBackDoorUser = Get-ASConfig -Setting "BDUsersOU"
        $Script:ASTools = Get-ASConfig -Setting "Tools"

        if ($ReadOnly) { return }
        
        $temp = Get-ASConfig -Setting  "Tools"
        If ($temp.tolower() -eq ".\tools") {
            Set-ASConfig -Setting  "Tools" -Value $Script:ASTools
            $Script:ASTools = Get-ASConfig -Setting "Tools"
        }
        else {
            $Script:ASTools = Get-ASConfig -Setting "Tools"
        } 
        
        $temp = Get-ASConfig -Setting  "BDUsersOU"
        If ($temp.tolower() -eq "CN=Users,DC=xxx,DC=xxx".ToLower()) {
            Set-ASConfig -Setting  "BDUsersOU" -Value (Get-ADDomain).UsersContainer
            $Script:ASOUofBackDoorUser = Get-ASConfig -Setting "BDUsersOU"
        }
        else {
            $Script:ASOUofBackDoorUser = Get-ASConfig -Setting "BDUsersOU"
        }

        # fill the arrays
        $MyParameter = @("Logon Server / DC         ", `
                "Victim PC                 ", `
                "Admin PC                  ", `
                "Application Server        ", `
                "Help Desk Group           ", `
                "MDI Honeytoken            ", `
                "Domain Name               ", `
                "Domain siD                ", `
                "NTML Hash Helpdesk        ", `
                "NTML Hash krbtgt          ", `
                "Seconds to reboot         ", `
                "AD Search Base            ", `
                "OU for BD User            ", `
                "Tickets UNC Path (suffix) ", `
                "Tickets Directory         ", `
                "NTDS Dit File (Backup)    ", `
                "Tools (e.g. Certity, Rubeus)     ")

        $MyValue = @($Script:ASDC, `
                $Script:ASVictimMaschine, `
                $Script:ASSAW, `
                $Script:ASAppServer, `
                $Script:ASHelpDesk, `
                $Script:ASHoneyToken, `
                $Script:ASDomain, `
                $Script:ASDomainSID, `
                $Script:ASPtHntml, `
                $Script:ASKrbtgtNtml, `
                $Script:ASTime2Reboot, `
                $Script:ASSearchBase, `
                $Script:ASOUofBackDoorUser, `
                $Script:ASTicketsUNCPath, `
                $Script:ASTicketsDirectory, `
                $Script:ASOfflineDITFile, `
                $Script:ASTools)

        $MyKey = @("myDC", `
                "myViPC", `
                "mySAW", `
                "myAppServer", `
                "globalHelpDesk", `
                "honeytoken", `
                "DomainName", `
                "DomainSID", `
                "pthntml", `
                "krbtgtntml", `
                "time2reboot", `
                "MySearchBase", `
                "BDUsersOU", `
                "ticketsUNCPath", `
                "ticketsDir", `
                "OfflineDITFile", `
                "Tools")

        for ($counter = 0; $counter -lt $MyParameter.Length; $counter++ ) {
            write-host ([string]$counter).PadLeft(4, ' ') ":" $MyParameter.Get($counter) " = " $MyValue.Get($counter)
        }

        $decision = Show-DecisionPrompt -Message $message  -Options $Options -Default 0 -Title $title

        switch ($decision) {

            "Yes" {
                $repeat = $Script:No
            }
            "No" {

                $counter = 10

                if ($prompt -match '^(\d|\d\d)$') {
                    If ([int]$prompt -gt 0 -and [int]$prompt -lt 20) {
                        $counter = $prompt
                    }
                    else {
                        $question = "Please enter the desired setting number. Default "
                        $counter = Get-Answer -question $question -defaultValue $counter
                    }
                }
                else {
                    $question = "Please enter the desired setting number. Default "
                    $counter = Get-Answer -question $question -defaultValue $counter
                }

                try {

                    write-host "`n  Change value for '$($MyParameter.Get($counter).trim())' = $($MyValue.Get($counter))" -ForegroundColor $Script:FGCCommand
                
                    If ($counter -match '^(11|12)$') {
                        $result = Select-ADObject
                        $newvaulue = $result
                    }
                    elseif ($counter -match '^(16)$') {
                        $newvaulue = Get-FolderPath -InitialDirectory 'C:\' -Description 'Please select the tools folder (with mimikatz.exe)'
                    }
                    else {
                        $newvaulue = Invoke-Output -Type Input -Message "Please enter the new value"
                    }
                    Set-ASConfig -Setting $MyKey.Get($counter)  -Value $newvaulue
                }
                catch {
                    write-host  "$counter = Wrong Input"
                }
                Finally {
                    Get-AS2GoSettings
                }
            }
            "Quit" {
                Write-Log -Message "Skipped AS2Go Lab Setup!"
                $repeat = $Script:No
            }
        }

        $firstrun = $false
        clear-host
    } Until ($repeat -eq $Script:No)

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
