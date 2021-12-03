# Reference https://www.retouw.nl/2020/06/21/horizonrestapi-handling-instant-clone-administrator-accounts/

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
# Connect to vCenter with saved creds
connect-viserver -Server $vc -Credential $credentials

# Import the Horizon module
Import-Module VMware.VimAutomation.HorizonView

# Establish connection to Connection Server
Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credentials


$hvServer = $global:DefaultHVServers[0]
$services=  $hvServer.ExtensionData

$url = "https://cs01.fqdn.whatever"
$username = $hzuser
$password = $hzpassword
$Domain = "domain.fqdn.whatever"


function Get-HRHeader(){
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type' = "application/json"
    }
}

function Open-HRConnection(){
    param(
        [string] $username,
        [string] $password,
        [string] $domain,
        [string] $url
    )

    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $password
        domain = $domain
    }

    return invoke-restmethod -Method Post -uri "$url/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}

function Close-HRConnection(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}
$accessToken = Open-HRConnection -username $username -password $password -domain $Domain -url $url


Invoke-RestMethod -Method Get -uri "$url/rest/monitor/connection-servers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)

Invoke-RestMethod -Method Get -uri "$url/rest/config/v1/ic-domain-accounts" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)

# Post 
$domains=Invoke-RestMethod -Method Get -uri "$url/rest/external/v1/ad-domains" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)

# Get
$domainid=$domains |select-object -expandproperty id -first 1
$data=@{
ad_domain_id= $domainid;
password= $hzsvcpassword;
username= $hzsvcuser
}
$body= $data | ConvertTo-Json

Invoke-RestMethod -Method Post -uri "$url/rest/config/v1/ic-domain-accounts" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $body

Invoke-RestMethod -Method Get -uri "$url/rest/config/v1/ic-domain-accounts" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
