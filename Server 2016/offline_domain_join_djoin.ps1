# Add target machine to TrustedHosts for WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts "<ip>" (-Force)

# Create a new session to target machine
$nano = New-PSSession -ComputerName <ip> -Credential (Get-Credential)

# Use djoin.exe utility to performan an offline domain join
djoin.exe /provision /domain <domain> /machine <name> /savefile <filename.blob>

# Copy blob to target machine
Copy-Item -Path <blob> -DestinationPath <path> -ToSession $nano

# Perform the offline domain join
djoin.exe /requestodj /loadfile <path\to\blob> /windowspath <path> /localos

# Restart the computer
Restart-Computer

# Best practice: Remove TrustedHosts entry after domain join is finished
Set-Item WSMan:\localhost\Client\TrustedHosts ""
# Verify
Get-Item WSMan:\localhost\Client\TrustedHosts