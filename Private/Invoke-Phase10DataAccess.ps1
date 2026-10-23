<#
.SYNOPSIS
Demonstrates discovery and access to simulated sensitive data.

.DESCRIPTION
Writes a recursive listing of the AS2Go module into an ntds.dit placeholder on the configured AD backup share.
Runs net view for share discovery and lists the backup-share contents.
Copies a sample password-file viewing command to the clipboard and launches PsExec against the application server.
The user can explore the remote command prompt; the sample password file is not read automatically.

.EXAMPLE
Invoke-Phase10DataAccess
Runs this workflow using the initialized AS2Go module configuration.

.INPUTS
None. This function does not declare pipeline input.

.OUTPUTS
Console messages and output from invoked commands; no dedicated result object is defined.

.NOTES
Private AS2Go function. Run from an initialized AS2Go module session.
Uses configured backup-share, application-server, and tool paths. The .dit file is a directory listing, not a live AD database.

.COMPONENT
Category: Main Function

.FUNCTIONALITY
Writes a simulated ntds.dit file and enumerates the configured server shares and backup contents.
Opens a PsExec command prompt on the application server and prepares a sample sensitive-file command.
#>
function Invoke-Phase10DataAccess {

    ################################################################################
    #####                                                                      ##### 
    #####    Accessing Data                                                    #####                                 
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    $server = $($Script:ASOfflineDITFile).Split(".")[0]
    $fakeditfile = Join-Path -Path $Script:ASOfflineDITFile -ChildPath "ntds.dit"


    Write-AS2GoOutput -Type Header -Message "Starting with Share Enumeration"

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "net ", "view ", "$server" `
        -Color $fgcC, $fgcF, $fgcV
    Write-Host ""

    try {
        Get-ChildItem -path $ASModulePath -Recurse | out-file $fakeditfile 
    }
    catch {
        <#Do this if a terminating exception happens#>
    }


    Invoke-Command -ScriptBlock { net view $server } | Out-Host

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    Write-AS2GoOutput -Type Header -Message "Starting Enumeration of Share Content"
    Get-DirContent -Path $Script:ASOfflineDITFile

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Write-AS2GoOutput -Type Header -Message  "Try to open cmd console on $Script:ASAppServer"

    Write-Host ""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "Start-Process ", ".\PsExec.exe ", "-ArgumentList ", """\\$Script:ASAppServer -accepteula cmd.exe""" `
        -Color $fgcC, $fgcF, $fgcS, $fgcV
    Write-Host ""

    try {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | Set-Clipboard
    }
    catch {
        Write-Output "more C:\temp\as2go\my-passwords.txt" | clip
    }

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    
    $tool = Join-Path -Path $Script:ASTools -ChildPath "PsExec.exe"
    Start-Process $tool -ArgumentList "\\$Script:ASAppServer -accepteula cmd.exe"

    Write-AS2GoOutput -Type Bullet -Message "Try to find some sensitive data, e.g. files with passwords" 
    
    Write-Host""
    Write-Host      -NoNewline "  Command: "
    Write-Highlight -Text "more ", "C:\temp\as2go\my-passwords.txt" `
        -Color $fgcC, $fgcV
    Write-Host ""

    If ($UnAttended) { Start-Sleep 2 } else { Pause }
    If (-not $SkipClearHost) { Clear-Host }

    Measure-FunctionRuntime -End -Details $Info
}
