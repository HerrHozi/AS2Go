<#
.SYNOPSIS
Moves artifacts from the exfiltration folder to the cleanup folder.

.DESCRIPTION
Creates the cleanup folder when needed, then moves matching NTDS and other exfiltration files
out of the active exfiltration folder to prepare it for another lab run.

.FUNCTIONALITY
Moves selected exfiltration artifacts to the cleanup folder for a clean lab run.

.COMPONENT
Category: Sub Function
#>
function Clear-ExfiltrationFolder {

    $Info = Measure-FunctionRuntime -Begin

    # clean-up AS2Go Folder
    New-Item -Path $Script:DefautCleanUpFolder -ItemType Directory  -ErrorAction Ignore | Out-Null
    
    try {
        Get-ChildItem ??-*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
        Get-ChildItem ntds_capi_*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
        Get-ChildItem ntds_legacy_*.* -Path $Script:DefautExfiltrationFolder | Move-Item -Destination $Script:DefautCleanUpFolder -Force | Out-Null
    }
    catch {
    
    }

    Measure-FunctionRuntime -End -Details $Info 
}