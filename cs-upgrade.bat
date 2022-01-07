@echo off

TIMEOUT 60

echo Waiting for Horizon Services to start..

TIMEOUT 30

echo Upgrading Horizon now..
C:\Temp\VMware-Horizon-Connection-Server-xxx.exe /s /v "/qn VDM_SERVER_INSTANCE_TYPE=2"

echo Upgrade complete, now removing AutoAdminLogon and deleting upgrade file from Start Up folder..
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& {Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "AutoAdminLogon" -Value "0"}"
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& {Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name "DefaultPassword"}"
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& {Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "EnableLUA" -Value "1"}"
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -command "& {Remove-Item -Path 'C:\programdata\Microsoft\Windows\Start Menu\Programs\StartUp\CS-Upgrade.bat'}"

TIMEOUT 60

echo Rebooting the server now..
Shutdown -r -t 30

exit
