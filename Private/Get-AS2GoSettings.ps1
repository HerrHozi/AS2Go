function Get-AS2GoSettings {

    ################################################################################
    #####                                                                      ##### 
    #####   Read & Update global AS2Go Settings from JSON file                 #####                                 
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    param(
        [switch]$ReadOnly = $false
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    Invoke-Output -Type Header -Message "Verify and Update global AS2Go Settings"

    Set-ASConfig -Setting "ticketsDir" -Value $Script:AS2GOTicketsDir

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
            
            #            if ($Setting.Key -eq 'mySAW') {
            #                $path = "\\$newValue\$Script:ASTicketsUNCPath\`$c\temp\tickets"
            #                Set-ASConfig -Setting "ASTicketsUNCPath" -Value $path
            #            }

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
