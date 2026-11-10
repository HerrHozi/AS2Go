<#
.SYNOPSIS
Browses an AS2Go workflow offline.

.DESCRIPTION
Reads the function's help and PowerShell command syntax tree to build a preview.
Shows eligible AS2Go calls as menu items and displays literal commands for steps without a submenu.
Kerberoasting offers a display-only domain choice. Runtime conditions and skip switches are not evaluated.

.PARAMETER FunctionName
Name of the AS2Go function to preview.

.PARAMETER UnAttended
Displays reachable steps without prompting.

.PARAMETER Visited
Tracks the current navigation path to prevent recursive calls from looping.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Shows AS2Go workflow descriptions and commands without running the workflow or connecting to Active Directory.
#>
function Show-AS2GoPreview {

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'EnableLogging',
        Justification = 'Write-Log reads this variable from the calling scope.')]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,
        [switch]$UnAttended,
        [string[]]$Visited = @()
    )

    # Keep the shared output and timing helpers from writing logs during preview.
    $EnableLogging = $false
    $info = Measure-FunctionRuntime -Begin

    try {
        if ($FunctionName -in $Visited) { return }

        $command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
        $ast = $command.ScriptBlock.Ast

        Write-AS2GoOutput -Type Header -Message "$FunctionName - Preview Mode"
        Write-AS2GoOutput -Type H1 -Message $((Get-Help (Get-FunctionName)).Functionality)

        $help = $ast.GetHelpContent()
        if ($help) {
            $description = $help.Functionality
            if (-not $description) { $description = $help.Description }
            if (-not $description) { $description = $help.Synopsis }
            Write-AS2GoOutput -Type Info -Message $description -NoExtraLines
        }

        if ($FunctionName -eq 'Start-Kerberoasting') {
            Write-AS2GoOutput -Type Command -Message '.\Rubeus.exe kerberoast /ldapfilter:admincount=1 /domain:<domain> /dc:<dc> /outfile:<exfiltration>\KR-<domain>.hashes.txt'
            if (-not $UnAttended) {
                $options = @(
                    [pscustomobject]@{ Label = 'Current User Domain'; Help = 'Use a placeholder for the current user domain.'; Value = 'User' }
                    [pscustomobject]@{ Label = 'Specific Domain'; Help = 'Enter a domain for display only.'; Value = 'Domain' }
                    [pscustomobject]@{ Label = 'Skip'; Help = 'Return to the previous menu.'; Value = 'Skip' }
                )
                $choice = Show-AS2GoPreviewChoice -Title 'Kerberoasting Attack - Select Target Domain' -Options $options
                if ($choice -eq 'Skip') { return }

                $domain = '<domain>'
                if ($choice -eq 'Domain') {
                    $domain = Read-Host 'Domain (display only)'
                }
                Write-AS2GoOutput -Type Info -Message "Preview target: $domain" -NoExtraLines
            }
            return
        }

        # Inspect command syntax without evaluating source expressions.
        $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)
        $children = @()
        foreach ($call in $calls) {
            $name = $call.GetCommandName()
            if (-not $name -or $name -eq $FunctionName -or $name -in $children) { continue }

            $target = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
            if (-not $target -or $target.ModuleName -ne $command.ModuleName) { continue }

            if ($name -eq 'Start-Kerberoasting') {
                $children += $name
                continue
            }

            if ($name -match '^(Invoke-|New-|Add-|Remove-|Set-|Restart-|Install-|Export-|Request-|Search-|Get-)') {
                # Infrastructure and formatting helpers are not workflow steps.
                if ($name -match '^(Get-(AS2GoSettings|Function|ASConfig|RunTime)|Set-(ASConfig|NewColor|NewBackground|BestDomain|AttackScope)|New-PrivilegeEscalationRecommendation)') { continue }
                $targetHelp = $target.ScriptBlock.Ast.GetHelpContent()
                if (($target.ScriptBlock.File -like '*Public*') -or ($targetHelp -and $targetHelp.Component -match 'Main Function')) {
                    $children += $name
                }
            }
        }

        if ($children.Count -eq 0) {
            Write-AS2GoOutput -Type NextCommand -Message 'Commands from source (display only)'
            foreach ($call in $calls) {
                if ($call.GetCommandName() -notmatch '^(Write-|Show-|Measure-|Get-(Function|Help$)|Out-|Clear-Host|Pause|Start-Sleep)') {
                    Write-AS2GoOutput -Type Command -Message $call.Extent.Text -NoExtraLines
                }
            }
            return
        }

        if ($UnAttended) {
            foreach ($child in $children) {
                Show-AS2GoPreview -FunctionName $child -UnAttended -Visited ($Visited + $FunctionName)
            }
            return
        }

        $options = @(
            foreach ($child in $children) {
                [pscustomobject]@{ Label = $child; Help = 'Show the step description and commands.'; Value = $child }
            }
            [pscustomobject]@{ Label = 'Back / Exit'; Help = 'Return to the previous menu.'; Value = 'Back' }
        )

        do {
            $choice = Show-AS2GoPreviewChoice -Title "$FunctionName - Preview" -Options $options
            if ($choice -ne 'Back') {
                Show-AS2GoPreview -FunctionName $choice -Visited ($Visited + $FunctionName)
            }
        } until ($choice -eq 'Back')
    }
    finally {
        Measure-FunctionRuntime -End -Details $info
    }
}

<#
.SYNOPSIS
Prompts for a numbered AS2Go preview option.

.PARAMETER Title
Menu title.

.PARAMETER Options
Menu entries with Label, Help, and Value properties. Enter selects the final entry.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Displays a numbered preview menu and returns the selected option.
#>
function Show-AS2GoPreviewChoice {

    param(
        [string]$Title,
        [object[]]$Options
    )

    $info = Measure-FunctionRuntime -Begin

    Write-AS2GoOutput -Type NextCommand -Message $Title -NoExtraLines
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i].Label)"
    }

    $index = $Options.Count - 1
    do {
        $answer = Read-Host 'Choose a preview step (Enter = Back / Skip, ? = Help)'
        if ([string]::IsNullOrWhiteSpace($answer)) { break }
        if ($answer -eq '?') {
            foreach ($option in $Options) {
                Write-AS2GoOutput -Type Info -Message "$($option.Label): $($option.Help)" -NoExtraLines
            }
        }

        $number = 0
        $valid = [int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Options.Count
        if ($valid) { $index = $number - 1 }
    } until ($valid)

    Measure-FunctionRuntime -End -Details $info
    return $Options[$index].Value
}
