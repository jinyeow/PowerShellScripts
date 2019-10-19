# Get-Credential to login to O365 portal
# Connect to O365/Exchange Online
# Take Username
# Reset password
# Options: input pw, generate pw

# Last Updated: 22:49 19/10/2019


if (!(Get-InstalledModule -Name MSOnline)) {
    Install-Module -Name MSOnline -Force -Scope CurrentUser
}

Connect-MsolService

$userName = Read-Host -Prompt 'Email'
$User     = Get-MsolUser -SearchString $userName

# If search returns 1 object; print UPN, ask for confirmation to proceed
# If search returns > 1 object;
#   1. print object UPNs,
#   2. ask to choose 1 object or to search again

# Remove -WhatIf for real script
Set-MsolUserPassword `
    -userPrincipalName $User.UserPrincipalName `
    -NewPassword $password `
    -ForceChangePassword $false
    -WhatIf