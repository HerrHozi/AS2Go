function Get-RandomPassword_old {

    $Info = Measure-FunctionRuntime -Begin

    $chars = "abcdefghijkmnopqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ1234567890".ToCharArray()
    $nums = "1234567890".ToCharArray()
    $schars = "+-!()?".ToCharArray()

    $newPassword = ""
    1..9 | ForEach-Object { $newPassword += $chars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    1..3 | ForEach-Object { $newPassword += $chars | Get-Random }
    1..1 | ForEach-Object { $newPassword += $nums | Get-Random }
    1..1 | ForEach-Object { $newPassword += $schars | Get-Random }
    
    Write-Log -Message "    >> New Password: $newPassword"
    Measure-FunctionRuntime -End -Details $Info
    
    return $newPassword
}

function Get-RandomPassword {
    $Info = Measure-FunctionRuntime -Begin

    try {
        $letters = 'abcdefghijkmnopqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ'.ToCharArray()
        $numbers = '1234567890'.ToCharArray()
        $specials = '+-!()?'.ToCharArray()
        $passwordChars = [System.Collections.Generic.List[char]]::new()

        foreach ($set in @(
            @{ Characters = $letters; Count = 10 }
            @{ Characters = $numbers; Count = 3 }
            @{ Characters = $specials; Count = 3 }
        )) {
            for ($i = 0; $i -lt $set.Count; $i++) {
                $index = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32(
                    $set.Characters.Length
                )
                $passwordChars.Add($set.Characters[$index])
            }
        }

        for ($i = $passwordChars.Count - 1; $i -gt 0; $i--) {
            $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($i + 1)
            $temp = $passwordChars[$i]
            $passwordChars[$i] = $passwordChars[$j]
            $passwordChars[$j] = $temp
        }

        $password = -join $passwordChars
        return (-join $password)
    }
    finally {
        Measure-FunctionRuntime -End -Details $Info
    }
}