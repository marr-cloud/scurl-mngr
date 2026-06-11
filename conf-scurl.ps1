# conf-scurl.ps1 - Static curl manager for Windows
#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$script:ConfigDir = Join-Path $env:LOCALAPPDATA "scurl"
$script:ConfigFile = Join-Path $script:ConfigDir "config"

function Write-ScurlConfig {
    New-Item -ItemType Directory -Path $script:ConfigDir -Force | Out-Null
    @(
        "VERSION=$script:VERSION"
        "INSTALL_PATH=$script:INSTALL_PATH"
        "BINARY_NAME=$script:BINARY_NAME"
        "OS=$script:OS"
        "ARCH=$script:ARCH"
    ) | Set-Content -Path $script:ConfigFile
}

function Read-ScurlConfig {
    if (Test-Path $script:ConfigFile) {
        Get-Content $script:ConfigFile | ForEach-Object {
            if ($_ -match '^(\w+)=(.*)$') {
                Set-Variable -Name $Matches[1] -Value $Matches[2] -Scope Script
            }
        }
    }
}

function Test-ScurlConfig {
    Test-Path $script:ConfigFile
}
