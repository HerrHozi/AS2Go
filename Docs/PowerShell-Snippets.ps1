# AS2Go - Top 10 reusable PowerShell call snippets
# Copy the code inside one comment block into your AS2Go function or script.
# This file intentionally contains no executable statements.
# Most helpers are private: use them inside the AS2Go module context, where
# logging, colors, configuration paths, and supporting functions are initialized.
# Import-Module alone does not normally expose private helpers to the caller.

#region 01 - Yes / No decision (default: No)
<#
$Options = @(
    [pscustomobject]@{
        Label = '&Yes'
        Help  = 'Continue with this step'
        Value = $true
    }
    [pscustomobject]@{
        Label = '&No'
        Help  = 'Cancel this step'
        Value = $false
    }
)

$Proceed = Show-DecisionPrompt `
    -Title 'Continue with this step?' `
    -Options $Options `
    -Default 1

if ($Proceed) {
    Write-Host 'Continuing...'
}
#>
#endregion

#region 02 - Custom menu with named return values
<#
$Options = @(
    [pscustomobject]@{
        Label = '&View'
        Help  = 'View the current settings'
        Value = 'View'
    }
    [pscustomobject]@{
        Label = '&Edit'
        Help  = 'Edit the current settings'
        Value = 'Edit'
    }
    [pscustomobject]@{
        Label = '&Skip'
        Help  = 'Skip this step'
        Value = 'Skip'
    }
)

$Selection = Show-DecisionPrompt -Title 'Select an action' -Options $Options -Default 2

switch ($Selection) {
    'View' { Write-Host 'View selected.' }
    'Edit' { Write-Host 'Edit selected.' }
    'Skip' { Write-Host 'Step skipped.' }
}
#>
#endregion

#region 03 - Build a menu from objects with automatic keyboard shortcuts
<#
$Targets = @(
    [pscustomobject]@{ Name = 'Development'; Description = 'Development environment'; Id = 'Dev' }
    [pscustomobject]@{ Name = 'Training'; Description = 'Training environment'; Id = 'Lab' }
)

$Options = @($Targets | New-HelpOptions -Label Name -Help Description -Value Id)
$SelectedId = Show-DecisionPrompt -Title 'Select an environment' -Options $Options

Write-Host "Selected environment: $SelectedId"
#>
#endregion

#region 04 - Text input with a default value
# Get-Answer returns uppercase text and logs the answer; do not use for secrets.
<#
$EnvironmentName = Get-Answer -Question 'Environment name' -DefaultValue 'LAB'
Write-Host "Selected environment: $EnvironmentName"
#>
#endregion

#region 05 - Consistent status output and command syntax highlighting
<#
Write-AS2GoOutput -Type Header -Message 'Configuration Review'
Write-AS2GoOutput -Type Info -Message 'Reading the current settings.' -NoExtraLines
Write-AS2GoOutput -Type Success -Message 'Settings loaded successfully.' -NoExtraLines
Write-AS2GoOutput -Type Warning -Message 'Review the selected environment before continuing.'

Write-AS2GoOutput -Type NextCommand -NoNewLine
Write-AS2GoOutput -Type Command -Message "Get-Command -Module 'AS2Go'" -NoExtraLines
# Command displays the supplied text; it does not execute it.
#>
#endregion

#region 06 - Measure and log a function's runtime, including early returns
# Paste this pattern inside a function body; finally also runs on return or error.
<#
$Info = Measure-FunctionRuntime -Begin
try {
    Write-AS2GoOutput -Type Info -Message 'Processing the current step.'
    # Place the function's work here.
}
finally {
    Measure-FunctionRuntime -End -Details $Info
}
#>
#endregion

#region 07 - Save and read a JSON configuration setting
# Saving writes to the configured AS2Go settings file.
<#
Set-ASConfig -Setting 'SnippetExampleEnvironment' -Value 'LAB'
$EnvironmentName = Get-ASConfig -Setting 'SnippetExampleEnvironment'
Write-Host "Configured environment: $EnvironmentName"

# Optional Windows DPAPI protection for sensitive values:
# $SensitiveValue must already contain the value to protect.
# Set-ASConfig -Setting 'SnippetExampleProtectedValue' -Value $SensitiveValue -DPAPI
# $SensitiveValue = Get-ASConfig -Setting 'SnippetExampleProtectedValue' -DPAPI
# Protection is scoped to this Windows computer, not to an individual user.
#>
#endregion

#region 08 - Generate a password using cryptographic randomness
# Uses the current Get-RandomPassword implementation, not Get-RandomPassword_old.
<#
$GeneratedPassword = Get-RandomPassword
# Pass the value directly to the operation that needs it; avoid displaying or logging it.
#>
#endregion

#region 09 - Validate AD input formats without querying AD or DNS
<#
$DomainName = 'lab.example.com'
$OrganizationalUnit = 'OU=Training,DC=lab,DC=example,DC=com'

if (-not (Test-ADFormat -Type FQDN -Value $DomainName)) {
    throw 'Enter a valid fully qualified domain name.'
}

if (-not (Test-ADFormat -Type OU -Value $OrganizationalUnit)) {
    throw 'Enter a valid organizational unit distinguished name.'
}

Write-Host 'Both input formats are valid.'
#>
#endregion

#region 10 - Select an AD user through a graphical tree view
# Requires Windows Forms and access to Active Directory.
<#
$SelectedDistinguishedName = Select-ADObject `
    -Title 'Select an Active Directory user' `
    -LocalDomainOnly `
    -IncludeUsers `
    -BlockOUSelection

if ($SelectedDistinguishedName) {
    Write-Host "Selected object: $SelectedDistinguishedName"
}
else {
    Write-Host 'Selection canceled.'
}
#>
#endregion
