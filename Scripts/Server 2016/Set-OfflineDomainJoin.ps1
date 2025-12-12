[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $ComputerName,
    [Parameter(Mandatory = $true)]
    [string] $DomainName,
    [Parameter(Mandatory = $true)]
    [string] $SaveFile
)

# NOTE: Ensure WinRM service is running on source machine
# NOTE: Must use the ip/name that was set in TrustedHosts
#       If ip was used, cannot use the hostname; and vice-versa
# Run "Enable-PSRemoting" or "winrm quickconfig"

# Add target machine to TrustedHosts for WinRM
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value "$ComputerName" -Force

# Create a new session to target machine
$nano = New-PSSession -ComputerName $ComputerName -Credential (Get-Credential)

# Use djoin.exe utility to performan an offline domain join
djoin.exe /provision /domain $DomainName /machine $ComputerName /savefile $SaveFile

# Copy blob to target machine
Copy-Item -Path "<blob>" -DestinationPath "<path>" -ToSession $nano

# Perform the offline domain join
djoin.exe /requestodj /loadfile "<path\to\blob>" /windowspath "<path>" /localos

# Restart the computer
Restart-Computer

# Best practice: Remove TrustedHosts entry after domain join is finished
Set-Item -Path WSMan:\localhost\Client\TrustedHosts -Value ""
# Verify
Get-Item WSMan:\localhost\Client\TrustedHosts
