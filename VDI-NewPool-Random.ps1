# I use this script to automatically add an Instant Clone pool with a randomly generated pool name based upon date and time.

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
$domain = $hzDomain
$DomainAdminAcct = "account" # 
$poolentitlementuser = 'domain\user'
$poolentitlementgroup = 'domain\group'
$dt = get-date -format "MM-dd-yyyy hh:mm"
$date = get-date -format "MM-dd-yyy"
$Pool = "W10-IC-Blast"  # Change to whatever pool name you want with no spaces or special characters except for hyphens
$PoolName = $Pool + "-" + $date  # Change to whatever Pool name you want or leave like this so that it'll go off of the Pool + Date and time
$Snap = "Script Snapshot $dt" # Snapshot name with date and time
$VMFolder = "VDI" # Change to whatever VM Folder you want, in my case VDI is where I place all my VDI pools under
$Cluster = "vSAN-Cluster" # Change to whatever your Host cluster name is that your VDI will reside on
$RPool = "VDI" # Change to whatever resource pool your VDI will reside on
$DStore = "vsanDatastore" # Change to whatever datastore your VDI will reside on
$PoolDispName = "IC using PShell"  # Change to whatever pool description you want or leave as blank
$NamePat = "w10-blast-{n:fixed=3}" # Change the naming pattern, in this case I'm doing a reference to the OS, Protocol and fixed numbering of 3 digits
$parent = "Win10-IC-Parent"  # Change to your Windows VDI parent VM name


# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView

# Establish connection to Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credential

# Assign a variable to obtain the API Extension Data
$hzServices = $Global:DefaultHVServers.ExtensionData

# Retrieve Connection Server Health metrics
$hzHealth =$hzServices.ConnectionServerHealth.ConnectionServerHealth_List()

# Display ConnectionData (Usage stats)
$hzHealth.ConnectionData

# Select as a Menu
#$parentvmitems = Get-VM -Name *-parent
#$menu = @{}
#for ($i=1;$i -le $parentvmitems.count; $i++)
#{ Write-Host "$i. $($parentvmitems[$i-1].name),$($parentvmitems[$i-1].status)"
#$menu.Add($i,($parentvmitems[$i-1].name))}

#[int]$ans = Read-Host 'Enter Selection'
#$selection = $menu.Item($ans) ; Get-VM -Name $selection

# Take a new snapshot of the parent
$dt = get-date -format "MM-dd-yyyy hh:mm"
$Snap = "Script Snapshot $dt"
get-vm -Name $parent | new-snapshot -name $Snap

# Instant Clone pool with HTML Access and Auto Log off @ 10 Mins
New-HVPool -InstantClone -PoolName $PoolName -PoolDisplayName $PoolDispName -Description "IC created via Script with HTMLAccess and Auto Logoff" -UserAssignment FLOATING -ParentVM $Parent -SnapshotVM $Snap -VmFolder $VMFolder -HostOrCluster $Cluster -ResourcePool $RPool -NamingMethod PATTERN -UseVSAN $true -Datastores $DStore -NamingPattern $NamePat -NetBiosName $Domain -DomainAdmin $DomainAdminAcct -EnableHTMLAccess $true -AutomaticLogoffMinutes 10

# Wait 15 seconds for the pool to create before adding entitlements, if not it'll error out.
Start-Sleep -s 15

# Add AD group to pool entitlement
# New-HVEntitlement -ResourceName $PoolName -User $poolentitlementuser -Type User # Add an AD User for entitlement access and uncomment this line
New-HVEntitlement -ResourceName $PoolName -User $poolentitlementgroup -Type Group # Add an AD Group for entitlement access
