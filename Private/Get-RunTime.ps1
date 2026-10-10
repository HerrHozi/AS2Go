<#
.SYNOPSIS
Calculates elapsed time from a supplied start time.

.DESCRIPTION
Parses the supplied start timestamp and returns the elapsed time span through the current time.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Returns the elapsed time span between the start time and the current time.
#>
function Get-RunTime {

    ################################################################################
    #####                                                                      ##### 
    #####    Get the run time of each function, to improve the execution       #####                     
    #####                                                                      #####
    ################################################################################

    param (
        [datetime] $StartRunTime
    )
   
    [datetime] $EndRunTime = (Get-Date).ToString($Script:DateFormatLog)
    $RunTime = NEW-TIMESPAN -Start $StartRunTime -End $EndRunTime
    return $RunTime
}
