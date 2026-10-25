<#
.SYNOPSIS
Displays a command using the centralized AS2Go syntax-highlighting output.

.DESCRIPTION
Compatibility wrapper for Write-AS2GoOutput -Type Command. Displays text without executing it.

.PARAMETER Code
Command text to display.

.EXAMPLE
Write-HighlightedCode -Code "Get-Command -Module 'AS2Go'"
Displays the command with syntax highlighting and no surrounding blank lines.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Displays command text through Write-AS2GoOutput with syntax highlighting.
#>
function Write-HighlightedCode {
    param([string]$Code)

    Write-AS2GoOutput -Type Command -Message $Code -NoExtraLines
}
