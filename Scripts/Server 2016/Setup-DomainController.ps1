Write-Host "!!! This script is not to be run as is. Read the below and fill out the appropriate variables."
return

# PowerShell script outlining setting up a Domain Controller from scratch
# using Powershell/cmd
#
# Steps:
# 1. Set static IP
# 2. Set static DNS
# 3. Disable firewall
# 4. Rename computername
# 5. Reboot
# 6. Enable Remote Desktop
# 7. Set TimeZone
# 8. Install Windows updates
# 9. Install ADDS,DNS
# 10. Setup Domain and promote to Domain Controller

# Get initial network info
# IP, DNS, Interface ID/Alias
Get-NetAdapter
Get-NetIPInterface
Get-NetIPConfiguration
Get-DnsClientServerAddress
Get-NetFirewallProfile
ipconfig
netsh interface ipv4 show interface
netsh interface ipv4 show address
netsh interface ipv4 show dnsservers
netsh advfirewall show allprofiles state

(Get-WmiObject Win32_ComputerSystem).Name
(Get-WmiObject Win32_ComputerSystem).Domain

# Disable IPv6 on interface adapter
Get-NetAdapterBinding
Dsiable-NetAdapterBinding -Name $Adapter -ComponentID ms_tcpip6

# Join a domain
Add-Computer -DomainName $Domain
netdom join %computername% /domain:$Domain /userd:$Username /passwordd:$Password

# 1. Set static IP
$params = @{
    InterfaceAlias = $Alias
    IPAddress = $IP
    PrefixLength = 24
    DefaultGateway = $GatewayIP
}
New-NetIPAddress @params
netsh interface ipv4 set address $Adapter static $IP $PrefixLength $GatewayIP

# 2. Set static DNS
Set-DnsClientServerAddress -InterfaceIndex <id> -ServerAddresses <dns1>,<dns2>
netsh interface ipv4 set dnsservers <adapter> <static|dhcp> <ip>
netsh interface ipv4 add dnsservers <adapter> <ip> index=<index>

# 3. Disable firewall
Set-NetFirewallProfile -Profile domain, private, public -Enabled False
netsh advfirewall set allprofiles state off

# 4. Rename computer
Rename-Computer -Name <newcomputername> -Restart -Force
# Legacy way to rename domain-joined computers
netdom renamecomputer %computername% /newname:<name>
# Legacy way to rename non-domain computers
wmic computersystem where name="%COMPUTERNAME%" RENAME NAME="<name>"

# 5. Reboot computer
Restart-Computer
shutdown /r /t <seconds> /c <comment> (/m <\\computer>)

# 6. Enable Remote Desktop
$params = @{
    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\'
    Name = 'fDenyTSConnections'
    Value = 0
}
Set-ItemProperty @params
$params = @{
    Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\'
    Name = 'UserAuthentication'
    Value = 1
}
Set-ItemProperty @params
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Grant permissions for users by adding to localgroup "Remote Desktop Users"
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $Username

# 7. Set TimeZone
Get-TimeZone -ListAvailable
Set-TimeZone -Id "AUS Eastern Standard Time"

# 8. Install Windows updates
$AutoUpdates = New-Object -ComObject "Microsoft.Update.AutoUpdate"
$AutoUpdates.DetectNow()

# 9. Install ADDS,DNS
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools -IncludeAllSubFeature

# 10. Setup domain
# Install initial domain
Install-ADDSForest -InstallDns:$true -DomainName $DomainName -DomainNetbiosName $Domain
# Promote server to DC
Install-ADDSDomainController -DomainName $DomainName -Credential $(Get-Credential)

# Make sure AD/DNS services are running
# sc query {adws,kdc,netlogon,dns}
Get-Service adws, kdc, netlogon, dns

# Check for sysvol and netlogon shares
Get-SmbShare

# Review logs
Get-EventLog "Directory Service" | Select-Object entrytype, source, eventid, Message
Get-EventLog "Active Directory Web Services" | Select-Object entrytype, source, eventid, message
Get-ADDomainController
Get-ADDomain $Domain
Get-ADForest $DomainName

# EXTRA
# Set Remote Management service to start automatically
Set-Service WinRM -StartupType Automatic
