
function Wait-AS2GoUserInput {

    ################################################################################
    #####                                                                      ##### 
    #####    Press Enter to continue                              
    #####                                                                      #####
    ################################################################################

    Param([string] $param1, [string] $param2)

    $Info = Measure-FunctionRuntime -Begin

    Write-Host "`n`n  [i] Press Enter to continue ... " -ForegroundColor $Script:FGCQuestion -NoNewline; [void][Console]::ReadLine()

    Measure-FunctionRuntime -End -Details $Info
}