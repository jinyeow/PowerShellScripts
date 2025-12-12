# HOWTO: install windows updates on servers
# e.g. Server Core = No GUI

# 1. PowerShell
Install-Module PSWindowsUpdate
Get-WindowsUpdate
Install-WindowsUpdate

# 2. cmd (wuauclt)
wuauclt /detectnow /updatenow # recommended
wuauclt /detectnow
wuauclt /updatenow

# 3. cmd (UsoClient; Windows 10 or Server 2016 recommended)
usoclient StartScan # Start scan
usoclient StartDownload # Start download of Patches
usoclient StartInstall # Install downloaded Patches
usoclient RefreshSettings # Refresh settings if any changes were made
usoclient StartInteractiveScan # May ask for user input and/or open dialoges to show progress or report errors
usoclient RestartDevice # Restart device to finish installation of updates
usoclient ScanInstallWait # Combined Scan,Download,Install
usoclient ResumeUpdate # Resume Update Installation on Boot
