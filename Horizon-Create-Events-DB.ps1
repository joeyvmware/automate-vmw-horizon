# Clear All Variables
Remove-Variable * -ErrorAction SilentlyContinue

#region Modules Load
# Install-Module VMware.PowerCLI -Confirm:$false -Force
# Get-Module -Name VMware* -ListAvailable | Install-Module -Confirm:$false -Force
# Find-Module -Name *Hostfile* | Install-Module -Confirm:$false -Force
Install-Module -Name SqlServer

#endregion

# The beginning of each script I always include how to create the credential file and how to import it for each script I use.
# Save vCenter/Horizon/SQL credentials - Only needs to be ran once to create .cred file.
# $credentials = Get-Credential
# $credentials | Export-Clixml -path S:\scripts\credentials.cred
$credentials = import-clixml -path S:\scripts\credentials.cred

# Variables - Change these to meet your environment
$hzDomain = "yourdomain"
$hzConn = "primary-cs"
$sqlserver = "your-sqlserver"
$sqldbname = "Horizon-Events" 

# Connect to Horizon Connection Server
$hzServer = Connect-HVServer -server $hzConn -Domain $hzDomain -Credential $credentials
$Services1=$Global:DefaultHVServers.ExtensionData

# We will delete the database if there was one already created - Change the Horizon-Events to match your desired DB name as we cannot use $sqldbname variable here for deletion and below for creation
Invoke-SqlCmd -ServerInstance $sqlserver `
    -Query "IF EXISTS (SELECT name FROM master.dbo.sysdatabases WHERE name ='Horizon-Events') `
                BEGIN `
                    ALTER DATABASE [Horizon-Events] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; `
                    DROP DATABASE [Horizon-Events]; `
                END;" `
    -Verbose

# Create database file folder on $sqlserver - This is to make sure the path we want to store the database files, change to your desired location.
Invoke-Command -ComputerName $sqlserver -ScriptBlock {mkdir c:\databases} -Credential $credentials

# Create SQL Database
 $sql = "
CREATE DATABASE [Horizon-Events]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Horizon-Events', FILENAME = N'C:\databases\Horizon-Events.mdf' , SIZE = 1048576KB , FILEGROWTH = 262144KB )
 LOG ON 
( NAME = N'Horizon-Events_log', FILENAME = N'C:\databases\Horizon-Events_log.ldf' , SIZE = 524288KB , FILEGROWTH = 131072KB )
GO
 
USE [master]
GO
ALTER DATABASE [Horizon-Events] SET RECOVERY SIMPLE WITH NO_WAIT
GO 
 
ALTER AUTHORIZATION ON DATABASE::[Horizon-Events] TO [sa]
GO "


Invoke-SqlCmd -ServerInstance $sqlserver -Query $sql

# Adding Events DB to Horizon environment - change username from SA to whatever your desired username will be for the Horizon environment to use
Set-HvEventDatabase -server $sqlserver -databasename $sqldbname -username 'sa' -password $credentials.Password

