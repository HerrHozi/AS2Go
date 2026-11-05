function Show-AS2GoPreview {
    <#
    .SYNOPSIS
    Browses workflow source and help without executing workflow code.
    .DESCRIPTION
    Uses the parsed call graph for offline navigation. Source expressions are displayed
    literally and are never evaluated. No workflow setup, AD queries or tools run.
    #>
    param(
        [Parameter(Mandatory)][string]$FunctionName,
        [switch]$UnAttended,
        [string[]]$Visited = @()
    )

    if ($FunctionName -in $Visited) { return }
    $command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction Stop
    $ast = $command.ScriptBlock.Ast
    Write-Host "`n______________________________________________________________________" -ForegroundColor DarkGray
    Write-Host "`n  $FunctionName — Preview Mode" -ForegroundColor Cyan
    Write-Host '______________________________________________________________________' -ForegroundColor DarkGray
    Write-Host '  [Preview] Execution disabled. No AD connection required.' -ForegroundColor Yellow
    $help = $ast.GetHelpContent()
    if ($help) {
        $description = $help.Functionality
        if (-not $description) { $description = $help.Description }
        if (-not $description) { $description = $help.Synopsis }
        Write-Host "`n$description"
    }

    if ($FunctionName -eq 'Start-Kerberoasting') {
        Write-Host "`n  .\Rubeus.exe kerberoast /ldapfilter:admincount=1 /domain:<domain> /dc:<dc> /outfile:<exfiltration>\KR-<domain>.hashes.txt"
        if (-not $UnAttended) {
            $options = @(
                [pscustomobject]@{Label = 'Current &User Domain'; Help = 'Preview the current user domain; no domain lookup is performed.'; Value = 'User' },
                [pscustomobject]@{Label = 'Specific &Domain'; Help = 'Enter a domain for display only.'; Value = 'Domain' },
                [pscustomobject]@{Label = '&Skip'; Help = 'Return to the previous menu.'; Value = 'Skip' }
            )
            $choice = Show-AS2GoPreviewChoice -Title 'Kerberoasting Attack - Select Target Domain' -Options $options
            if ($choice -eq 'Skip') { return }
            $domain = '<domain>'
            if ($choice -eq 'Domain') { $domain = Read-Host 'Domain (display only)' }
            Write-Host "[Preview] Target: $domain. Execution skipped." -ForegroundColor Yellow
        }
        return
    }

    # Only inspect command ASTs. Never invoke or expand source expressions.
    $calls = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
    $children = @()
    foreach ($call in $calls) {
        $name = $call.GetCommandName()
        if (-not $name -or $name -eq $FunctionName -or $name -in $children) { continue }
        $target = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
        if (-not $target -or $target.ModuleName -ne $command.ModuleName) { continue }
        if ($name -match '^(Invoke-|New-|Add-|Remove-|Set-|Restart-|Install-|Export-|Request-|Search-|Get-)') {
            # Infrastructure and formatting helpers are not workflow steps.
            if ($name -match '^(Get-(AS2GoSettings|Function|ASConfig|RunTime)|Set-(ASConfig|NewColor|NewBackground|BestDomain|AttackScope)|New-PrivilegeEscalationRecommendation)') { continue }
            $targetHelp = $target.ScriptBlock.Ast.GetHelpContent()
            if (($target.ScriptBlock.File -like '*Public*') -or ($targetHelp -and $targetHelp.Component -match 'Main Function') -or $name -eq 'Start-Kerberoasting') {
                $children += $name
            }
        }
    }


    if ($children.Count -eq 0) {
        Write-Host "`n[Preview] Planned source (display only):" -ForegroundColor Cyan
        foreach ($call in $calls) {
            if ($call.GetCommandName() -notmatch '^(Write-|Show-|Measure-|Get-Function|Out-|Clear-Host|Pause|Start-Sleep)') {
                Write-Host $call.Extent.Text
            }
        }
        Write-Host '[Preview] Execution skipped.' -ForegroundColor Yellow
        return
    }
    if ($UnAttended) {
        foreach ($child in $children) {
            Show-AS2GoPreview -FunctionName $child -UnAttended -Visited ($Visited + $FunctionName)
        }
        return
    }
    do {
        $options = @()
        for ($i = 0; $i -lt $children.Count; $i++) {
            $options += [pscustomobject]@{Label = $children[$i]; Help = 'Show description and planned steps without execution.'; Value = $children[$i] }
        }
        $options += [pscustomobject]@{Label = 'Back / Exit'; Help = 'Return to the previous menu.'; Value = 'Back' }
        $choice = Show-AS2GoPreviewChoice -Title "$FunctionName — Preview" -Options $options
        if ($choice -ne 'Back') { Show-AS2GoPreview -FunctionName $choice -Visited ($Visited + $FunctionName) }
    } until ($choice -eq 'Back')
}

function Show-AS2GoPreviewChoice {
    param([string]$Title, [object[]]$Options)
    # Do not use the live prompt helper: its runtime and logging hooks write files.
    Write-Host "`n[>] $Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Options[$i].Label -replace '&', '')"
    }
    do {
        $answer = Read-Host 'Choose a preview step (Enter = Back / Skip)'
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Options[-1].Value }
        if ($answer -eq '?') {
            $Options | ForEach-Object { Write-Host "$($_.Label -replace '&', ''): $($_.Help)" }
        }
        $number = 0
        $valid = [int]::TryParse($answer, [ref]$number) -and $number -ge 1 -and $number -le $Options.Count
    } until ($valid)
    return $Options[$number - 1].Value
}