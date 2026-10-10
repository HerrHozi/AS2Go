function Start-Reconnaissance {

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    If ($null -eq $Script:ASSAW) {
        $Script:ASSAW = Get-ASConfig -Setting "mySAW" -ErrorAction SilentlyContinue
    }

    If ($null -eq $Script:ASDC) {
        $Script:ASDC = Get-ASConfig -Setting "myDC" -ErrorAction SilentlyContinue
    }
  
    Get-ForestInfo
    
    if ($null -eq $Script:GroupDA) {
        $Script:GroupDA = Get-ADGroupSamAccountNameBasedOnRID -RID "-512"
    }

    Invoke-Output -Type  Header -M "TRY to enumerate 10 Domain ADMINs"
  
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-ADGroupMember ", "-Identity """, $Script:GroupDA.samaccountname, """ -Recursive |", " Select-Object", " -First", " 10 |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC, $fgcS, $fgcV, $fgcC  

    Get-PriviledgeGroupMember -Group $Script:GroupDA

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type  Header -M "TRY to enumerate 10 Domain COMPUTER"

    
    Write-Host -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADComputer ", "-Filter * | ", "Format-Table", " Name, Enabled, OperatingSystem, DistinguishedName") -Color $fgcC, $fgcS, $fgcC, $fgcV
    Write-Host ""

    # enumerate all computer accounts 
    $attributes = @("Name", "Enabled", "OperatingSystem", "DistinguishedName", "lastLogondate", "CanonicalName")
    try {
        Get-ADComputer -Filter 'PrimaryGroupID -ne 516 -and Enabled -eq $true -and OperatingSystem -like "*"' -properties $attributes -Server $Script:ASDC | 
        Sort-Object lastlogondate -Descending | Select-Object -First 10 | Format-Table Name, OperatingSystem, Lastlogondate, CanonicalName, Enabled
    }
    catch {
        Invoke-Output -Type  Warning -M ("$Script:ASDC | $_")
    }

    Invoke-Output -Type  Header -M "... and connect to one c$ share"

    [bool]$result = Test-Connection -ComputerName $Script:ASSAW -Quiet -Count 1 -ErrorAction SilentlyContinue
    If ($result -eq $true) {
        $directory = "\\$Script:ASSAW\c$"
        Get-DirContent -Path $directory
    }
    else {
        Invoke-Output -Type  Warning -M ("Admin PC $Script:ASSAW is offline!")
    }


    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Invoke-Output -Type  Header -M "TRY to enumerate Domain Controllers"
    
    Write-Host -NoNewline "  Command: "
    Write-Highlight -Text ("Get-ADDomainController ", "-filter * | ", "ft ", "hostname, IPv4Address, ISReadOnly, IsGlobalCatalog, site, ComputerObjectDN") -Color $fgcC, $fgcS, $fgcC, $fgcV

    Write-Host ""
    Write-Host ""

    Get-ADDomainController -Filter * | ForEach-Object {
        $dc = $_
        $canonical = $null
        try {
            $canonical = (Get-ADComputer -Identity $dc.ComputerObjectDN -Properties CanonicalName -Server $Script:ASDC -ErrorAction Stop).CanonicalName
        }
        catch {
            $canonical = "<n/a>"
        }
        [PSCustomObject]@{
            HostName        = $dc.HostName
            IPv4Address     = $dc.IPv4Address
            IsReadOnly      = $dc.IsReadOnly
            IsGlobalCatalog = $dc.IsGlobalCatalog
            Site            = $dc.Site
            CanonicalName   = $canonical
        }
    } | Format-Table HostName, IPv4Address, IsReadOnly, IsGlobalCatalog, Site, CanonicalName

    Invoke-Output -Type  Header -M "... and connect to one c$ share"

    Get-DirContent -Path "\\$Script:ASDC\c$"
    Write-Host ""
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
