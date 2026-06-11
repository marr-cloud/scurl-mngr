# scurl-mngr

Manage [static-curl](https://github.com/stunnel/static-curl) installations.

## Quick Install

```sh
curl -fsSL https://raw.githubusercontent.com/marr-cloud/scurl-mngr/main/install.sh | sh
```

## Requirements

- `jq`
- `curl` or `wget`
- `tar` with xz support

## Commands

```
conf-scurl install [version]  # Install (latest or specific version)
conf-scurl update             # Update to latest version
conf-scurl remove             # Remove scurl and conf-scurl
conf-scurl status             # Show version and update info
conf-scurl config [key] [val] # View or edit configuration
```

## Configuration

Stored in `~/.config/scurl/config`:

| Key | Description |
|-----|-------------|
| VERSION | Installed version |
| INSTALL_PATH | Directory for binaries |
| BINARY_NAME | Name of the curl binary (default: scurl) |
| OS | Operating system |
| ARCH | Architecture |
| LIBC | C library (Linux only: glibc/musl) |

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