# Clear All Variables
Remove-Variable * -ErrorAction SilentlyContinue

# Download aind install SSH-Sessions Module
Install-Module -Name Posh-SSH -AllowClobber

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path S:\scripts\uag.cred
$credentials = import-clixml -path S:\scripts\uag.cred
$scriptlocale = "S:\Scripts\Horizon_Windows_Log4j_Mitigation\uag_rm_log4j_jndilookup.sh"
$uagint01 = "your-uag-server-01"
$uagext01 = "your-uag-server-02"

#SSH into UAG
New-sshsession -Computername $uagint01 -Credential $credentials
New-SshSession -Computername $uagext01 -Credential $credentials

Get-SSHSession

Set-SCPItem -ComputerName $uagint01 -Credential $credentials -Destination "/" -Path $scriptlocale
Set-SCPItem -ComputerName $uagext01 -Credential $credentials -Destination "/" -Path $scriptlocale

# Apply Log4J Workaround
Invoke-SshCommand -Command "chmod +x /uag_rm_log4j_jndilookup.sh" -SessionId 0,1 # Pay attention to the Get-SSHSession as you will need to add more session IDs
Invoke-SshCommand -Command "/uag_rm_log4j_jndilookup.sh" -SessionId 0,1 -TimeOut 180
Invoke-SshCommand -Command "sed -i 's/java /java -Dlog4j2.formatMsgNoLookups=true /' /opt/vmware/gateway/supervisor/conf/authbroker.ini" -SessionId 0,1
Invoke-SshCommand -Command "supervisorctl update" -SessionId 0,1
Invoke-SshCommand -Command "ps -ef | grep ab-frontend" -SessionId 0,1
