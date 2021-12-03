# Reference Wouter Kursten's https://www.retouw.nl/2020/04/12/adding-vcenter-server-to-horizon-view-using-the-apis/

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
$localpassword = $credentials.Password # If the service account you are using in line 7 is the same password as your local Admin, use this or create another .cred file and reference that password

# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView

# Establish connection to Connection Server
Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credentials


$hvServer = $global:DefaultHVServers[0]
$services=  $hvServer.ExtensionData

# Create required objects

$spec=new-object VMware.Hv.VirtualCenterSpec
$spec.serverspec=new-object vmware.hv.serverspec
$spec.viewComposerData=new-object VMware.Hv.virtualcenterViewComposerData

$spec.Certificateoverride=new-object vmware.hv.CertificateThumbprint
$spec.limits=new-object VMware.Hv.VirtualCenterConcurrentOperationLimits
$spec.storageAcceleratorData=new-object VMware.Hv.virtualcenterStorageAcceleratorData

# vCenter Server specs

$spec.ServerSpec.servername="vcenter.fqdn.whatever"        # Required, fqdn for the vCenter server
$spec.ServerSpec.port=443                                 # Required
$spec.ServerSpec.usessl=$true                             # Required
$spec.ServerSpec.username="administrator@vsphere.local"   # Required user@domain
#$vcpassword=read-host "vCenter User password?" -assecurestring 
$vcpassword = ConvertTo-SecureString -String $localpassword -AsPlainText -Force
$temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vcPassword)
$PlainvcPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
$vcencPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$vcencPassword.Utf8String = $enc.GetBytes($PlainvcPassword)
$spec.ServerSpec.password=$vcencPassword
$spec.ServerSpec.servertype="VIRTUAL_CENTER"

# Description & Displayname, neither is required to be set

#$spec.description="description"              # Not Required
#$spec.displayname="virtualcenterdisplayname" # Not Required
# I still get an error after these are ran, I need to ask Wouter or someone why but it still works.. just don't remove.
$spec.CertificateOverride=($services.Certificate.Certificate_Validate($spec.serverspec)).thumbprint
$spec.CertificateOverride.SslCertThumbprint=($services.Certificate.Certificate_Validate($spec.serverspec)).certificate
$spec.CertificateOverride.sslCertThumbprintAlgorithm = "DER_BASE64_PEM"


# Limits
# Only change when you want to change the default values. It is required to set these in the spec

$spec.limits.vcProvisioningLimit=20
$spec.Limits.VcPowerOperationsLimit=50
$spec.limits.ViewComposerProvisioningLimit=12
$spec.Limits.ViewComposerMaintenanceLimit=20
$spec.Limits.InstantCloneEngineProvisioningLimit=20

# Storage Accelerator data

$spec.StorageAcceleratorData.enabled=$false
#$spec.StorageAcceleratorData.DefaultCacheSizeMB=1024   # Not Required

# Cmposer
# most can be left empty but they need to be set otherwise you'll get a xml error


# DO NOT DELETE THE BELOW CODE! Since Composer is no longer used in Horizon 8/2XXX don't assume you can just remove this for now.  As started mark "DISABLED" 
$spec.ViewComposerData.viewcomposertype="DISABLED"  # DISABLED for none, LOCAL_TO_VC for installed with the vcenter and STANDALONE for s standalone composer


if ($spec.ViewComposerData.viewcomposertype -ne "DISABLED"){
    $spec.ViewComposerData.ServerSpec=new-object vmware.hv.serverspec
    $spec.ViewComposerData.CertificateOverride=new-object VMware.Hv.CertificateThumbprint
    $cmppassword=read-host "Composer user password?" -assecurestring
    $temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cmpPassword)
    $PlaincmpPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
    $cmpencPassword = New-Object VMware.Hv.SecureString
    $enc = [system.Text.Encoding]::UTF8
    $cmpencPassword.Utf8String = $enc.GetBytes($PlaincmpPassword)
    $spec.ViewComposerData.ServerSpec.password=$cmpencPassword
    $spec.ViewComposerData.ServerSpec.servername="pod2cmp1.loft.lab"
    $spec.ViewComposerData.ServerSpec.port=18443
    $spec.ViewComposerData.ServerSpec.usessl=$true
    $spec.ViewComposerData.ServerSpec.username="m_wouter@loft.lab"
    $spec.ViewComposerData.ServerSpec.servertype="VIEW_COMPOSER"

    $spec.ViewComposerData.CertificateOverride=($services.Certificate.Certificate_Validate($spec.ViewComposerData.ServerSpec)).thumbprint
    $spec.ViewComposerData.CertificateOverride.sslCertThumbprint = ($services.Certificate.Certificate_Validate($spec.ViewComposerData.ServerSpec)).certificate
    $spec.ViewComposerData.CertificateOverride.sslCertThumbprintAlgorithm = "DER_BASE64_PEM"
}


# Disk reclamation, this is required to be set to either $false or $true
$spec.SeSparseReclamationEnabled=$false 

# This will create the connection
$services.VirtualCenter.VirtualCenter_Create($spec)
