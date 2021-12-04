# Download the UAG OVA and Powershell scripts from within your MyVMware account at https://downloads.vmware.com
# The ini file I'm using is from when I built my UAGs initially and then exported, reference https://docs.vmware.com/en/Unified-Access-Gateway/2111/uag-deploy-config/GUID-03C78817-84E3-46C8-8D6A-01C503CDAE56.html on how to create your own INI file

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path <driveletter>:\<path>\<filename>.cred
$credentials = import-clixml -path <driveletter>:\<path>\<filename>.cred

#region Starter Vars () - Generic Declarations for this example 
$vc = "vcenter.fqdn.whatever"  # Enter in your vCenter fully qualified domain name

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

$ScriptPath = "<driveletter>:\<path>\" # Change to where your Powershell scripts will be located
$uagint01 = "uag-int-01" # Change to whatever you want to name the Internal UAG VM
$uagext01 = "uag-ext-01" # Change to whatever you want to name the External UAG VM
$folder = Get-Folder "PowerShell-Deploy" # Change to which VM folder you want to move the UAG VMs 
$uagpass = $credentials.GetNetworkCredential().Password
#endregion

#region Now to deploy the internal and external UAGs
Invoke-Expression -Command $ScriptPath\uagdeploy\uagdeploy.ps1 -iniFile <driveletter>:\<path>\<filename-external>.ini $uagpass $uagpass no  # External UAG and setting the admin and user password the same, change if you want as well as selecting "no" for the CEIP
Move-VM -VM $uagext01 -InventoryLocation $folder 

Invoke-Expression -Command $ScriptPath\uagdeploy\uagdeploy.ps1 -iniFile <driveletter>:\<path>\<filename-internal>.ini $uagpass $uagpass no  # Internal UAG and setting the admin and user password the same, change if you want as well as selecting "no" for the CEIP
Move-VM -VM $uagint01 -InventoryLocation $folder
#endregion
