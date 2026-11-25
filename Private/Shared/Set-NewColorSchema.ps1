Function Set-NewColorSchema {

    Param(
        [Parameter(Mandatory = $True)]
        [string]$NewStage
    )

    $Info = Measure-FunctionRuntime -Begin


    Initialize-ConsoleColors


    If ($NewStage -eq $Script:PtH) {
        
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "Darkblue"
        $Script:FGCError = "DarkBlue"
        
    Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor

    }
    elseif ($NewStage -eq $Script:PtT) {
        
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "Yellow"
        $Script:FGCError = "Red"
        
        Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor
    }
    elseif ($NewStage -eq $Script:GoldenTicket) {
        Initialize-ConsoleColors -AfterEscalation
        Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor
    }
    else {
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "YELLOW" 
        $Script:FGCError = "RED"
        Set-NewBackgroundColor -BgC $Script:ConsoleBGColor -FgC $Script:ConsoleFGColor
    }

    Write-Log -Message "    >> Set Color Schema for $NewStage"
    
    Measure-FunctionRuntime -End -Details $Info 
}