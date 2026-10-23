<#
.SYNOPSIS
Checks whether the current user is a local administrator and whether the process is elevated.

.DESCRIPTION
Inspects the current Windows identity and process token to determine local
administrator status, token elevation, and whether the token is filtered by UAC.
Returns these details together with a human-readable description.

.COMPONENT
Category: Sub Function

.FUNCTIONALITY
Reports local administrator membership and the current process elevation state.

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
Test-LocalAdministrator
Returns the current user's local administrator and token elevation status.

.NOTES
This function is intended for Windows and does not accept parameters.
#>
function Test-LocalAdministrator {
    [CmdletBinding()]
    param()

    # Load Windows token API once
    if (-not ('AS2Go.NativeToken' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace AS2Go
{
    public static class NativeToken
    {
        private const uint TOKEN_QUERY = 0x0008;
        private const int TokenElevationType = 18;
        private const int TokenLinkedToken = 19;
        private const int TokenElevation = 20;

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool OpenProcessToken(
            IntPtr ProcessHandle,
            uint DesiredAccess,
            out IntPtr TokenHandle);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool GetTokenInformation(
            IntPtr TokenHandle,
            int TokenInformationClass,
            out int TokenInformation,
            int TokenInformationLength,
            out int ReturnLength);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool GetTokenInformation(
            IntPtr TokenHandle,
            int TokenInformationClass,
            out IntPtr TokenInformation,
            int TokenInformationLength,
            out int ReturnLength);

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr Handle);

        private static int ReadInt(IntPtr token, int infoClass)
        {
            int value;
            int length;

            if (!GetTokenInformation(
                token, infoClass, out value, sizeof(int),
                out length))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error());
            }

            return value;
        }

        public static int[] GetStatus()
        {
            IntPtr token = IntPtr.Zero;

            if (!OpenProcessToken(
                GetCurrentProcess(), TOKEN_QUERY, out token))
            {
                throw new Win32Exception(
                    Marshal.GetLastWin32Error());
            }

            try
            {
                int type = ReadInt(token, TokenElevationType);
                int elevated = ReadInt(token, TokenElevation);

                // Limited tokens have a linked elevated token.
                // Full tokens are already elevated.
                // Default tokens require a separate membership check.
                return new int[] { type, elevated };
            }
            finally
            {
                CloseHandle(token);
            }
        }
    }
}
'@ -ErrorAction Stop
    }


    $Info = Measure-FunctionRuntime -Begin

    $Identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [System.Security.Principal.WindowsPrincipal]::new($Identity)

    $TokenStatus = [AS2Go.NativeToken]::GetStatus()

    $ElevationType = switch ($TokenStatus[0]) {
        1 { 'Default' }
        2 { 'Full' }
        3 { 'Limited' }
        default { 'Unknown' }
    }

    $IsElevated = $Principal.IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator
    )

    # Full and Limited indicate an administrator split token.
    # Default tokens require an enabled administrator SID check.
    $IsLocalAdmin = if ($ElevationType -in @('Full', 'Limited')) {
        $true
    }
    else {
        $IsElevated
    }

    # Determine administrator status
    $IsUACFiltered = ($ElevationType -eq 'Limited')

    $Description = if ($IsLocalAdmin -and $IsElevated) {
        'Local administrator with elevated privileges (full administrative access).'
    }
    elseif ($IsLocalAdmin -and $IsUACFiltered) {
        'Local administrator running with a UAC-filtered token (elevation required).'
    }
    elseif ($IsLocalAdmin) {
        'Local administrator without active administrative privileges.'
    }
    else {
        'Standard user without local administrator privileges.'
    }


    Measure-FunctionRuntime -End -Details $Info 
    [pscustomobject]@{
        ComputerName  = $env:COMPUTERNAME
        UserName      = $Identity.Name
        IsLocalAdmin  = $IsLocalAdmin
        IsElevated    = $IsElevated
        IsUACFiltered = $IsUACFiltered
        ElevationType = $ElevationType
        Description   = $Description
    }
}



