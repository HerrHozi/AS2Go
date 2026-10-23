function Write-Highlight {

    ################################################################################
    #####                                                                      ##### 
    ##### Format the command based on the new Windows Terminal color schema    #####                               
    #####                                                                      #####  
    ################################################################################

    Param ([String[]]$Text, [ConsoleColor[]]$Color, [Switch]$NoNewline = $false)

    $Info = Measure-FunctionRuntime -Begin

    For ([int]$i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -Foreground $Color[$i] -NoNewLine | Out-Host }
    If ($NoNewline -eq $false) { Write-Host '' | out-host }
    
    Write-Log -Message "    >> Highlighted '$Text' in $Color."
    Measure-FunctionRuntime -End -Details $Info
}
