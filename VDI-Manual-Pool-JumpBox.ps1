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
$win10jbVM = "Windows-10-VM" # Change to your Windows desktop VM name from vCenter
$poolname = "Win10JumpBox" # Change to a pool name of your choice without spaces or special characters
$pooldescrip = "Windows 10 Jump Box" # Change to a description of your choice to give more detail about the pool.
$poolentitlementuser = 'domain\user'
$poolentitlementgroup = 'domain\group'

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView -Force

# Establish connection to Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credential

# Assign a variable to obtain the API Extension Data
$hzServices = $Global:DefaultHVServers.ExtensionData

# Retrieve Connection Server Health metrics
$hzHealth =$hzServices.ConnectionServerHealth.ConnectionServerHealth_List()

# Display ConnectionData (Usage stats)
$hzHealth.ConnectionData
#endregion

#region Create Manual Pool and add W10 Jump Box to it
New-HVPool -Manual -PoolName $poolname -Description $pooldescrip -UserAssignment FLOATING -Source VIRTUAL_CENTER -VM $win10jbVM
# Add AD group to pool entitlement
New-HVEntitlement -ResourceName $PoolName -User $poolentitlementuser -Type User # Add an AD User for entitlement access
# New-HVEntitlement -ResourceName $PoolName -User $poolentitlementgroup -Type Group # Add an AD Group for entitlement access and uncomment line if needed
