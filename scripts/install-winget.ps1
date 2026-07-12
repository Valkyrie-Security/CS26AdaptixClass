[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false
Import-PackageProvider -Name NuGet -Force

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Install-Script -Name winget-install -Force -Scope CurrentUser

winget-install.ps1 

