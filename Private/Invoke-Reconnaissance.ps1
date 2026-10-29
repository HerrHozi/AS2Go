<#
.SYNOPSIS
Surveys AD infrastructure and attempts administrative-share access.

.DESCRIPTION
Loads configured workstation and DC settings when missing and collects forest, domain, and privileged-group details.
Lists Domain Admin members and up to ten enabled non-DC computer accounts with operating-system data.
Checks the configured admin workstation and attempts to list its C$ share when reachable.
Enumerates domain controllers with site and canonical-name information and attempts to list the configured DC C$ share.

.EXAMPLE
Invoke-Reconnaissance
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires AD cmdlets and initialized lab context. Share enumeration reflects the current user's permissions.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Surveys forest and domain details, Domain Admin membership, computers, and domain controllers.
Attempts to list the configured admin workstation and DC admin shares to demonstrate accessible resources.
#>
function Invoke-Reconnaissance {

    $Info = Measure-FunctionRuntime -Begin

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

    Write-AS2GoOutput -Type  Header -M "TRY to enumerate 10 Domain ADMINs"
  
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-ADGroupMember ", "-Identity """, $Script:GroupDA.samaccountname, """ -Recursive |", " Select-Object", " -First", " 10 |", " Format-Table" `
        -Color    $fgcC, $fgcS, $fgcV, $fgcS, $fgcC, $fgcS, $fgcV, $fgcC  

    Get-PrivilegeGroupMember -Group $Script:GroupDA

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -M "TRY to enumerate 10 Domain COMPUTER"

    
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
        Write-AS2GoOutput -Type  Warning -M ("$Script:ASDC | $_")
    }

    Write-AS2GoOutput -Type  Header -M "... and connect to one c$ share"

    [bool]$result = Test-Connection -ComputerName $Script:ASSAW -Quiet -Count 1 -ErrorAction SilentlyContinue
    If ($result -eq $true) {
        $directory = "\\$Script:ASSAW\c$"
        Get-DirContent -Path $directory
    }
    else {
        Write-AS2GoOutput -Type  Warning -M ("Admin PC $Script:ASSAW is offline!")
    }


    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type  Header -M "TRY to enumerate Domain Controllers"
    
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

    Write-AS2GoOutput -Type  Header -M "... and connect to one c$ share"

    Get-DirContent -Path "\\$Script:ASDC\c$"
    Write-Host ""
    Write-Host ""
    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    Measure-FunctionRuntime -End -Details $Info
}
