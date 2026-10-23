function Initialize-AS2GoDirectory {

    ################################################################################
    #####                                                                      ##### 
    #####    Creates the log directory if it does not exist.                   #####                
    #####                                                                      #####
    ################################################################################

    [CmdletBinding()]
    param (
        [String]$Directory
    )
    
    if (-not (Test-Path $Directory)) {
        try {
            New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop
            Write-Log -Message "Initialize-AS2GoDirectory    >> Log directory created: $Directory"
        }
        catch {
            Write-AS2GoOutput -Message "Failed to create log directory: $Directory. Error: $($_.Exception.Message)" -Type Error
            Write-Error "Failed to create $Directory`: $($_.Exception.Message)"
            throw
            return
        }
    }
    else {
        Write-Log -Message "Initialize-AS2GoDirectory:    >> Log directory already exists: $Directory"
    }
}
