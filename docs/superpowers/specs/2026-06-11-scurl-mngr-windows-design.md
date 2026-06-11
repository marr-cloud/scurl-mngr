# scurl-mngr: PowerShell Port for Windows

Port de `conf-scurl` a PowerShell para gestionar instalaciones de [static-curl](https://github.com/stunnel/static-curl) en Windows.

## Objetivo

Proveer la misma funcionalidad que la versión Unix (`conf-scurl` en sh) pero nativa en Windows, sin dependencias externas.

## Arquitectura

Tres archivos nuevos en el mismo repo:

| Archivo | Responsabilidad |
|---------|----------------|
| `install.ps1` | Bootstrap: descarga `conf-scurl.ps1` + `.cmd`, agrega al PATH, ejecuta install |
| `conf-scurl.ps1` | Script monolítico: todos los comandos, detección de plataforma, GitHub API, descarga |
| `conf-scurl.cmd` | Wrapper de 1 línea para invocar desde cmd.exe/cualquier shell |

## Dependencias

Solo componentes preinstalados en Windows 10+:
- PowerShell 5.1+
- `tar` (disponible desde Windows 10 1803)

No requiere: jq, curl externo, ni permisos de administrador.

## Layout en disco

```
$env:LOCALAPPDATA\scurl\
├── bin\
│   ├── scurl.exe         ← binario de static-curl
│   ├── conf-scurl.ps1    ← gestor
│   └── conf-scurl.cmd    ← wrapper cmd.exe
└── config                ← archivo key=value
```

## Configuración

Archivo: `$env:LOCALAPPDATA\scurl\config`

Formato key=value (mismo que Unix, sin LIBC):
```
VERSION=8.20.0
INSTALL_PATH=C:\Users\maurr\AppData\Local\scurl\bin
BINARY_NAME=scurl
OS=windows
ARCH=x86_64
```

## Bootstrap: `install.ps1`

Invocación: `irm https://raw.githubusercontent.com/marr-cloud/scurl-mngr/main/install.ps1 | iex`

Flujo:
1. Define `$InstallPath` default: `$env:LOCALAPPDATA\scurl\bin` (no-interactivo, configurable después con `conf-scurl config`)
2. Crea directorio con `New-Item -ItemType Directory -Force`
3. Descarga `conf-scurl.ps1` desde GitHub raw con `Invoke-WebRequest`
4. Crea `conf-scurl.cmd` con contenido del wrapper
5. Agrega `$InstallPath` al User PATH si no está (vía `[Environment]::SetEnvironmentVariable`)
6. Actualiza `$env:Path` en la sesión actual
7. Ejecuta `& "$InstallPath\conf-scurl.ps1" install`

## Comandos

### `conf-scurl install [version]`

1. Detecta arch: `$env:PROCESSOR_ARCHITECTURE` → mapeo: `AMD64`→`x86_64`, `ARM64`→`aarch64`, `x86`→`i686`
2. OS: siempre `windows`
3. Consulta GitHub API: `Invoke-RestMethod "https://api.github.com/repos/stunnel/static-curl/releases/latest"`
4. Filtra asset: `curl-windows-{arch}-{version}.tar.xz`
5. Descarga con `Invoke-WebRequest -OutFile`
6. Extrae con `tar -xJf` en directorio temporal
7. Mueve `curl.exe` a `$InstallPath\$BinaryName.exe`
8. Escribe config
9. Confirma: `✓ scurl v8.20.0 installed in C:\...\scurl.exe`

### `conf-scurl update`

1. Lee config
2. Consulta GitHub API latest
3. Compara versiones
4. Si hay nueva: descarga e instala
5. Si actual: `scurl v8.20.0 is already the latest version.`

### `conf-scurl remove`

1. Elimina `$InstallPath\scurl.exe`
2. Elimina `$InstallPath\conf-scurl.ps1`
3. Elimina `$InstallPath\conf-scurl.cmd`
4. Elimina directorio `$env:LOCALAPPDATA\scurl\` (config incluido)
5. Quita entrada del User PATH
6. Confirma

### `conf-scurl status`

Muestra:
```
scurl v8.20.0
Path: C:\Users\maurr\AppData\Local\scurl\bin\scurl.exe
OS: windows | Arch: x86_64
Latest available: v8.20.0 (up to date)
```

### `conf-scurl config [key] [val]`

- Sin args: muestra config completa
- Con key: muestra valor
- Con key y val: actualiza

## Detección de plataforma

- OS: hardcoded `windows`
- Arch: `$env:PROCESSOR_ARCHITECTURE` mapeado:
  - `AMD64` → `x86_64`
  - `ARM64` → `aarch64`
  - `x86` → `i686`

## Asset naming

Patrón: `curl-windows-{arch}-{version}.tar.xz`

Nota: Windows assets usan `aarch64` en el nombre (no `arm64`).

## Manejo del PATH

### Agregar (install)
```powershell
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$InstallPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$InstallPath;$currentPath", "User")
}
$env:Path = "$InstallPath;$env:Path"
```

### Quitar (remove)
```powershell
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallPath }) -join ';'
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")
```

## Wrapper `conf-scurl.cmd`

```cmd
@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0conf-scurl.ps1" %*
```

Permite invocar `conf-scurl install` desde cmd.exe, PowerShell, o Windows Terminal sin prefijo.

## Manejo de errores

- PowerShell no disponible: imposible (es el runtime)
- `tar` no disponible (Windows 7/8): `"Error: tar is required. Windows 10+ includes it natively."`
- Sin red: `"Error: cannot reach GitHub API. Check your internet connection."`
- Asset no encontrado: lista assets disponibles
- PATH demasiado largo (>2048 chars): warning pero continúa

## Integración con el repo existente

Los archivos Windows se agregan al mismo repo `marr-cloud/scurl-mngr`:
```
scurl-mngr/
├── conf-scurl         ← Unix (existente)
├── install.sh         ← Unix bootstrap (existente)
├── conf-scurl.ps1     ← Windows (nuevo)
├── conf-scurl.cmd     ← Windows wrapper (nuevo)
├── install.ps1        ← Windows bootstrap (nuevo)
├── tests/
│   ├── test_conf_scurl.sh     ← Unix tests (existente)
│   └── test_conf_scurl.ps1    ← Windows tests (nuevo)
└── README.md          ← actualizar con sección Windows
```

## Fuera de scope

- GUI / instalador MSI
- Soporte Windows 7/8 (sin tar nativo)
- Auto-update de conf-scurl.ps1 en sí
- Verificación de checksums SHA256 (mejora futura)
