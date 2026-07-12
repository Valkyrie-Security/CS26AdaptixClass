# DPAPI Credential Storage Setup
# Credentials stored here can be extracted with Mimikatz/SharpDPAPI
$user = "CHEDDARSALE\traci.ford"
$password = 'R%%5iE%mdSV8Rgd'

# Store RDP credential in Credential Manager (DPAPI protected)
cmdkey /generic:TERMSRV/dc01 /user:$user /pass:$password
cmdkey /generic:TERMSRV/srv01 /user:$user /pass:$password

# Create scheduled task with stored credentials
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\scripts\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

$taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -eq "DailyBackup"}
if(-not $taskExists) {
    Register-ScheduledTask -TaskName "DailyBackup" -Action $action -Trigger $trigger -User $user -Password $password -Settings $settings
}

# Store credential in XML (DPAPI encrypted)
$securePass = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($user, $securePass)
$cred | Export-Clixml "C:\Users\Public\backup_cred.xml"

Write-Host "DPAPI: Credentials stored for $user"
