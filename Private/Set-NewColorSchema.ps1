Function Set-NewColorSchema {

    Param(
        [Parameter(Mandatory = $True)][string]$NewStage
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    $Script:FGCIInfo = [System.ConsoleColor]::Magenta    # Additional info / side details
    $Script:FGCMInfo = [System.ConsoleColor]::Yellow       # Main info (instead of Yellow → modern, easy to read)
    $Script:FGCSInfo = [System.ConsoleColor]::DarkGray   # Secondary info / less important
    $Script:FGCCommand = [System.ConsoleColor]::White      # Commands / executions
    $Script:FGCQuestion = [System.ConsoleColor]::Cyan
    $Script:FGCDecisionPrompt = [System.ConsoleColor]::Cyan     # Questions / user input
    $Script:FGCHighLight = [System.ConsoleColor]::Magenta      # Clear highlight text
    $Script:FGCWarning = [System.ConsoleColor]::DarkYellow     # Warnings (classic Yellow)
    $Script:FGCError = [System.ConsoleColor]::Red        # Errors (bright red tone, more visible)

    $Script:ConsoleBGColor = [System.ConsoleColor]::Black    # Background remains black
    $Script:ConsoleFGColor = [System.ConsoleColor]::Gray     # Default text gray





    If ($NewStage -eq $Script:PtH) {
        
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "Darkblue"
        $Script:FGCError = "DarkBlue"
        
        Set-NewBackgroundColor -BgC "DarkBlue" -FgC "White"

    }
    elseif ($NewStage -eq $Script:PtT) {
        
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "Yellow"
        $Script:FGCError = "Red"
        
        Set-NewBackgroundColor -BgC "Black" -FgC "White"
    }
    elseif ($NewStage -eq $Script:GoldenTicket) {
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "Yellow"
        $Script:FGCError = "Black"
        
        Set-NewBackgroundColor -BgC "DarkRed" -FgC "White"
    }
    else {
        $Script:FGCCommand = [System.ConsoleColor]::White
        $Script:FGCQuestion = [System.ConsoleColor]::Cyan
        $Script:FGCHighLight = "YELLOW" 
        $Script:FGCError = "RED"
        Set-NewBackgroundColor -BgC "Black" -FgC "Gray"
    }

    Write-Log -Message "    >> Set Color Schema for $NewStage"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}