<#
.SYNOPSIS
Formats a table and highlights rows matching a selected value.

.FUNCTIONALITY
Builds aligned columns and colors rows that match the requested column value.
#>
function Set-TextMarker {

    ################################################################################
    #####                                                                      ##### 
    #####    Format and highlight rows in a table for a special value          #####                                 
    #####                                                                      #####
    ################################################################################
  
  
    Param($OldFormat, [string] $column, [string] $value, [string] $color, [string] $column2, [string] $value2)
  
    $CurrentFunction = Get-FunctionName
    Write-Log -Message "### Start Function $CurrentFunction ###"
    $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
    #################### main code | out- host #####################
  
    If ($OldFormat.count -eq 1) {
        $oldformat | Format-Table | out-host
        return
    }

    # get all column names
    $ColumnNames = $OldFormat[0].PSObject.Properties.Name
  
    #get the witdh for each column
    $ColumnWitdth = @()
    foreach ($ColumnName in $ColumnNames) {
        $i = $ColumnName.Length
        Foreach ($result in $OldFormat) {
            try {
                If ($result."$ColumnName".tostring().Length -gt $i) { $i = $result."$ColumnName".tostring().Length } 
            }
            catch {
                <#Do this if a terminating exception happens#>
            }
        }
        $i += 1
        $ColumnWitdth += $i.ToString()
    }
  
    #create the header
    Write-Host ""
    $row = ""
    for ($i = 0; $i -lt $ColumnNames.Count; $i++) {
        [int]$cw = $ColumnWitdth[$i]
        [string]$cn = $ColumnNames[$i]
        $row += $cn.PadRight($cw, " ")
    }
    Write-Host $row -ForegroundColor $fgcHeader
  
    #create the separator between header & values
    $row = ""
    for ($i = 0; $i -lt $ColumnNames.Count; $i++) {
        [int]$cw = $ColumnWitdth[$i]
        [string]$cn = $ColumnNames[$i]
        $cn = $cn -replace ".", "-"
        $row += $cn.PadRight($cw, " ")
    }
    Write-Host $row -ForegroundColor $fgcHeader
  
    #create the rows
    Foreach ($result in $OldFormat) {
        [string]$row = ""
        [bool]$highlight = $false
  
        for ($i = 0; $i -lt $ColumnNames.Count; $i++) {
  
            [int]$cw = $ColumnWitdth[$i]
            [string]$cn = $ColumnNames[$i]
            [string]$test = $result."$cn"
            $row += $test.PadRight($cw, " ")

            If ($column -ne "") {
                if ([string]$result."$column" -eq $value) { $highlight = $true }
            }
            else {
                if (([string]$result."$column" -eq $value) -and ([string]$result."$column2" -eq $value2)) { $highlight = $true }
            }
    
        }
        
        If ($highlight -eq $true) {
            Write-Host $row -ForegroundColor $Color | Out-Host
        }
        else {
            Write-Host $row | Out-Host
        }
    }
    Write-Host ""
    Write-Log -Message "    >> using column: $column - value: $value - color: $color"
    ######################## main code ############################
    $runtime = Get-RunTime -StartRunTime $StartRunTime
    Write-Log -Message "    Run Time: $runtime [h] ###"
    Write-Log -Message "### End Function $CurrentFunction ###"
}
