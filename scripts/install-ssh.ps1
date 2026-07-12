# Show current OpenSSH capability state
#Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'

# Install OpenSSH Server only if not already installed
$serverCap = Get-WindowsCapability -Online | Where-Object Name -eq 'OpenSSH.Server~~~~0.0.1.0'
if ($serverCap.State -ne 'Installed') {
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
}

# Start and enable the sshd service
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Ensure the firewall rule exists
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}
Get-Service -Name "sshd" | Select-Object Name, StartType, Status