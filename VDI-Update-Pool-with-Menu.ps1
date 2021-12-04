# I use this script to automatically add my Windows 10 jump box as a Manual Pool

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
$hzuser = $credentials.username
$hzpassword = $credentials.GetNetworkCredential().Password
$hzsvcuser = $hzcredentials.username
$hzsvcpassword = $hzcredentials.GetNetworkCredential().Password
$dt = get-date -format "MM-dd-yyyy hh:mm" # Used to set date and time for snapshot which makes it different every time this script is ran
$Snap = "Script Snapshot $dt" # Change if you want a different snapshot name within vCenter on the parent VM

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView -Force

# Establish connection to Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $hzcredentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView

# Assign a variable to obtain the API Extension Data
$hzServices = $Global:DefaultHVServers.ExtensionData

# Retrieve Connection Server Health metrics
$hzHealth =$hzServices.ConnectionServerHealth.ConnectionServerHealth_List()

# Display ConnectionData (Usage stats)
$hzHealth.ConnectionData

# List VMs with Parent in the name

# Menu of Pools to select
$poolitems = (get-hvpool).base.name 
$menu = @{}
for ($i=1;$i -le $poolitems.count; $i++) 
{ Write-Host "$i. $($poolitems[$i-1]),$($poolitems[$i-1].status)" 
$menu.Add($i,($poolitems[$i-1]))}

[int]$ans = Read-Host 'Enter selection'
$selection = $menu.Item($ans) ; (get-hvpool).base.name
$Parent = $parentselection

# Get-HVPoolSummary * | format-table -AutoSize

$dt = get-date -format "MM-dd-yyyy hh:mm"
$date = get-date -format "MM-dd-yyy"
# $PoolName = Read-Host -Prompt 'Input your pool name'

# Select as a Menu
$parentvmitems = Get-VM -Name *-parent
$menu = @{}
for ($i=1;$i -le $parentvmitems.count; $i++)
{ Write-Host "$i. $($parentvmitems[$i-1].name),$($parentvmitems[$i-1].status)"
$menu.Add($i,($parentvmitems[$i-1].name))}

[int]$ans = Read-Host 'Enter Selection'
$parentselection = $menu.Item($ans) ; Get-VM -Name $parentselection

# Update IC with new image
get-vm -Name $parent | new-snapshot -name $Snap
start-hvpool -schedulepushimage -pool $PoolName -LogOffSetting FORCE_LOGOFF -ParentVM $Parent -SnapshotVM $Snap
exit
