param(
    [Parameter(Mandatory = $true)]
    [string]$Domain
)

$ErrorActionPreference = "Stop"

# =========================
# Config
# =========================
$TargetHostname          = "DC01"
$StageFile               = "C:\Setup-DC.stage"
$ScriptCopy              = "C:\Setup-DC.ps1"
$PostSetupTask           = "Setup-DC-PostPromo"
$VagrantUser             = "vagrant"
$VagrantPassword         = "vagrant"
$LocalAdminPassword      = 'Pas$$Word123456'
$DSRMPasswordPlaintext   = 'Pas$$Word123456'

function Write-Info {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Good {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Ensure-RunningAsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run from an elevated PowerShell session."
    }
}

function Get-NetBIOSNameFromFQDN {
    param([string]$Fqdn)

    $leftLabel = $Fqdn.Split('.')[0]
    if ([string]::IsNullOrWhiteSpace($leftLabel)) {
        throw "Unable to derive NetBIOS name from domain '$Fqdn'."
    }

    if ($leftLabel.Length -gt 15) {
        return $leftLabel.Substring(0,15).ToUpper()
    }

    return $leftLabel.ToUpper()
}

function Save-ScriptCopy {
    if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
        Copy-Item -Path $PSCommandPath -Destination $ScriptCopy -Force
        Write-Info "Copied script to $ScriptCopy"
    }
    else {
        throw "Unable to determine script path. Save this script to a file and run it with -File."
    }
}

function Set-Stage {
    param([string]$Value)
    Set-Content -Path $StageFile -Value $Value -Force
}

function Get-Stage {
    if (Test-Path $StageFile) {
        return (Get-Content -Path $StageFile -ErrorAction Stop | Select-Object -First 1).Trim()
    }
    return ""
}

function Remove-Stage {
    if (Test-Path $StageFile) {
        Remove-Item -Path $StageFile -Force
    }
}

function Register-PostPromotionTask {
    param([string]$DomainName)

    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptCopy`" -Domain `"$DomainName`""
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument $argString
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

    try {
        Unregister-ScheduledTask -TaskName $PostSetupTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    Register-ScheduledTask -TaskName $PostSetupTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
    Write-Info "Registered startup task '$PostSetupTask' for post-promotion steps."
}

function Unregister-PostPromotionTask {
    try {
        Unregister-ScheduledTask -TaskName $PostSetupTask -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-Info "Removed scheduled task '$PostSetupTask'."
    } catch {}
}

function Set-LocalAdministratorPassword {
    param([string]$Password)

    Write-Info "Setting local Administrator password."

    $admin = Get-LocalUser -Name "Administrator" -ErrorAction Stop
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    Set-LocalUser -Name $admin.Name -Password $securePassword

    if (-not $admin.Enabled) {
        Enable-LocalUser -Name $admin.Name
        Write-Info "Enabled local Administrator account."
    }

    Write-Good "Local Administrator password set."
}

function Ensure-VagrantDomainUser {
    param(
        [string]$SamAccountName,
        [string]$PlainPassword,
        [string]$DnsDomainName
    )

    $existing = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Info "Domain user '$SamAccountName' already exists."
        return
    }

    $securePassword = ConvertTo-SecureString $PlainPassword -AsPlainText -Force
    $usersContainer = "CN=Users," + (($DnsDomainName.Split('.') | ForEach-Object { "DC=$_" }) -join ",")

    New-ADUser `
        -Name $SamAccountName `
        -SamAccountName $SamAccountName `
        -UserPrincipalName "$SamAccountName@$DnsDomainName" `
        -Path $usersContainer `
        -AccountPassword $securePassword `
        -Enabled $true `
        -PasswordNeverExpires $true

    Write-Good "Created domain user '$SamAccountName'."
}

function Add-UserToGroupIfMissing {
    param(
        [string]$UserSam,
        [string]$GroupName
    )

    $isMember = Get-ADGroupMember -Identity $GroupName -Recursive -ErrorAction Stop |
        Where-Object { $_.SamAccountName -eq $UserSam }

    if (-not $isMember) {
        Add-ADGroupMember -Identity $GroupName -Members $UserSam
        Write-Good "Added '$UserSam' to '$GroupName'."
    }
    else {
        Write-Info "'$UserSam' is already a member of '$GroupName'."
    }
}

Ensure-RunningAsAdmin

$stage   = Get-Stage
$netbios = Get-NetBIOSNameFromFQDN -Fqdn $Domain

# Detect whether the machine is already a DC
try {
    $isDC = ((Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4)
} catch {
    $isDC = $false
}

# =====================================
# Stage 0 - Pre-promotion setup
# =====================================
if (-not $isDC -and [string]::IsNullOrWhiteSpace($stage)) {
    Write-Info "Starting pre-promotion configuration for domain '$Domain'."

    Save-ScriptCopy

    Set-LocalAdministratorPassword -Password $LocalAdminPassword

    Write-Info "Installing AD DS and Active Directory PowerShell tools."
    Install-WindowsFeature AD-Domain-Services, RSAT-AD-PowerShell -IncludeManagementTools | Out-Null
    Write-Good "Installed AD DS and Active Directory PowerShell tools."

    Register-PostPromotionTask -DomainName $Domain
    Set-Stage -Value "PromoteToDC"

    if ($env:COMPUTERNAME -ne $TargetHostname) {
        Write-Info "Renaming computer from '$env:COMPUTERNAME' to '$TargetHostname'."
        Rename-Computer -NewName $TargetHostname -Force
        Write-Good "Hostname change scheduled."
    }
    else {
        Write-Info "Hostname is already '$TargetHostname'."
    }

    Write-WarnMsg "Rebooting to continue setup."
    Restart-Computer -Force
    exit
}

# =====================================
# Stage 1 - Promote to DC
# =====================================
if (-not $isDC -and $stage -eq "PromoteToDC") {
    Write-Info "Continuing setup after reboot."
    Write-Info "Promoting server to new forest root domain '$Domain'."

    $dsrmPassword = ConvertTo-SecureString $DSRMPasswordPlaintext -AsPlainText -Force

    Install-ADDSForest `
        -DomainName $Domain `
        -DomainNetbiosName $netbios `
        -InstallDNS `
        -SafeModeAdministratorPassword $dsrmPassword `
        -Force

    exit
}

# =====================================
# Stage 2 - Post-promotion config
# =====================================
if ($isDC -and $stage -eq "PromoteToDC") {
    Write-Info "Detected that the server is now a domain controller."
    Import-Module ActiveDirectory

    Ensure-VagrantDomainUser -SamAccountName $VagrantUser -PlainPassword $VagrantPassword -DnsDomainName $Domain
    Add-UserToGroupIfMissing -UserSam $VagrantUser -GroupName "Domain Admins"
    Add-UserToGroupIfMissing -UserSam $VagrantUser -GroupName "Schema Admins"

    Write-Good "Post-promotion configuration complete."
    Write-Good "Domain: $Domain"
    Write-Good "Hostname: $TargetHostname"
    Write-Good "User '$VagrantUser' is in Domain Admins and Schema Admins."

    Unregister-PostPromotionTask
    Remove-Stage
    exit
}

Write-WarnMsg "No action taken."
Write-WarnMsg "Current stage: '$stage'"
Write-WarnMsg "Is domain controller: $isDC"