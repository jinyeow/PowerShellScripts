# Import nano server PS into session
Import-Module D:\NanoServer\NanoServerImageGenerator -Verbose

# Create a basic nano server vhdx
New-NanoServerImage -MediaPath <path> `
                    -BasePath <path> `
                    -TargetPath <path.vhd/x|wim> `
                    -DeploymentType <Host|Guest>
                    -Edition <Standard|Datacenter>
                    -ComputerName <name>
                    -AdministratorPassword (ConvertTo-SecureString -String <string> -AsPlainText -Force)

# Create and start VM
New-VM -Name <name> `
       -VHDPath <path> `
       -MemoryStartupBytes 1GB `
       -Generation <1|2> | Start-VM

# Create nano server web server
New-NanoServerImage -MediaPath <installation\media\path> `
                    -BasePath <base\path> `
                    -TargetPath <target.vhdx> `
                    -DeploymentType Guest `
                    -Edition Datacenter `
                    -ComputerName <name> `
                    -InterfaceNameOrIndex Ethernet `
                    -Ipv4Address <ip> `
                    -Ipv4SubnetMask <subnetmask> `
                    -Ipv4Gateway <gateway> `
                    -Ipv4Dns ("<dns1>","<dns2>") `
                    -Package Microsoft-NanoServer-IIS-Package `
                    -AdministratorPassword (ConvertTo-String -String 'Pa$$w0rd' -AsPlainText -Force)

# View available packages
Get-NanoServerPackage -MediaPath <path\to\media>

# View installed packages in nano server
Get-WindowsPackage -Online

# Set Trusted Hosts
Set-Item WSMan:\localhost\Client\TrustedHosts "<ip>" (-Force)

# Do domain join / use djoin.exe for offline domain join
# TODO

Enter-PSSession -ComputerName <name>

# Install the nano server package provider
Install-PackageProvider NanoServerPackage

# Import the nano server package provider
Import-PackageProvider NanoServerPackage

# List all packages under <provider> package provider.
Find-Package -ProviderName <provider>
# Equivalent to Find-NanoServerPackage when NanoServerPackage provider has been imported.
Find-NanoServerPackage

# Find all installed packages from provider <provider>
Get-Package -Provider <provider>

# Install a package
Install-Package -Name <package>

# Uninstall a package
Uninstall-Package -Name <package>