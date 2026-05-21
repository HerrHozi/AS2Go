function Test-AccessDirectory {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$directory
    )

    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################

    [bool]$passed = $false

    Invoke-output -Type Codesnippet -Message "Command to access directory '$directory':"

    Write-Highlight -Text "Get-ChildItem ", "$directory ", "-filter ", "*.*" `
        -Color $fgcC, $fgcF, $fgcS, $fgcF
    Write-Host ""

    Try {
        Get-ChildItem -Path $directory -Force -ErrorAction Stop | Out-Host
        $passed = $true
    }
    catch {
        Invoke-Output -Type Error -Message "Failed to access directory '$directory'."
    }

    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"

    return $passed
}
