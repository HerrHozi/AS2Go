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
