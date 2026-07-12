$Password='Pas$$Word123456'
$admin = Get-LocalUser -Name "Administrator" -ErrorAction Stop
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force

Set-LocalUser -Name $admin.Name -Password $securePassword

if (-not $admin.Enabled) {
    Enable-LocalUser -Name $admin.Name
    Write-Host "Enabled local Administrator account."
}

Write-Host "Local Administrator password set."