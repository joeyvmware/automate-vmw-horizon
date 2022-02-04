## VMware Reference KB: https://kb.vmware.com/s/article/87073

# Clear All Variables
Remove-Variable * -ErrorAction SilentlyContinue

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path <driveletter>:\<path>\<filename>.cred
$credentials = import-clixml -path <driveletter>:\<path>\<filename>.cred
# $localcreds = Get-Credential
# $localcreds | Export-Clixml -path S:\scripts\localcred.cred


# Variables
$vc = "vcenter.fqdn.whatever"  # Enter in your vCenter fully qualified domain name
$hzDomain = $domainname
$hzConn = $primayCS_IP
$CSvmFolder = "PowerShell-Deploy"
$horizonlog4jbatlocale = "S:\Scripts\Horizon_Windows_Log4j_Mitigation\Horizon_Windows_Log4j_Mitigation.bat"
$horizonlog4jbat = "Horizon_Windows_Log4j_Mitigation.bat"
$horizonservice = "wsbroker"
$horizonagentservice = "WSNM"
$win10goldimage = "Win10-713.iamware.net"

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Connect to Horizon Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credentials
$Services1=$Global:DefaultHVServers.ExtensionData

# Get a list of all the Connection Servers in $hzServer pod
$hzServerPool = $Services1.ConnectionServer.ConnectionServer_List()
$hzServers = ($hzServerPool.General | Select-Object Fqhn | Format-Table -HideTableHeaders | Out-String).Trim()
$hzServers | out-File -filepath s:\scripts\hzServers.csv

# Take a new snapshot of the VMs in $CSvmFolder
$dt = get-date -format "MM-dd-yyyy hh:mm"
$Snap = "Script Snapshot $dt"
$VMs = (Get-Folder $CSvmFolder | Get-VM)
$VMs
foreach ($VM in $VMs) {
get-vm -name $VM | new-snapshot -name $Snap
}

# Start adding the workaround for all $hzServers
$Servers = Get-Content S:\scripts\hzServers.csv

ForEach ($server in $Servers) {
Write-Output "Starting Log4J Mitigation script on $server"
Get-Service -ComputerName $server -Name $horizonservice | Stop-Service -Verbose
invoke-command -ComputerName $server -ScriptBlock {mkdir c:\temp} -Credential $credentials
Start-BitsTransfer -source $horizonlog4jbatlocale -Destination \\$server\c$\temp\
invoke-command -ComputerName $server -scriptBlock {
cmd /c "c:\temp\$using:horizonlog4jbat /resolve /force"
} -Credential $credentials
Get-Service -ComputerName $server -Name $horizonservice | Start-Service -verbose
Start-Sleep 300
}


# Verify each Connection Server is fully mitigated
ForEach ($server in $Servers) {
Write-Output "Checking Log4J Mitigation script on $server"
invoke-command -ComputerName $server -scriptBlock {
cmd /c "c:\temp\$using:horizonlog4jbat /checkversion=2.17.1 /verbose"
} -Credential $credentials
}


# Patch Horizon Agents - Windows Desktops
Invoke-Command -ComputerName $win10goldimage -ScriptBlock {mkdir c:\temp} -Credential $credentials
Start-BitsTransfer -source $horizonlog4jbatlocale -Destination \\$win10goldimage\c$\temp\
Get-Service -ComputerName $win10goldimage -Name $horizonagentservice | Stop-Service -Verbose
invoke-command -ComputerName $win10goldimage -scriptBlock {
cmd /c "c:\temp\$using:horizonlog4jbat /resolve /force"
} -Credential $credentials
Get-Service -ComputerName $win10goldimage -Name $horizonagentservice | Start-Service -verbose
Write-Output "Checking Log4J version on $server"
invoke-command -ComputerName $win10goldimage -scriptBlock {
cmd /c "c:\temp\$using:horizonlog4jbat /checkversion=2.17.1 /verbose"
} -Credential $credentials
