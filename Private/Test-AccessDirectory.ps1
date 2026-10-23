function Test-AccessDirectory {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$directory
    )

    $Info = Measure-FunctionRuntime -Begin

    [bool]$passed = $false

    

    Write-AS2GoOutput -Type Codesnippet -Message "Command to access directory '$directory':"

    Write-Highlight -Text "Get-ChildItem ", "$directory ", "-filter ", "*.*" `
        -Color $fgcC, $fgcF, $fgcS, $fgcF
    Write-Host ""

    Try {
        Get-ChildItem -Path $directory -Force -ErrorAction Stop | Out-Host
        $passed = $true
    }
    catch {
        Write-AS2GoOutput -Type Error -Message "Failed to access directory '$directory'."
    }

    Measure-FunctionRuntime -End -Details $Info

    return $passed
}
