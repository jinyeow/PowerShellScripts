[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string] $VMName
)

# Make sure that both the host and guest are up to date
Get-VMProcessor -VMName $VMName | Format-List *
Set-VMProcessor -VMName $VMName -ExposeVirtualizationExtensions $true
