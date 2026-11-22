
function New-FunctionExample {

    Param(
        [string]$EnableLogging
    )

    $info = Measure-FunctionRuntime -Begin

    #<neuer code>
    # @{N = 'whencreated'; E = { Convert-FromUnixTime -seconds $_.whencreated -objectType 'User' -type 'whencreated' } }

    Write-Log -Message "    >> using "

$Options = @(
    [pscustomobject] @{
        Label = "&Yes"
        Help  = "YES to proceed"
        Value = $Script:Yes
    },
    [pscustomobject] @{
        Label = "&No"
        Help  = "NO to cancel"
        Value = $Script:No
    },
    [pscustomobject] @{
        Label = "&Skip"
        Help  = "SKIP to bypass this operation"
        Value = $Script:Skip
    }
)

$Title = "Decision Required"
$message = "Please make a decision:"
$answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title


$results = gci
$results | Where-Object { $_.Name -match 'Agent|License' } | Select-Object ObjectClass, Name, @{N = 'Name1'; E = { $_.Name.ToLower() } }, ObjectGUID


$Options = @(
    [pscustomobject] @{
        Label = "&Yes"
        Help  = "YES to proceed"
        Value = $Script:Yes
    },
    [pscustomobject] @{
        Label = "&No"
        Help  = "NO to cancel"
        Value = $Script:No
    },
    [pscustomobject] @{
        Label = "&Skip"
        Help  = "SKIP to bypass this operation"
        Value = $Script:Skip
    }
)

$Title = "Decision Required"
$message = "Please make a decision:"
$answer = Show-DecisionPrompt -Message $message -Options $Options -Default 0 -Title $title


    

    If ($Script:Yes -ne $(Show-DecisionPrompt)) {
        Write-AS2GoOutput -Type Info -Message "User chose not to proceed this operation"
        return
    }

    Measure-FunctionRuntime -End -Details $info
}