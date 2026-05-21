function Write-Highlight {

    ################################################################################
    #####                                                                      ##### 
    ##### Format the command based on the new Windows Terminal color schema    #####                               
    #####                                                                      #####  
    ################################################################################

    Param ([String[]]$Text, [ConsoleColor[]]$Color, [Switch]$NoNewline = $false)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -Foreground $Color[$i] -NoNewLine | Out-Host }
    If ($NoNewline -eq $false) { Write-Host '' | out-host }
    
    Write-Log -Message "    >> Highlighted '$Text' in $Color."
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
