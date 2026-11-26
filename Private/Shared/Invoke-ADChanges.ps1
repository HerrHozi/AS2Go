function Invoke-ADChanges {

    Param(
        [string]$EnableLogging
    )

    $info = Measure-FunctionRuntime -Begin
    
    $Klist = Get-KlistTicket | Select-Object -Last 1
    $title = "KLIST | Client | $($klist.client) @ $($klist.clientdomain)"
    $Version = "Make some changes to AD objects, e.g. enable/disable accounts or reset passwords"
    
    Write-AS2GoOutput -Type Important -Note "Check for Windows Form to enable AD changes! To continue, click on the form and then click on the 'Close' button." -message "`n      If you don't see the form, check if it is hidden behind other windows."
  
    $null = Select-ADObject -AddOU -Title $title -Close -IncludeUsers -IncludeGroups -IncludeComputers -Version $Version

    Measure-FunctionRuntime -End -Details $info
}