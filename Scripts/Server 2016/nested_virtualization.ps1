# Make sure that both the host and guest are up to date
Get-VMProcessor -VMName <vm> | fl *
Set-VMProcessor -VMName <vm> -ExposeVirtualizationExtensions $true