function Get-SessionsOnDC {

    Param([string]$server)

    $Info = Measure-FunctionRuntime -Begin

    $tool = Join-Path -Path $Script:ASTools -ChildPath "NetSess.exe"
    Invoke-Command -ScriptBlock { param($tool, $server) & $tool $server } -ArgumentList $tool, $server | out-host

    Write-Log -Message "    >> Using DC $server!"
    Measure-FunctionRuntime -End -Details $Info
}
