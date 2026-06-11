# tests/test_conf_scurl.ps1
# Minimal test harness for conf-scurl.ps1 (no Pester dependency)

$script:Pass = 0
$script:Fail = 0

function Assert-Eq($Actual, $Expected, $Msg) {
    if ($Actual -eq $Expected) { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: expected '$Expected', got '$Actual' - $Msg"
    }
}

function Assert-Contains($String, $Substring, $Msg) {
    if ($String -like "*$Substring*") { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: '$String' does not contain '$Substring' - $Msg"
    }
}

function Assert-True($Value, $Msg) {
    if ($Value) { $script:Pass++ }
    else {
        $script:Fail++
        Write-Error "FAIL: expected true - $Msg"
    }
}

function Show-Summary {
    Write-Host "`nResults: $script:Pass passed, $script:Fail failed"
    if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
}

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

# --- Test: platform detection ---
. "$PSScriptRoot/../conf-scurl.ps1"

$result = Get-ScurlPlatform
Assert-Eq $result.OS "windows" "detect OS"
Assert-True ($result.Arch -ne "") "detect arch non-empty"

# --- Test: GitHub API ---
. "$PSScriptRoot/../conf-scurl.ps1"

$version = Get-LatestVersion
Assert-True ($version -match '^\d+\.\d+\.\d+$') "fetch latest version is semver: $version"

# --- Test: download and install ---
. "$PSScriptRoot/../conf-scurl.ps1"

$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "scurl-dl-test-$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

$version = Get-LatestVersion
$url = Get-DownloadUrl -Version $version -OS "windows" -Arch "x86_64"
Invoke-ScurlDownload -Url $url -InstallPath $testDir -BinaryName "scurl" -Version $version

Assert-True (Test-Path (Join-Path $testDir "scurl.exe")) "scurl.exe exists after download"

Remove-Item -Recurse -Force $testDir

Show-Summary
