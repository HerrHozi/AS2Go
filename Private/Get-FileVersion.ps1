function Get-FileVersion {

    Param(
        [Parameter(Mandatory = $True)]
        [string]$fullname
    )

    $Info = Measure-FunctionRuntime -Begin

    If ((Test-Path -Path $fullname -PathType Leaf) -eq $false) {
            $result = $false
        Write-AS2GoOutput -Type Warning -M "Cannot find file - $fullname!" -NoExtraLines
    }
    else {
        [datetime] $LastWriteTime = (get-item $fullname).LastWriteTime
        [String]   $FileVersion = (get-item $fullname).VersionInfo.FileVersion
        $build = Get-date -date $LastWriteTime -Format yyyyMMdd
        $release = ("Release: " + $FileVersion.PadRight(9, [Char]32) + "(last build $build)")
        Write-AS2GoOutput -Type Bullet -Message  "Version of $fullname is $release!"
        $result = $true
    }

    Measure-FunctionRuntime -End -Details $Info
    return $result 
}