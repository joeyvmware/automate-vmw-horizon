# Clear All Variables
Remove-Variable * -ErrorAction SilentlyContinue

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path <driveletter>:\<path>\<filename>.cred
# $hzcredentials = Get-Credential
# $hzcredentials = Export-Clixml -path <driveletter>:\<path>\<filename>.cred # Different than above $credentials file
$credentials = import-clixml -path <driveletter>:\<path>\<filename>.cred # Same file as line 4 path
$hzcredentials = import-clixml -path <driveletter>:\<path>\<filename>.cred # Same file as line 6 path
# Connect to vCenter with saved creds
#region Starter Vars () - Generic Declarations for this example 
$vc = "vcenter.fqdn.whatever"  # Enter in your vCenter fully qualified domain name
$hzDomain = "domain.fqdn.whatever"
$hzConn = "cs01.fqdn.whatever"
$horizonCSfile = "VMware-Horizon-Connection-Server-xxx.exe"
$hzFilePath = "\\share.fqdn.whatever\share\Horizon-8\2111\"
$horizonBat = "CS-Upgrade.bat"
$CSvmFolder = "PowerShell-Deploy"  # Change to whatever your VM Folder path is for Horizon MGMT VMs, to take a snapshot so that we can revert later
$localacct = "localAdmin" # Change to whatever your auto login domain account will be to start the install/upgrade.. has to be a domain account with local admin rights
$domainname = "domain" # Change to your domain
$localpassword = $credentials.Password
$localpasswordunsecure = Convertfrom-SecuretoPlain -SecurePassword $localpassword
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
$Snap = "Horizon Upgrade Script Snapshot $dt"
$VMs = (Get-Folder $CSvmFolder | Get-VM)
$VMs
#foreach ($VM in $VMs) {
#get-vm -name $VM | new-snapshot -name $Snap
#}

# Start adding the workaround for all $hzServers
$Servers = Get-Content S:\scripts\hzServers.csv

ForEach ($server in $Servers) {
$source1 = $hzFilePath+$horizonCSfile
$source2 = $hzFilePath+horizonBat

# Disabling UAC and setting Autologon so we can launch the upgrade on logon due to ADAM LDAP requirements
Invoke-Command -ComputerName $server -ScriptBlock {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value " "
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultDomainName" -Value " "
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Value " "
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -type String
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value $Using:localacct
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultDomainName" -Value $Using:domainname
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Value $Using:localpasswordunsecure
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "1"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value "0"
}
Write-host "Copying $horizonCSfile to $server and starting upgrade.."
Start-BitsTransfer -source $source1 -Destination \\$server\c$\temp\
Start-BitsTransfer -source $source2 -Destination "\\$server\c$\programdata\microsoft\windows\Start Menu\Programs\StartUp\"
Invoke-Command -ComputerName $server -Credential $credentials -ScriptBlock {
    Shutdown -r -t 0

}

Start-Sleep 720
}

