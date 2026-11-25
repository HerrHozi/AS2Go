<#
.SYNOPSIS
Prompts for a text answer with a default value.

.FUNCTIONALITY
Returns the entered answer in uppercase, using the default when input is blank.
#>
Function Get-Answer {

    ################################################################################
    #####                                                                      ##### 
    #####    Function for a predefined answer                                  #####                                 
    #####                                                                      #####
    ################################################################################

    Param([string] $question, [string] $defaultValue)

    $Info = Measure-FunctionRuntime -Begin

  
    If ($question.ToLower().Contains("repeat")) {
        write-host "`n  [?]  $question"  -ForegroundColor Cyan -NoNewline
    }
    else {
        write-host "`n  [?] $question"  -ForegroundColor $Script:FGCQuestion -NoNewline
    }
    
    $prompt = Read-Host "[$($defaultValue)]" 
    if ($prompt -eq "") { $prompt = $defaultValue.trim() } 

    Write-Log -Message "    >> Q:$question  A:$prompt"
    Measure-FunctionRuntime -End -Details $Info

    return $prompt.ToUpper()
}
