<#
.SYNOPSIS
Sets the console background and foreground colors.

.DESCRIPTION
Applies the supplied background and foreground colors to the current PowerShell host console.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Applies the supplied colors to the current PowerShell host console.
#>
Function Set-NewBackgroundColor {

    ################################################################################
    #####                                                                      ##### 
    #####    set your own background color e.g. the black                      #####
    #####                                                                      #####
    ################################################################################

    Param(
        [Parameter(Mandatory = $True)]
        $BgC,
        [Parameter(Mandatory = $True)]
        $FgC
    )

    $Info = Measure-FunctionRuntime -Begin

    $AS2GoConsole = (Get-Host).UI.RawUI
    $AS2GoConsole.BackgroundColor = $BgC
    $AS2GoConsole.ForegroundColor = $FgC

    Write-Log -Message "    >> Set Background Color to '$Bgc'."
    Write-Log -Message "    >> Set Foreground Color to '$Fgc'."

    $runtime = Measure-FunctionRuntime -End -Details $Info
}
