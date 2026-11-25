function Update-WindowTitle {

    Param(
        [Parameter(Mandatory = $True)]
        [string]$NewTitle
    )
    
    $Info = Measure-FunctionRuntime -Begin
    
    $host.ui.RawUI.WindowTitle = $NewTitle
    Write-Log -Message "    >> Changed window title to $NewTitle"

    Measure-FunctionRuntime -End -Details $Info 
}
