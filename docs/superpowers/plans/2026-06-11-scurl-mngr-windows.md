# scurl-mngr Windows PowerShell Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port scurl-mngr to PowerShell for Windows — `conf-scurl.ps1` + `conf-scurl.cmd` wrapper + `install.ps1` bootstrap.

**Architecture:** Single monolithic `conf-scurl.ps1` with all logic. `install.ps1` bootstrap places it and triggers first install. `conf-scurl.cmd` wrapper enables use from cmd.exe.

**Tech Stack:** PowerShell 5.1+, Invoke-RestMethod, tar (native Win 10+), GitHub Releases API

---

## File Structure

| File | Responsibility |
|------|---------------|
| `conf-scurl.ps1` | Main CLI: commands (install, update, remove, status, config), platform detection, GitHub API, download+extract, config I/O, PATH management |
| `conf-scurl.cmd` | One-line wrapper for cmd.exe invocation |
| `install.ps1` | Bootstrap: download conf-scurl.ps1+.cmd, add to PATH, run install |
| `tests/test_conf_scurl.ps1` | Pester-free tests (simple assert-based, matches Unix harness style) |

---

### Task 1: PowerShell test harness and scaffolding

**Files:**
- Create: `tests/test_conf_scurl.ps1`
- Create: `conf-scurl.ps1` (stub)
- Create: `conf-scurl.cmd`

- [ ] **Step 1: Create conf-scurl.cmd**

```cmd
@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0conf-scurl.ps1" %*
```

- [ ] **Step 2: Create minimal test harness**

```powershell
# tests/test_conf_scurl.ps1
# Minimal test harness for conf-scurl.ps1 (no Pester dependency)

$script:Pass = 0
$script:Fail = 0

function Assert-Eq($Actual, $Expected, $Msg) {
    if ($Actual -eq $Expected) { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: expected '$Expected', got '$Actual' — $Msg"
    }
}

function Assert-Contains($String, $Substring, $Msg) {
    if ($String -like "*$Substring*") { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: '$String' does not contain '$Substring' — $Msg"
    }
}

function Assert-True($Value, $Msg) {
    if ($Value) { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: expected true — $Msg"
    }
}

function Show-Summary {
    Write-Host "`nResults: $script:Pass passed, $script:Fail failed"
    if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
}

# Tests will be added in subsequent tasks

Show-Summary
```

- [ ] **Step 3: Create empty conf-scurl.ps1 stub**

```powershell
# conf-scurl.ps1 - Static curl manager for Windows
#Requires -Version 5.1
$ErrorActionPreference = "Stop"
```

- [ ] **Step 4: Run tests to verify harness works**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: `Results: 0 passed, 0 failed` with exit 0

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 conf-scurl.cmd tests/test_conf_scurl.ps1
git commit -m "chore: PowerShell scaffolding and test harness"
```

---

### Task 2: Config I/O

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for config read/write**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: config I/O ---
. "$PSScriptRoot/../conf-scurl.ps1"

$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "scurl-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

$script:ConfigDir = $testDir
$script:ConfigFile = Join-Path $testDir "config"
$script:VERSION = "8.20.0"
$script:INSTALL_PATH = "C:\test"
$script:BINARY_NAME = "scurl"
$script:OS = "windows"
$script:ARCH = "x86_64"

Write-ScurlConfig
$content = Get-Content $script:ConfigFile -Raw
Assert-Contains $content "VERSION=8.20.0" "write config VERSION"
Assert-Contains $content "INSTALL_PATH=C:\test" "write config INSTALL_PATH"

$script:VERSION = ""
$script:INSTALL_PATH = ""
Read-ScurlConfig
Assert-Eq $script:VERSION "8.20.0" "read config VERSION"
Assert-Eq $script:INSTALL_PATH "C:\test" "read config INSTALL_PATH"

Remove-Item -Recurse -Force $testDir
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: FAIL (Write-ScurlConfig not defined)

- [ ] **Step 3: Implement config I/O in conf-scurl.ps1**

Add to `conf-scurl.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add config file read/write"
```

---

### Task 3: Platform detection

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for platform detection**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: platform detection ---
. "$PSScriptRoot/../conf-scurl.ps1"

$result = Get-ScurlPlatform
Assert-Eq $result.OS "windows" "detect OS"
Assert-True ($result.Arch -ne "") "detect arch non-empty"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: FAIL (Get-ScurlPlatform not defined)

- [ ] **Step 3: Implement platform detection**

Add to `conf-scurl.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add platform detection"
```

---

### Task 4: GitHub API interaction

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for GitHub API**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: GitHub API ---
. "$PSScriptRoot/../conf-scurl.ps1"

$version = Get-LatestVersion
Assert-True ($version -match '^\d+\.\d+\.\d+$') "fetch latest version is semver: $version"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: FAIL (Get-LatestVersion not defined)

- [ ] **Step 3: Implement GitHub API functions**

Add to `conf-scurl.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add GitHub API interaction"
```

---

### Task 5: Download and install logic

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for download**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: download and install ---
. "$PSScriptRoot/../conf-scurl.ps1"

$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "scurl-dl-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

$version = Get-LatestVersion
$url = Get-DownloadUrl -Version $version -OS "windows" -Arch "x86_64"
Invoke-ScurlDownload -Url $url -InstallPath $testDir -BinaryName "scurl" -Version $version

Assert-True (Test-Path (Join-Path $testDir "scurl.exe")) "scurl.exe exists after download"

Remove-Item -Recurse -Force $testDir
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: FAIL (Invoke-ScurlDownload not defined)

- [ ] **Step 3: Implement download and install**

Add to `conf-scurl.ps1`:

```powershell
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

    Remove-Item -Recurse -Force $tmpDir
    Write-Host "✓ $BinaryName v$Version installed in $InstallPath\$BinaryName.exe"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS (downloads real binary)

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add download and install logic"
```

---

### Task 6: PATH management

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for PATH functions**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: PATH management ---
. "$PSScriptRoot/../conf-scurl.ps1"

$fakePath = "C:\scurl-test-path-$(Get-Random)"
$before = [Environment]::GetEnvironmentVariable("Path", "User")

Add-ToUserPath $fakePath
$after = [Environment]::GetEnvironmentVariable("Path", "User")
Assert-Contains $after $fakePath "Add-ToUserPath adds to PATH"

Remove-FromUserPath $fakePath
$final = [Environment]::GetEnvironmentVariable("Path", "User")
Assert-True ($final -notlike "*$fakePath*") "Remove-FromUserPath removes from PATH"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: FAIL (Add-ToUserPath not defined)

- [ ] **Step 3: Implement PATH management**

Add to `conf-scurl.ps1`:

```powershell
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add PATH management"
```

---

### Task 7: Command dispatch and all commands

**Files:**
- Modify: `conf-scurl.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write failing test for commands**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: command dispatch ---
$output = pwsh -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/../conf-scurl.ps1" "--help" 2>&1 | Out-String
Assert-Contains $output "Usage" "help shows usage"

$output = pwsh -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot/../conf-scurl.ps1" "status" 2>&1 | Out-String
Assert-Contains $output "scurl" "status produces output"
```

- [ ] **Step 2: Implement command dispatch and all commands**

Add to the end of `conf-scurl.ps1`:

```powershell
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
```

- [ ] **Step 3: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add conf-scurl.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add command dispatch and all commands"
```

---

### Task 8: Bootstrap install.ps1

**Files:**
- Create: `install.ps1`
- Modify: `tests/test_conf_scurl.ps1`

- [ ] **Step 1: Write test for install.ps1 syntax**

Append to `tests/test_conf_scurl.ps1` (before `Show-Summary`):

```powershell
# --- Test: install.ps1 syntax ---
$errors = $null
[System.Management.Automation.PSParser]::Tokenize((Get-Content "$PSScriptRoot/../install.ps1" -Raw), [ref]$errors) | Out-Null
Assert-Eq $errors.Count 0 "install.ps1 has valid syntax"
```

- [ ] **Step 2: Create install.ps1**

```powershell
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
```

- [ ] **Step 3: Run test to verify it passes**

Run: `pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add install.ps1 tests/test_conf_scurl.ps1
git commit -m "feat(win): add bootstrap install.ps1"
```

---

### Task 9: Update README and push

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Windows section to README.md**

Append after the existing Configuration section:

```markdown

## Windows

### Quick Install (PowerShell)

```powershell
irm https://raw.githubusercontent.com/marr-cloud/scurl-mngr/main/install.ps1 | iex
```

### Requirements (Windows)

- Windows 10+ (includes PowerShell 5.1 and tar)

### Commands (same as Unix)

```
conf-scurl install [version]
conf-scurl update
conf-scurl remove
conf-scurl status
conf-scurl config [key] [val]
```

Configuration stored in `%LOCALAPPDATA%\scurl\config`.
```

- [ ] **Step 2: Run all tests**

Run: `sh tests/test_conf_scurl.sh && pwsh -NoProfile -File tests/test_conf_scurl.ps1`
Expected: Both pass

- [ ] **Step 3: Commit and push**

```bash
git add README.md
git commit -m "docs: add Windows install instructions to README"
git push
```
