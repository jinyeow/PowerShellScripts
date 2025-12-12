# DISM help
dism /?
Get-Command -Module DISM

# View images in a .wim
dism /get-imageinfo /imagefile:<path>
Get-WindowsImage -ImagePath <path\to\wim>

# Mount server core datacenter image
# NB: make sure that you are not in the mount location or else it will fail
dism /mount-image /imagefile:<path\install.wim> /index:<id> /mountdir:<path>
Mount-WindowsImage -ImagePath <path\to\image>

# Add drivers (.inf)
dism /image:<path> /get-drivers
Get-WindowsDriver -Path <path\to\image>
dism /image:<path> /add-driver /driver:<path\to\driver> (/recurse)
Add-WindowsDriver -Path <path\to\image> -Driver <path\to\driver>

# Remove driver(s)
dism /image:<path> /remove-dirver /driver:<path\to\driver>
Remove-WindowsDriver -Path <path\to\image> -Driver <path\to\driver>

# Add patches, hotfixes, and updates
dism /image:<path> /get-packages
Get-WindowsPackage -Path <path\to\image>
dism /image:<path> /add-package /packagepath:<path>
Add-WindowsPackage -Path <path\to\image> -PackagePath <path\to\package.{msu,cab}>

# Remove patch, hotfix, update
dism /image:<path> /remove-package /packagename:<package-name>
Remove-WindowsPackage -Path <path\to\image> -PackagePath <path\to\package.{msu,cab}>

# Get feature information
dism /image:<path> /get-features
dism /image:<path> /get-featureinfo /featurename:<feature>
Get-WindowsOptionalFeature -Path <image> -FeatureName <feature>

# Install role/feature on image
dism image:<path> /enable-feature /featurename:<feature> /all
Enable-WindowsOptionalFeature -Path <image> -FeatureName <feature>

# Remove role/feature on image
dism /image:<path> /disable-feature /featurename:<feature>
Disable-WindowsOptionalFeature -Path <image> -FeatureName <feature>

# Dismount and commit all changes
dism /unmount-image /mountdir:<path> /commit
Dismount-WindowsImage -Path <path> (-Save|-Discard)