function New-GpCExtention {

   ################################################################################
   #####                                                                      #####
   #####       Define the new gPCMachineExtensionNames value                  #####
   #####             [{CSE GUID 1}{Tool Extension GUID 1}]                    #####
   #####                                                                      #####
   ################################################################################
  
   Param([string] $OldValue, [string] $CSEGUID, [string] $TOOLGUID)
 
   $CurrentFunction = Get-FunctionName
   Write-Log -Message "### Start Function $CurrentFunction ###"
   $StartRunTime = (Get-Date).ToString($Script:DateFormatLog)
   #################### main code | out- host ####################
    
   #Write-Host "CSE GUID  = $CSEGUID"
   #Write-host "TOOL GUID = $TOOLGUID"
   #Write-Host "Old Value = $OldValue" -ForegroundColor green
    
   #add the default prefix if missing
   If (-not $OldValue.Contains($Script:StartGUID)) {
      $OldValue = "[{00000000-0000-0000-0000-000000000000}]" + $OldValue
   }
 
   $result = $OldValue.split("[")
 
   #skip for User Rights Assignment, not needed
   If ($TOOLGUID -ne $Script:ToolGUIDComputerPolicySettings) {
      #define new prefix
      $prefix = "[" + $result[1]
      $prefix = $prefix.Replace("[", "").Replace("]", "")
      $prefix = $prefix + $TOOLGUID
    
      $tempresult = $prefix.Split("{") | Sort-Object
      $newPreFix = $tempresult -join "{"
      $newPreFix = "[" + $newPreFix + "]"
   }
   else {
      $newPreFix = "[" + $result[1]
   }
    
   #define new postfix
   $postfix = ""
   for ($i = 2; $i -lt $result.Count; $i++) {
      $postfix = $postfix + "[" + $result[$i]
   }
 
   $TempValue = $postfix + "[" + $CSEGUID + $TOOLGUID + "]"
   $result = $TempValue.Split("[") | Sort-Object
   $newPostFix = $result -join "["
 
   $newValue = $newPreFix + $newPostFix 
 
   #Write-Host "New Value = $newValue" -ForegroundColor Cyan
   Write-Log -Message "    >> Cse  GUID = $CSEGUID"
   Write-Log -Message "    >> Tool GUID = $TOOLGUID"
   Write-Log -Message "    >> Old Value = $OldValue"
   Write-Log -Message "    >> New Value = $newValue"
   ######################## main code ############################
   $runtime = Get-RunTime -StartRunTime $StartRunTime
   Write-Log -Message "    Run Time: $runtime [h] ###"
   Write-Log -Message "### End Function $CurrentFunction ###"

   return $newValue
}
