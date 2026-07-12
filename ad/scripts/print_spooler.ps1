# Enable Print Spooler for coercion attacks
# Vulnerable to PrinterBug (SpoolSample) and potentially PrintNightmare
# https://www.thehacker.recipes/ad/movement/mitm-and-coerced-authentications/ms-rprn

# Ensure Spooler service is running
Set-Service -Name Spooler -StartupType Automatic
Start-Service -Name Spooler

# Create registry path if it doesn't exist
$printerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers"
if (-not (Test-Path $printerPath)) {
    New-Item -Path $printerPath -Force | Out-Null
}

# Enable remote printer access (for coercion)
Set-ItemProperty -Path $printerPath -Name "RegisterSpoolerRemoteRpcEndPoint" -Value 1 -Type DWord -Force

# Allow remote RPC (required for SpoolSample)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Print" -Name "RpcAuthnLevelPrivacyEnabled" -Value 0 -Type DWord -Force

Write-Host "Print Spooler: Service enabled and configured for remote access"
