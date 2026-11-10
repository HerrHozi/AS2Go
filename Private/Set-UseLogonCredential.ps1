function Set-UseLogonCredential {

    ################################################################################
    #####                                                                      ##### 
    #####    Set value for UseLogonCredential to 1                             #####                             
    #####                                                                      #####
    ################################################################################

    $Info = Measure-FunctionRuntime -Begin

    write-as2gooutput -Type Header -Message "Enable UseLogonCredential to read credentials from memory"
    Write-AS2GoOutput -Type Command -Message "Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest -Name UseLogonCredential -Value 1"
  
    If ($Script:Yes = Show-DecisionPrompt) {
        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest -Name UseLogonCredential -value 1
        Invoke-Command -ScriptBlock { gpupdate /force /wait:0 }
        Write-AS2GoOutput -Type Success -Message "UseLogonCredential has been set to 1. Logoff / Logon may be required for changes to take effect."
    }



    Measure-FunctionRuntime -End -Details $info
}
