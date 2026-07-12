Set-Service -Name wuauserv -StartupType Automatic
Start-Service -Name wuauserv
(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
