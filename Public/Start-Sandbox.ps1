function Start-2GoSandbox {

    ################################################################################
    #####                                                                      ##### 
    #####    Description                ######                                 
    #####                                                                      #####
    ################################################################################
    
    Param(
        [switch] $EnableLogging
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

[int]$total = 66
$text =  "  REPEAT ? PSExec Command  "
$chars = [int](($total - $text.Length) / 2)
$separator = ':' * $chars



    


#$answer = Show-DecisionPrompt -Message $message -Options $Options -Default 1 -Title $title
$title = "$separator $text $separator"
$answer = Show-DecisionPrompt -Default 1 -Title $title

######################## main code ############################
$runtime = Get-RunTime -StartRunTime $StartRunTime
Write-Log -Message "    Run Time: $runtime [h] ###"
Write-Log -Message "### End Function $CurrentFunction ###"
}