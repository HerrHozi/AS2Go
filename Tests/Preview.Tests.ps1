$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$publicFiles = Get-ChildItem "$root/Public/*.ps1"
foreach ($file in @($publicFiles) + @(Get-Item "$root/Private/Show-AS2GoPreview.ps1")) {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
# Dot-source declarations only: module import has unrelated initialization side effects.
foreach ($file in $publicFiles) { . $file.FullName }
$script:seen = @()
function Show-AS2GoPreview {
    param($FunctionName, [switch]$UnAttended)
    $script:seen += $FunctionName
}
foreach ($file in $publicFiles) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    $functions = $ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $false)
    foreach ($fn in $functions) {
        $before = $script:seen.Count
        & $fn.Name -Preview
        if ($script:seen.Count -ne $before + 1 -or $script:seen[-1] -ne $fn.Name) { throw "Missing preview guard: $($fn.Name)" }
    }
}
# Load real declarations in an isolated module, but never run their bodies.
$module = New-Module -ArgumentList $root -ScriptBlock {
    param($root)
    Get-ChildItem "$root/Private/*.ps1", "$root/Public/*.ps1" | ForEach-Object { . $_.FullName }
    $script:route = [System.Collections.Generic.Queue[string]]::new()
    @('Invoke-ASPhase07PrivilegeEscalation', 'Invoke-KerberoastingAttack', 'Invoke-Kerberoasting', 'User', 'Back', 'Back', 'Back') | ForEach-Object { $script:route.Enqueue($_) }
    function Show-AS2GoPreviewChoice {
        param($Title, $Options)
        if ($script:route.Count -eq 0) { throw "Unexpected menu: $Title" }
        $next = $script:route.Dequeue()
        if ($next -notin $Options.Value) { throw "Missing preview option '$next' in $Title" }
        return $next
    }
    Show-AS2GoPreview -FunctionName 'Start-AS2GoDemo'
    if ($script:route.Count -ne 0) { throw 'Preview route did not finish.' }
    # Walk every reachable step without invoking any live function body.
    Show-AS2GoPreview -FunctionName 'Start-AS2GoDemo' -UnAttended 6>$null
}
Write-Host "PASS: $($script:seen.Count) public preview guards; offline Kerberoasting and workflow navigation."
