# ASP00 Secure Access Workstation

Use **SAW** in the public `Initialize-AS2GoLab` setup menu to configure the Admin PC used by AS2Go's remote Pass-the-Ticket (PtT) workflow. The menu calls the internal `Set-SecureAccessWorkstation` function; users start this setup through the public menu.

For this scenario, **SAW** identifies the computer on which the simulated attacker has validated Administrator access. It is not a workstation provisioning or hardening function. You can configure the computer running AS2Go itself as the SAW/Admin PC.

## When this setting is needed

Configure an Admin PC when you intend to choose the **remote** route for Pass-the-Ticket in the Phase 07 Privilege Escalation workflow. The local Pass-the-Ticket route operates on the current computer and does not use the configured remote Admin PC in the same way.

In the remote simulation, the attacker has validated Administrator privileges on the Admin PC and uses that access to harvest Kerberos tickets. The workflow stages Mimikatz on the Admin PC, exports and reviews available tickets, then injects a selected ticket pair to demonstrate access as the represented account (for example, SamiraA) without using that account's password.

```text
Initialize-AS2GoLab
└─ Select SAW
   └─ Set-SecureAccessWorkstation
      ├─ Select the Admin PC from Active Directory, type its hostname, or keep the saved host
      ├─ Check WinRM on TCP 5985; optionally offer to enable PowerShell Remoting
      └─ Save the host name in the local AS2Go configuration

Start-AS2GoDemo
└─ Phase 07: Privilege Escalation
   └─ Pass-the-Ticket → Remote
      ├─ Stage Mimikatz on the Admin PC
      ├─ Harvest and review Kerberos tickets
      └─ Inject the selected ticket to demonstrate the represented account's access
```

## Menu option

Run the public setup menu:

```powershell
Initialize-AS2GoLab
```

Select **SAW**. The menu offers these choices:

| Choice | Behavior |
|---|---|
| Previous Secure Access Workstation | Keeps the configured host name. Available when a value is already saved. |
| Select new Secure Access Workstation | Opens the AD Object Picker with computer objects. Select the intended Admin PC. AS2Go reads its `dNSHostName`; if unavailable, it uses the computer object's `name`. |
| Type new Secure Access Workstation | Lets you enter a host name manually. |
| Skip | Leaves the saved value unchanged and returns without checking or changing the selection. |

If the current AS2Go computer is also the Admin PC, select its computer object or enter its host name. No separate remote workstation is required for that configuration.

## WinRM check and remote configuration

After a host is selected or entered, AS2Go saves its host name as `AS2GoSAW` in the local configuration and checks whether TCP port **5985** is reachable. The check only tests reachability; it does not validate that the chosen computer is the intended Admin PC or that all later PtT prerequisites are ready.

If TCP 5985 is not reachable, the function asks whether it should enable PowerShell Remoting on the selected computer. The default is **No**. If you choose **Yes**, it uses a DCOM CIM session to start `Enable-PSRemoting -Force` remotely. This changes the selected computer's remoting configuration and requires appropriate remote administrative access. If you choose **No**, the host name remains configured, but remote PtT may not work until remoting is available.

## Requirements for the remote PtT simulation

Before selecting the remote route, prepare the Admin PC and verify the conditions shown by the phase workflow:

- You have validated Administrator access to the Admin PC.
- Mimikatz is available in the configured AS2Go tools folder and can be staged on the Admin PC.
- Fresh Kerberos tickets for the intended demonstration are present on the Admin PC.
- PowerShell remoting and required file access work between the AS2Go computer and the Admin PC.
- Endpoint-protection changes, if any, are explicitly authorized for the isolated lab.

The remote PtT workflow clears prior ticket staging files before it collects new ticket material. Review the selected hosts and paths before confirming the phase.

## Configuration storage

The host name is saved as `AS2GoSAW` in `%PUBLIC%\AS2Go\Config\AS2Go.json`. This setting is written without the `-DPAPI` option and is stored as readable text. The local JSON file can contain a mixture of ordinary and individually DPAPI-protected settings; DPAPI protection is not applied to the entire file. See [ASP00 Installation and Setup](ASP00__Setup.md) for the shared configuration details.

## Related documentation

- [ASP00 Installation and Setup](ASP00__Setup.md)
- [Public Phase 07 workflow](../Public/Invoke-Phase07PrivilegeEscalation.ps1)
- [Public setup function: `Initialize-AS2GoLab`](../Public/Initialize-AS2GoLab.ps1)
- [Internal workflow: `Set-SecureAccessWorkstation`](../Private/ASP00/Set-SecureAccessWorkstation.ps1)
- [Remote Pass-the-Ticket workflow](../Private/ASP07/Invoke-PassTheTicketAttack.ps1)
- [Local Pass-the-Ticket workflow](../Private/ASP07/Invoke-PassTheTicketAttackLocalMachine.ps1)
