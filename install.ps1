# install.ps1 - Bootstrap installer for scurl-mngr (Windows)
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Repo = "marr-cloud/scurl-mngr"
$InstallPath = Join-Path $env:LOCALAPPDATA "scurl\bin"

Write-Host "scurl-mngr installer"
Write-Host "===================="

# Check tar availability
if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
    Write-Error "Error: tar is required. Windows 10+ includes it natively."
    exit 1
}

# Create install directory
New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null

# Download conf-scurl.ps1
Write-Host "Downloading conf-scurl.ps1..."
$baseUrl = "https://raw.githubusercontent.com/$Repo/main"
Invoke-WebRequest -Uri "$baseUrl/conf-scurl.ps1" -OutFile (Join-Path $InstallPath "conf-scurl.ps1") -UseBasicParsing

# Create conf-scurl.cmd wrapper
'@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0conf-scurl.ps1" %*' |
    Set-Content -Path (Join-Path $InstallPath "conf-scurl.cmd")

# Add to PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$InstallPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$InstallPath;$currentPath", "User")
    $env:Path = "$InstallPath;$env:Path"
    Write-Host "Added $InstallPath to PATH"
}

Write-Host "conf-scurl installed to $InstallPath"

# Run first install
& (Join-Path $InstallPath "conf-scurl.ps1") install
