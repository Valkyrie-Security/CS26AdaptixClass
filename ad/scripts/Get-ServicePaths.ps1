$serviceNames = @(
    "PrintWorkflowSvc",
    "DiagHostSvc",
    "EntWorkflowSvc",
    "SecComplianceSvc",
    "NetHealthSvc"
)

foreach ($name in $serviceNames) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "[$name] NOT FOUND" -ForegroundColor Red
        continue
    }

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
    $binPath = (Get-ItemProperty -Path $regPath -Name ImagePath -ErrorAction SilentlyContinue).ImagePath

    Write-Host "Service:     $($svc.Name)" -ForegroundColor Cyan
    Write-Host "DisplayName: $($svc.DisplayName)"
    Write-Host "BinPath:     $binPath"
    Write-Host ""
}
