function Get-FileVersion {

    Param(
        [Parameter(Mandatory = $True)][string]$fullname
    )

    $Info = Measure-FunctionRuntime -Begin

    If ((Test-Path -Path $fullname -PathType Leaf) -eq $false) {
        $release = "failed"
        #       Write-Host "WARNING: Cannot find file - $fullname!" -ForegroundColor $Script:FGCWarning
        #       Write-Log -Message "WARNING: Cannot find file - $fullname!" -level WARN

        Write-AS2GoOutput -Type  Warning -M "Cannot find file - $fullname!"

        If ($fullname.ToUpper() -eq $Script:ConfigFile.ToUpper()) {
            Write-Host "`n`nProbably you started the PoSH Script $scriptName `nfrom the wrong directory $Script:ConfigFile!" -ForegroundColor $Script:FGCError
            return
        }
    }
    else {
        [datetime] $LastWriteTime = (get-item $fullname).LastWriteTime
        [String]   $FileVersion = (get-item $fullname).VersionInfo.FileVersion
        $build = Get-date -date $LastWriteTime -Format yyyyMMdd
        $release = ("Release: " + $FileVersion.PadRight(9, [Char]32) + "(last build $build)")
        Write-Log -Message "    >> Version of $fullname is $release!"
    }


    Measure-FunctionRuntime -End -Details $Info
    return $release 
}
