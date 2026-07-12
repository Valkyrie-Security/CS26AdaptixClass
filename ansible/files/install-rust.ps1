$rustup   = "C:\DevTools\rustup-init.exe"
$rustc    = "$env:USERPROFILE\.cargo\bin\rustc.exe"
$rustupDir = "$env:USERPROFILE\.rustup"

if (Test-Path $rustc) {
    exit 0
}

if (Test-Path $rustupDir) {
    Remove-Item -Path $rustupDir -Recurse -Force
}

Invoke-WebRequest -Uri "https://static.rust-lang.org/rustup/dist/x86_64-pc-windows-msvc/rustup-init.exe" -OutFile $rustup -UseBasicParsing

& $rustup -q -y
exit 0


