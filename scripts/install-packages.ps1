$packages = @(
    @{ Id = "9N0DX20HK701"; Source = "msstore" },
    @{ Id = "Git.Git"; Source = "winget" },
    @{ Id = "7zip.7zip"; Source = "winget" },
    @{ Id = "Microsoft.VisualStudioCode"; Source = "winget" }
)

foreach ($pkg in $packages) {
    Write-Host "Installing $($pkg.Id) from $($pkg.Source)..."
    winget install --id $pkg.Id --source $pkg.Source --exact --silent --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to install $($pkg.Id). Exit code: $LASTEXITCODE"
    }
}