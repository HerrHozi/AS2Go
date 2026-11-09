        $ResultList = @($BestResults)
        $Options = @(
            for ($Index = 0; $Index -lt $ResultList.Count; $Index++) {
                $Result = $ResultList[$Index]
                [pscustomobject]@{
                    Label = "$($Result.HelpLabel)"
                    Help  = "Group membership: $($Result.GroupMembership)"
                    Value = $Index
                }
                if ($ResultList[$Index].SID -eq $BestPrincipal.SID) {
                    $defaut = $Index
                }
            }
        )

        $Options += [pscustomobject] @{
            Label = "&Skip"
            Help  = "Skip this selection"
            Value = $Script:No
        }