$starttime = Get-Date

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path <driveletter>:\<path>\<filename>.cred
$credentials = import-clixml -path <driveletter>:\<path>\<filename>.cred

# It's also assumed that the file server that you'll use throughout this script will have read access from this Powershell host or locally stored

#region Modules Load
# Get-Module -Name VMware* -ListAvailable | Install-Module -Confirm:$false -Force  # Uncomment and run if you do not already have the VMware modules installed
# Find-Module -Name *Hostfile* | Install-Module -Confirm:$false -Force  # Uncomment and run if you do not already have the Host File module installed
# Get-ChildItem -Path 'C:\Program Files\WindowsPowerShell\Modules\VMware*' -Recurse | Unblock-File  # Uncomment and run if you just installed the above modules 
# Get-ChildItem -Path S:\Scripts\* -Recurse | Unblock-File # Uncomment and run if you just installed this script and the others but also change the path to where those are located
#endregion


#region Starter Vars () - Generic Declarations for this example 
$vc = "vcenter.fqdn.whatever"  # Enter in your vCenter fully qualified domain name

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

$vm = "cs01"
$horizonCSfile = "VMware-Horizon-Connection-Server-x86_64-8.3.0-18294467.exe" # Change this to the filename of the Horizon Installer
$horizonBat = "cs-install.bat" # Used to launch installer locally on the Connection Server, could just invoke-command instead
$cluster = Get-Cluster "vSAN-Cluster"  # Change to your Host Cluster name
$resourcepool = "RP-PowerShell-Deploy" # If you use Resource Pools, if not remove
$datacenter = $cluster | Get-Datacenter
$datastore = "vsanDatastore" # Change to your host/cluster's datastore
$folder = Get-Folder "PowerShell-Deploy" # Used to place VMs that I deploy in this folder by default
$vmSubnet = Get-VDPortgroup -Name "VMs" # Change to your Portgroup name
$numCPU = "2" # Change if you want more vCPUs per VM
$numRAM = "8" # Change if you want more RAM per VM
$IP = "192.168.1.71" # Change to your Connection Servers static IP address
$netmask = "255.255.252.0" # Change to your subnet mask
$DefaultGateway = "192.168.1.1" # Change to your static IP's gateway
$DnsA = "192.168.1.38" # Change to your primary DNS server
$DnsB = "8.8.8.8" # Change to your secondary DNS server
$spec = "Windows" # This is the name of the VM Custiomization Profile in vCenter under Profiles and Policies
$primaryCS = "cs01.fqdn.whatever"  # Not needed in primary CS install script but used for the replica servers install
$primaryCS_IP = "192.168.1.71" # Same as previous variable but only needed for replica servers install
$localacct = "local-admin" # Change to whatever your local administrator account is on the VM Template
$domainname = "domain.fqdn.whatever" # Change to your AD domain name
$localpassword = $credentials.Password # If the service account you are using in line 7 is the same password as your local Admin, use this or create another .cred file and reference that password
$localpasswordunsecure = Convertfrom-SecureString -SecureString $localpassword # Will use this for the DefaultPassword within the registry for AutoAdminLogon functionality
$localWindowskey = Get-Content <driveletter>:\<path>\<filename>.txt # Create a text file like "cs01-windowslicensekey.txt" so the script can pull that info that way
$horizonKey = Get-Content <driveletter>:\<path>\<filename>.txt # Create a different text file like "horizon-key.txt" with the Perpetual/On-prem Horizon key
$hzDomain = $domainname
$hzConn = $primayCS_IP
$ScriptPath = "<driveletter>:\<path>\" # Change to where your Powershell scripts will be located
$fileserver = "192.168.1.95" # Change to whatever your path where the files are stored for the Horizon installer and SSL certificate
$templatename = "Server2019-STD" # Change this to your Content Library Template for the VM that we will use to install the Horizon Connection Server on
$source1 = "\\$fileserver\path\Horizon-8\2106\$horizonCSfile"  # Change this to your file server's path to the Horizon Installer location
$source2 = "\\$fileserver\path\Horizon-8\2106\$horizonBat" # Change this to the BAT file for the Horizon primary Connector Server installer command line
# BAT file will have this command line = C:\Temp\VMware-Horizon-Connection-Server-x86_64-8.3.0-18294467.exe /s /v "/qn VDM_SERVER_INSTANCE_TYPE=1 VDM_INITIAL_ADMIN_SID=S-1-5-32-544 HTMLACCESS=1 FWCHOICE=1 DEPLOYMENT_TYPE=GENERAL VDM_SERVER_RECOVERY_PWD="password" VDM_SERVER_RECOVERY_PWD_REMINDER=""Lab Password"""
$source3 = "\\$fileserver\s$\certs\$certfile" # Change this to the path to where the SSL cert is located that will be copied over
$Target = "c:\temp\"
#endregion



#region Start cloning and configuring the new VM
# Get-ContentLibraryItem -ItemType vm-template | Select Name
#Generate a random name for the tempSpec to allow parallel runs
$vmSpec = "tempSpec" + (Get-Random)

#Modify the selected Custom Spec to configure desired networking settings
Get-OSCustomizationSpec -Name $spec | New-OSCustomizationSpec -Name $$vmSpec -Type NonPersistent

Get-OSCustomizationSpec -Name $$vmSpec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress $IP -SubnetMask $netmask -DefaultGateway $defaultgateway -Dns $DNSA,$DNSB

$tempSpec = Get-OSCustomizationSpec -Name $$vmSpec

#spin up the vm from a content library template.
Get-ContentLibraryItem -ItemType "vm-template" -Name $templatename  | New-VM -Name $vm -resourcePool $resourcepool -location $folder -datastore $datastore -confirm:$false 

#assumes a single nic, which as a template should be your standard
Get-NetworkAdapter -VM $vm | Set-NetworkAdapter -NetworkName $vmSubnet -StartConnected $true -confirm:$false

#set your custimization specification
set-vm $vm -OSCustomizationSpec $$vmSpec -NumCpu $numCPU -MemoryGB $numRAM -confirm:$false

#with no other options left to configure start it up. 
Start-VM $vm -confirm:$false

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping.." -Status "Waiting for VM to Power On and Customized." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping.." -Status "Waiting for VM to Power On and Customized.." -SecondsRemaining 0 -Completed
}

# Sleep for 10 minutes to give the OS time to customize.
Start-Sleep 600

#Cleanup the temporary Spec. System will do this outside of the session, but this will allow the scripts to be reused within a session.
Remove-OSCustomizationSpec -Confirm:$false -customizationSpec (Get-OSCustomizationSpec -name $$vmSpec)

#endregion

#region Get the IP of the VM which should be hard set and add it to the local host file.
connect-viserver -Server jw-vcenter.iamware.net -Credential $credentials
# Create local host file entry for DHCP address
$vmIP = (Get-VMGuest -VM (Get-VM -name $vm)).IPAddress
$IP = $vmIP | ?{$_ -notmatch ':'}
$hostfileIP = Test-Connection -ComputerName $vm -Count 1  | Select -ExpandProperty IPV4Address


Add-HostFileEntry -hostname $vm -ipaddress $IP.IPAddressToString
#endregion


#region Create the temp folder for the files in the next step.
Invoke-Command -ComputerName $vm -ScriptBlock {
    mkdir c:\temp
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -type String
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value $Using:localacct
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultDomainName" -Value $Using:domainname
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Value $Using:localpasswordunsecure
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "1"
    Find-Module -Name *Hostfile* | Install-Module -Confirm:$false -Force -SkipPublisherCheck
    Add-HostFileEntry -hostname $Using:primaryCS -ipaddress $Using:primaryCS_IP
function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}
    Disable-InternetExplorerESC
    
    Shutdown -r -t 0
}  -Credential $credentials
#endregion

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping.." -Status "Rebooting to take settings and start Horizon install.." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping.." -Status "Waiting for VM to boot up.." -SecondsRemaining 0 -Completed
}

Start-Sleep 120



#region Copying files from File Server to VM
# Copy-Item -Path $source -Destination 'C:\temp' -ToSession $session
Start-BitsTransfer -source $source1 -Destination \\$vm\c$\temp\
Start-BitsTransfer -source $source2 -Destination \\$vm\c$\temp\
Start-BitsTransfer -source $source3 -Destination \\$vm\c$\temp\
#endregion

#region
# Run Horizon Connection Server silent install
Invoke-Command -ComputerName $vm -ScriptBlock {cmd "/c C:\Temp\$Using:horizonBat"}  -Credential $credentials

#region Now remove the auto logon and other settings.
Invoke-Command -ComputerName $vm -ScriptBlock {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword"
}  -Credential $credentials
Invoke-Command -ComputerName $vm -ScriptBlock {(get-childitem -Path Cert:\LocalMachine\My | Where-Object {$_.FriendlyName -like "vdm"}).FriendlyName = "vdm-original"}  -Credential $credentials

Invoke-Command -ComputerName $vm -ScriptBlock {Import-PfxCertificate -FilePath "c:\temp\$Using:certfile" -CertStoreLocation Cert:\LocalMachine\My -Password $Using:certpassword -Exportable -Confirm:$false}  -Credential $credentials
# Invoke-Command -ComputerName $vm -ScriptBlock {(Get-ChildItem -path Cert:\LocalMachine\My\FB1260F5BD725451BBCDEA9F8B1F17467365F0A4).FriendlyName = "vdm"} # Not needed if cert has this already.
Start-Sleep 60
Invoke-Command -ComputerName $vm -ScriptBlock {Shutdown -r -t 0}  -Credential $credentials

#endregion

# Set Windows Activation Key
Invoke-Command -ComputerName $vm -ScriptBlock {slmgr /ipk $Using:localWindowskey}  -Credential $credentials
#endregion

#region # Waiting for Horizon services to start and then set the license key

function Start-Sleep($seconds) {
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $percent = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "Sleeping.." -Status "Giving Horizon time to start up.." -SecondsRemaining $secondsLeft -PercentComplete $percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping.." -Status "Waiting for the Connection Server services.." -SecondsRemaining 0 -Completed
}


Start-sleep 300

# Set Horizon License Key

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView

# Establish connection to Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credentials

# Assign a variable to obtain the API Extension Data
$hzServices = $Global:DefaultHVServers.ExtensionData

# Retrieve Connection Server Health metrics
$hzHealth =$hzServices.ConnectionServerHealth.ConnectionServerHealth_List()

# Display ConnectionData (Usage stats)
$hzHealth.ConnectionData

Set-HVlicense -license $horizonKey
#endregion

#region Start CS2 build script

# "$ScriptPath\Windows-Horizon-CS02.ps1"  $ Uncomment and change this to the path for the replica server Powershell script if needed

#endregion


#region Add vCenter to Connection Server..

"$ScriptPath\Horizon-API-vCenter.ps1" # Download this script also from my Github or check out Wouter Kursten's https://www.retouw.nl/2020/04/12/adding-vcenter-server-to-horizon-view-using-the-apis/

#endregion


#region Create the Instant Clone domain user

"$ScriptPath\Horizon-API-InstantClone.ps1" # Download this script also from my Github or check out Wouter Kursten's https://www.retouw.nl/2020/06/21/horizonrestapi-handling-instant-clone-administrator-accounts/

#endregion


#region Adding Manual and Instant Clone pools

# Then add Windows 10 Jump Box script
# "$ScriptPath\VDI-Manual-Pool-JumpBox.ps1" # Download this script also from my Github if you using a manual desktop pool and uncomment


# Then add Instant Clone pool script
# "$ScriptPath\vdi-newpool-random.ps1"  # Download this script also from my Github if you are wanting to auto create an instant clone pool and uncomment the line
#endregion

#region Now to deploy the internal and external UAGs
# "$ScriptPath\Deploy-UAGs.ps1"  # Download this script also from my Github if you want to also deploy UAGs and uncomment this line
#endregion

$endtime = Get-Date
New-TimeSpan -Start $starttime -End $endtime  # Used to determine how long the script took when all is said and done
