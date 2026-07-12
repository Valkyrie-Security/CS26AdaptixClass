Install-WindowsFeature -Name GPMC

$GpoName = "VillageWallpaper"
$DomainDN = "DC=cheddarsale,DC=local"
$WallpaperUNC = "\\cheddarsale.local\SYSVOL\cheddarsale.local\scripts\VillageWallpaper.png"

$gpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue

if (-not $gpo) {
    $gpo = New-GPO -Name $GpoName -Comment "Set village wallpaper"
}

# Ensure the GPO is linked
$inheritance = Get-GPInheritance -Target $DomainDN
$linkExists = $inheritance.GpoLinks | Where-Object { $_.DisplayName -eq $GpoName }

if (-not $linkExists) {
    New-GPLink -Name $GpoName -Target $DomainDN | Out-Null
}

# Optional fallback background color while wallpaper loads / if unavailable
Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Control Panel\Colors" `
    -ValueName "Background" `
    -Type String `
    -Value "210 202 189"

# User policy wallpaper settings - this is the important part
Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "Wallpaper" `
    -Type String `
    -Value $WallpaperUNC

# WallpaperStyle values commonly used:
# 0 = Center
# 2 = Stretch
# 6 = Fit
# 10 = Fill
Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
    -ValueName "WallpaperStyle" `
    -Type String `
    -Value "10"

# Older companion value still commonly checked
Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Control Panel\Desktop" `
    -ValueName "Wallpaper" `
    -Type String `
    -Value $WallpaperUNC

Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Control Panel\Desktop" `
    -ValueName "WallpaperStyle" `
    -Type String `
    -Value "10"

Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_CURRENT_USER\Control Panel\Desktop" `
    -ValueName "TileWallpaper" `
    -Type String `
    -Value "0"

# Helps ensure foreground user policy is processed at logon
Set-GPRegistryValue -Name $GpoName `
    -Key "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows NT\CurrentVersion\WinLogon" `
    -ValueName "SyncForegroundPolicy" `
    -Type DWord `
    -Value 1

# Allow delegated editing of the GPO
Set-GPPermissions -Name $GpoName `
    -PermissionLevel GpoEditDeleteModifySecurity `
    -TargetName "justin.talley" `
    -TargetType User