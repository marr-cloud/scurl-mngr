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

function Invoke-ScurlDownload($Url, $InstallPath, $BinaryName, $Version) {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "scurl-tmp-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $archive = Join-Path $tmpDir "curl.tar.xz"

    Write-Host "Downloading $(Split-Path $Url -Leaf)..."
    Invoke-WebRequest -Uri $Url -OutFile $archive -UseBasicParsing

    tar -xJf $archive -C $tmpDir 2>$null
    $bin = Get-ChildItem -Path $tmpDir -Filter "curl.exe" -Recurse | Select-Object -First 1
    if (-not $bin) {
        Remove-Item -Recurse -Force $tmpDir
        throw "Error: curl.exe not found in archive"
    }

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Move-Item -Path $bin.FullName -Destination (Join-Path $InstallPath "$BinaryName.exe") -Force

    # Install trurl.exe if present
    $trurl = Get-ChildItem -Path $tmpDir -Filter "trurl.exe" -Recurse | Select-Object -First 1
    if ($trurl) {
        Move-Item -Path $trurl.FullName -Destination (Join-Path $InstallPath "trurl.exe") -Force
    }
    # Install ca-bundle if present
    $crt = Get-ChildItem -Path $tmpDir -Filter "curl-ca-bundle.crt" -Recurse | Select-Object -First 1
    if ($crt) {
        Move-Item -Path $crt.FullName -Destination (Join-Path $InstallPath "curl-ca-bundle.crt") -Force
    }

    Remove-Item -Recurse -Force $tmpDir
    Write-Host "Done: $BinaryName v$Version installed in $InstallPath\$BinaryName.exe"
}

function Add-ToUserPath($Dir) {
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($current -notlike "*$Dir*") {
        [Environment]::SetEnvironmentVariable("Path", "$Dir;$current", "User")
        $env:Path = "$Dir;$env:Path"
    }
}

function Remove-FromUserPath($Dir) {
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = $current -split ';' | Where-Object { $_ -ne $Dir -and $_ -ne "" }
    [Environment]::SetEnvironmentVariable("Path", ($parts -join ';'), "User")
    $envParts = $env:Path -split ';' | Where-Object { $_ -ne $Dir -and $_ -ne "" }
    $env:Path = $envParts -join ';'
}

function Show-Usage {
    Write-Host @"
Usage: conf-scurl <command> [args]

Commands:
  install [version]  Install scurl (latest or specific version)
  update             Update to latest version
  remove             Remove scurl and conf-scurl
  status             Show installed version and update availability
  config [key] [val] View or edit configuration

"@
}

function Invoke-Install($TargetVersion) {
    if (Test-ScurlConfig) {
        Read-ScurlConfig
    } else {
        $platform = Get-ScurlPlatform
        $script:OS = $platform.OS
        $script:ARCH = $platform.Arch
        $script:INSTALL_PATH = Join-Path $env:LOCALAPPDATA "scurl\bin"
        $script:BINARY_NAME = "scurl"
    }
    if ($TargetVersion) {
        $script:VERSION = $TargetVersion
    } else {
        $script:VERSION = Get-LatestVersion
    }
    $url = Get-DownloadUrl -Version $script:VERSION -OS $script:OS -Arch $script:ARCH
    Invoke-ScurlDownload -Url $url -InstallPath $script:INSTALL_PATH -BinaryName $script:BINARY_NAME -Version $script:VERSION
    Add-ToUserPath $script:INSTALL_PATH
    Write-ScurlConfig
}

function Invoke-Update {
    if (-not (Test-ScurlConfig)) {
        throw "Error: scurl not installed. Run 'conf-scurl install' first."
    }
    Read-ScurlConfig
    $latest = Get-LatestVersion
    if ($script:VERSION -eq $latest) {
        Write-Host "$script:BINARY_NAME v$script:VERSION is already the latest version."
        return
    }
    Write-Host "Updating $script:BINARY_NAME v$script:VERSION -> v$latest..."
    $script:VERSION = $latest
    $url = Get-DownloadUrl -Version $script:VERSION -OS $script:OS -Arch $script:ARCH
    Invoke-ScurlDownload -Url $url -InstallPath $script:INSTALL_PATH -BinaryName $script:BINARY_NAME -Version $script:VERSION
    Write-ScurlConfig
}

function Invoke-Remove {
    if (-not (Test-ScurlConfig)) {
        throw "Error: scurl not installed."
    }
    Read-ScurlConfig
    $binExe = Join-Path $script:INSTALL_PATH "$script:BINARY_NAME.exe"
    if (Test-Path $binExe) { Remove-Item $binExe -Force }
    $trurl = Join-Path $script:INSTALL_PATH "trurl.exe"
    if (Test-Path $trurl) { Remove-Item $trurl -Force }
    $crt = Join-Path $script:INSTALL_PATH "curl-ca-bundle.crt"
    if (Test-Path $crt) { Remove-Item $crt -Force }
    $confPs1 = Join-Path $script:INSTALL_PATH "conf-scurl.ps1"
    if (Test-Path $confPs1) { Remove-Item $confPs1 -Force }
    $confCmd = Join-Path $script:INSTALL_PATH "conf-scurl.cmd"
    if (Test-Path $confCmd) { Remove-Item $confCmd -Force }
    Remove-FromUserPath $script:INSTALL_PATH
    if (Test-Path $script:ConfigDir) { Remove-Item -Recurse -Force $script:ConfigDir }
    Write-Host "Removed $script:BINARY_NAME."
}

function Show-Status {
    if (-not (Test-ScurlConfig)) {
        Write-Host "scurl is not installed. Run 'conf-scurl install'."
        return
    }
    Read-ScurlConfig
    Write-Host "$script:BINARY_NAME v$script:VERSION"
    Write-Host "Path: $script:INSTALL_PATH\$script:BINARY_NAME.exe"
    Write-Host "OS: $script:OS | Arch: $script:ARCH"
    try {
        $latest = Get-LatestVersion
        if ($script:VERSION -eq $latest) {
            Write-Host "Latest available: v$latest (up to date)"
        } else {
            Write-Host "Latest available: v$latest (update available!)"
        }
    } catch {
        Write-Host "Latest available: (could not check)"
    }
}

function Invoke-Config($Key, $Value) {
    if (-not (Test-ScurlConfig)) {
        throw "Error: no configuration found. Run 'conf-scurl install' first."
    }
    if (-not $Key) {
        Get-Content $script:ConfigFile
    } elseif (-not $Value) {
        $line = Get-Content $script:ConfigFile | Where-Object { $_ -match "^$Key=" }
        if ($line) { ($line -split '=', 2)[1] }
    } else {
        $lines = Get-Content $script:ConfigFile
        $found = $false
        $lines = $lines | ForEach-Object {
            if ($_ -match "^$Key=") { "$Key=$Value"; $found = $true }
            else { $_ }
        }
        if (-not $found) { $lines += "$Key=$Value" }
        $lines | Set-Content $script:ConfigFile
        Write-Host "$Key=$Value"
    }
}

# --- Dispatch (only when run directly, not dot-sourced) ---
if ($MyInvocation.InvocationName -ne '.') {
    $command = if ($args.Count -gt 0) { $args[0] } else { "" }
    switch ($command) {
        "install" { Invoke-Install $(if ($args.Count -gt 1) { $args[1] } else { $null }) }
        "update"  { Invoke-Update }
        "remove"  { Invoke-Remove }
        "status"  { Show-Status }
        "config"  {
            $k = if ($args.Count -gt 1) { $args[1] } else { $null }
            $v = if ($args.Count -gt 2) { $args[2] } else { $null }
            Invoke-Config $k $v
        }
        "--help"  { Show-Usage }
        "-h"      { Show-Usage }
        ""        { Show-Usage }
        default   { Write-Error "Error: unknown command '$command'"; Show-Usage; exit 1 }
    }
}