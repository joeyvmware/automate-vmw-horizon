# This script is a manual process of removing a Horizon Pool via a Powershell script using a Menu selection.

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
$hzDomain = domainname # Change to your domain name
$hzConn = primayCS # change to your primary/VIP fqdn of the Connection Server


# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView
#Get-Module -Name VMware* -ListAvailable | Import-Module -WarningAction SilentlyContinue

# Establish connection to Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain

# Assign a variable to obtain the API Extension Data
$hzServices = $Global:DefaultHVServers.ExtensionData

# Establish connection to vCenter Server
$vcServer = Connect-VIServer -server $vc 

# Menu selection of Horizon Pools
# Select as a Menu
$pools=get-hvpool
$pooldata=@()
foreach ($pool in $pools){
$pooldata+=new-object PSObject -property @{"name" = $pool.base.name;}}
$pooldata
$menu = @{}
for ($i=1;$i -le $pooldata.count; $i++)
{ Write-Host "$i. $($pooldata[$i-1].name)"
$menu.Add($i,($pooldata[$i-1].name))}
[int]$ans = Read-Host 'Enter Selection'
$PoolName = $selection = $menu.Item($ans) ; Get-HVPool -poolname $selection

# Remove the selected Pool
Remove-HVPool -HvServer $hvConn -PoolName $PoolName -DeleteFromDisk -Confirm:$false
