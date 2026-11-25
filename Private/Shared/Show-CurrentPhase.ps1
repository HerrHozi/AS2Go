<#
    .SYNOPSIS
    Displays a Kill Chain phase as an HTML page.

    .DESCRIPTION
    Opens the specified phase file in the default browser.

    .PARAMETER Phase
    Name of the HTML phase file to display.
    
    .COMPONENT
    Category: Sub Function
    #>
Function Show-CurrentPhase {

    Param(
        [string]$Phase
    )

    $info = Measure-FunctionRuntime -begin

    If (-not $SkipImages) { 

        If ($Phase.tolower().StartsWith("http")) {

            Start-Process $Phase
            Write-Log -Message "    Opened link: $Phase"

        }
        else {
            $fullpath = Join-Path $Script:ASPhases -ChildPath $Phase  
            Invoke-Item $fullpath
            Write-Log -Message "    Opened File: $fullpath"
        }


    }
    else {
        Write-Log -Message "    Skipped displaying phase: $Phase"
    }
    Measure-FunctionRuntime -end -detail $info
}
