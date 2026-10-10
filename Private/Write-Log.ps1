<#
.SYNOPSIS
Writes a timestamped message to the AS2Go log.

.DESCRIPTION
Writes a timestamped message with the requested severity when module logging is enabled.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Writes the selected severity and message when module logging is enabled.
#>
Function Write-Log {

    ################################################################################
    #####                                                                      ##### 
    #####    log all actions into a log file                                   #####
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",

        [Parameter(Mandatory = $True)]
        [string]
        $Message,

        [Parameter(Mandatory = $False)]
        [string]
        $logfile = $Script:ASModuleLog
    )

    If ($EnableLogging -ne $true) { return }
    $Stamp = (Get-Date).ToUniversalTime().ToString($Script:DateFormatLog)
    
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}
