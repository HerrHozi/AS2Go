Function Get-Answer {

    ################################################################################
    #####                                                                      ##### 
    #####    Function for a predefined answer                                  #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $question, [string] $defaultValue)

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host ####################

  
    If ($question.ToLower().Contains("repeat")) {
        write-host "`n  [?]  $question"  -ForegroundColor Cyan -NoNewline
    }
    else {
        write-host "`n  [?] $question"  -ForegroundColor $Script:FGCQuestion -NoNewline
    }
    
    $prompt = Read-Host "[$($defaultValue)]" 
    if ($prompt -eq "") { $prompt = $defaultValue.trim() } 

    Write-Log -Message "    >> Q:$question  A:$prompt"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $prompt.ToUpper()
}
