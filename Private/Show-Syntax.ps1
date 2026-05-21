function Write-SyntaxNew {
    param([string]$Code)
    
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tokens, [ref]$errors)
    
    $totalPos = 0
    
    foreach($token in $tokens) {
        # Sicherer Pre-Text
        $preLen = [Math]::Max(0, $token.Extent.StartOffset - $totalPos)
        if($preLen -gt 0 -and $totalPos + $preLen -le $Code.Length) {
            $preText = $Code.Substring($totalPos, $preLen)
            Write-Host $preText -NoNewline -ForegroundColor Gray
        }
        
        # Token farbig
        $color = switch -Regex ($token.Kind) {
            'String|HereString' { 'Green' }
            'If|Else|For|Foreach|Function|While|Do|Until' { 'Cyan' }
            'Generic|Command' { If ($token.TokenFlags -eq 'CommandName') {'Yellow'} else {'White'} }
            'Variable' { 'green' }
            'Number' { 'White' }
            'Identifier' {'White'}
            'StringLiteral' {'Cyan'}
            'Parameter' { 'DarkGray' }
            '^I|Pipe|and' { 'DarkGray' }
            'Operator|GroupStart|GroupEnd|Comment' { 'DarkGray' }
            default { 'White' }
        }
        
        Write-Host $token.Text -NoNewline -ForegroundColor $color
        

        $newPos = [Math]::Min($Code.Length, $token.Extent.EndOffset)
        $totalPos = $newPos
    }
    

    if($totalPos -lt $Code.Length) {
        $rest = $Code.Substring($totalPos)
        Write-Host $rest -NoNewline -ForegroundColor Gray
    }
    
    Write-Host "`n"
}


$code = "Get-PSModuleQuantity -ModuleName .\PSModuleQuantityAnalyzer.psd1 | Where-Object {`$_.Type -eq 'Private' -and `$_.References -eq 0} | ft"

$code = "MATCH (n:Base {highvalue:False})-[r]->(m {highvalue:True}) WHERE NOT type(r) IN ['WriteOwnerRaw','OwnsRaw', 'LocalToComputer']"

$code = "Get-ADUser -SearchBase 'Ldap:\\dsdadf' -Filter 'homePhone -like 1000' -Properties a,b | Select-Object name,asss | Sort-Object samaccountname  | Format-Table | Out-Host"

$code =  "Get-ADGroupMember -Identity 'Domain Admins' -Recursive | Select-Object -First 10 | Format-Table"
#Write-SyntaxNew -Code $code