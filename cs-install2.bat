@echo off
echo Launching the Horizon Connection Server Replica install..
C:\Temp\VMware-Horizon-Connection-Server-xxx /s /v "/qn VDM_SERVER_INSTANCE_TYPE=2 ADAM_PRIMARY_NAME=pirmary-cs.domain"
Timeout 30
echo Rebooting to finish install and remove autologon settings..
Shutdown -r -t 30
exit
