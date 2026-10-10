<#
.SYNOPSIS
Sets the console background and foreground colors.

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
        [Parameter(Mandatory = $True)]$BgC,
        [Parameter(Mandatory = $True)]$FgC
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $AS2GoConsole = (Get-Host).UI.RawUI
    $AS2GoConsole.BackgroundColor = $BgC
    $AS2GoConsole.ForegroundColor = $FgC

    Write-Log -Message "    >> Set Background Color to '$Bgc'."
    Write-Log -Message "    >> Set Foreground Color to '$Fgc'."

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
