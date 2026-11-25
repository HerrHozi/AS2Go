function Initialize-ConsoleColors {

    ################################################################################
    #####                                                                      ##### 
    #####    Load console colors from JSON configuration                       #####                               
    #####                                                                      #####
    ################################################################################
    
    param(
        [string]$JsonPath = (Join-Path -Path $ASModulePath -ChildPath "Config\UserInterface.json"),
        [switch]$AfterEscalation
    )

    $info = Measure-FunctionRuntime -Begin
    if (-not (Test-Path -Path $JsonPath)) {
        Write-AS2GoOutput -Type Warning -Message "Console color config not found: $JsonPath"
        return
    }

    try {
        $config = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json

        foreach ($property in $config.Settings.ConsoleColors.($AfterEscalation ? "AfterEscalation" : "BeforeEscalation").PSObject.Properties) {
            $name = $property.Name
            $entry = $property.Value

            $colorName = $entry.value
            $description = $entry.description

            if ($colorName -eq "Default") {
                $colorName = [System.ConsoleColor]::Gray
            }

            try {
                $resolvedColor = [System.ConsoleColor]::$colorName
            }
            catch {
                $resolvedColor = [System.ConsoleColor]::Gray
            }

            Set-Variable -Scope Script -Name $name -Value $resolvedColor -Force
            Write-log -Level INFO -Message  "   >> $name | $resolvedColor | $description"
        }
    }
    catch {
        Write-AS2GoOutput -Type Warning -Message "Failed to load console colors from JSON: $JsonPath"
    }

    Measure-FunctionRuntime -End -Details $info
}





