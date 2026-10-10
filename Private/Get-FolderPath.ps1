<#
.SYNOPSIS
Opens a folder picker and returns the selected path.

.FUNCTIONALITY
Returns the chosen folder path, or null if the user cancels the dialog.
#>
function Get-FolderPath {
    param(
        [string]$InitialDirectory = '',
        [string]$Description = 'Select Folder'
    )

    Add-Type -AssemblyName System.Windows.Forms
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = $Description
    $fbd.RootFolder = 'MyComputer'
    if ($InitialDirectory) { $fbd.SelectedPath = $InitialDirectory }

    if ($fbd.ShowDialog() -eq 'OK') {
        return $fbd.SelectedPath
    }
    return $null
}

# Test
#$path = Get-FolderPath -InitialDirectory 'C:\' -Description 'Please select a folder:'
