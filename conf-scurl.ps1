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

function Get-ScurlPlatform {
    $os = "windows"
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        "AMD64" { "x86_64" }
        "ARM64" { "aarch64" }
        "x86"   { "i686" }
        default { throw "Unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
    }
    return @{ OS = $os; Arch = $arch }
}

$script:RepoApiUrl = "https://api.github.com/repos/stunnel/static-curl/releases"

function Get-LatestVersion {
    try {
        $release = Invoke-RestMethod -Uri "$script:RepoApiUrl/latest" -UseBasicParsing
        return $release.tag_name
    } catch {
        throw "Error: cannot reach GitHub API. Check your internet connection."
    }
}

function Get-DownloadUrl($Version, $OS, $Arch) {
    $pattern = "curl-$OS-$Arch-$Version.tar.xz"
    try {
        $release = Invoke-RestMethod -Uri "$script:RepoApiUrl/tags/$Version" -UseBasicParsing
    } catch {
        throw "Error: cannot fetch release $Version from GitHub API."
    }
    $asset = $release.assets | Where-Object { $_.name -eq $pattern }
    if (-not $asset) {
        $available = ($release.assets | ForEach-Object { $_.name }) -join "`n"
        throw "Error: no release found for $pattern`nAvailable assets:`n$available"
    }
    return $asset.browser_download_url
}
