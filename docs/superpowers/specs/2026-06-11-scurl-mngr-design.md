# scurl-mngr: Static Curl Manager

CLI para gestionar instalaciones de [static-curl](https://github.com/stunnel/static-curl) releases.

## Objetivo

Proveer un one-liner para instalar y mantener actualizado un binario estático de curl (`scurl`) en sistemas Unix, con una CLI de gestión (`conf-scurl`) separada.

## Arquitectura

Dos componentes:

### 1. `install.sh` (bootstrap)

Script mínimo hosteado en Cloudflare (dominio custom del usuario). Su único trabajo:

1. Verificar dependencias: `jq`, `curl` o `wget`, `tar` (con xz)
2. Preguntar path de instalación (default: `~/.local/bin/`)
3. Descargar `conf-scurl` desde GitHub releases del proyecto y colocarlo en el path con permisos `+x`
4. Ejecutar `conf-scurl install`

Uso: `curl -fsSL https://<dominio>/install.sh | sh`

### 2. `conf-scurl` (gestor)

Script POSIX sh monolítico. Toda la lógica de descarga, configuración y mantenimiento vive aquí.

## Dependencias obligatorias

El script falla inmediatamente con mensaje de error si alguna falta:

- `jq` — parsing de la API de GitHub
- `curl` o `wget` — descarga de assets
- `tar` con soporte xz — extracción de releases

Mensajes de error incluyen instrucciones de instalación por plataforma:
- Debian/Ubuntu: `apt install jq`
- macOS: `brew install jq`
- Alpine: `apk add jq`

## Configuración

Archivo: `~/.config/scurl/config`

Formato key=value, una por línea:

```
VERSION=8.20.0
INSTALL_PATH=/home/user/.local/bin
BINARY_NAME=scurl
OS=linux
ARCH=x86_64
LIBC=glibc
```

Claves:
- `VERSION` — versión instalada actualmente
- `INSTALL_PATH` — directorio donde viven `scurl` y `conf-scurl`
- `BINARY_NAME` — nombre del binario (default: `scurl`)
- `OS` — sistema operativo detectado (`linux`, `macos`)
- `ARCH` — arquitectura detectada
- `LIBC` — tipo de libc (solo Linux: `glibc` o `musl`)

## Comandos

### `conf-scurl install [version]`

Instala static-curl. Si es la primera vez, ejecuta flujo interactivo.

Flujo primera instalación:
1. Detecta OS con `uname -s` (Linux → `linux`, Darwin → `macos`)
2. Detecta arch con `uname -m` (mapeo: `x86_64`→`x86_64`, `aarch64`/`arm64`→`aarch64`, `armv7l`→`armv7`, `i686`→`i686`)
3. Si Linux: pregunta libc. Sugiere autodetección (`ldd --version 2>&1 | grep -qi musl` → musl, sino glibc). El usuario confirma o elige.
4. Consulta GitHub API: `https://api.github.com/repos/stunnel/static-curl/releases/latest` (o `/tags/{version}` si se especificó versión)
5. Filtra con jq el asset que matchea: `curl-{os}-{arch}-{libc}-{version}.tar.xz` (en macOS sin libc: `curl-macos-{arch}-{version}.tar.xz`)
6. Descarga el .tar.xz
7. Extrae con `tar -xJf`, obtiene el binario `curl`
8. Renombra a `$BINARY_NAME` (default: `scurl`) y mueve a `$INSTALL_PATH`
9. Escribe/actualiza `~/.config/scurl/config`
10. Imprime confirmación: `✓ scurl v8.20.0 instalado en ~/.local/bin/scurl`

Reinstalación (config ya existe): usa valores guardados, sin preguntas. Si el usuario quiere cambiar plataforma, usa `conf-scurl config` primero.

### `conf-scurl update`

1. Lee versión actual de config
2. Consulta GitHub API latest
3. Compara versiones
4. Si hay nueva: descarga e instala (mismo flujo que install, sin preguntas)
5. Si ya está al día: `scurl v8.20.0 ya es la última versión`

### `conf-scurl remove`

1. Elimina `$INSTALL_PATH/$BINARY_NAME`
2. Elimina `$INSTALL_PATH/conf-scurl`
3. Elimina `~/.config/scurl/` (directorio completo)
4. Imprime confirmación

### `conf-scurl status`

Muestra:
```
scurl v8.20.0
Path: /home/user/.local/bin/scurl
OS: linux | Arch: x86_64 | LibC: glibc
Latest available: v8.20.0 (up to date)
```

Si no puede consultar remoto (sin red), muestra solo info local con aviso.

### `conf-scurl config [key] [value]`

- Sin argumentos: imprime toda la config
- Con key: imprime valor de esa key
- Con key y value: actualiza el valor y reescribe el archivo

## Detección de plataforma

### OS
`uname -s` mapeado:
- `Linux` → `linux`
- `Darwin` → `macos`

### Arquitectura
`uname -m` mapeado a valor interno:
- `x86_64` → `x86_64`
- `aarch64` → `aarch64`
- `arm64` → `aarch64` (macOS reporta arm64)
- `armv7l` → `armv7`
- `i686` / `i386` → `i686`

Para construir el nombre del asset, se usa el valor interno EXCEPTO: macOS usa `arm64` en el nombre del asset (no `aarch64`). El script mapea `aarch64` → `arm64` al construir la URL cuando OS=macos.

### LibC (solo Linux)
Interactivo en primera instalación. Sugerencia automática:
- Si `ldd --version 2>&1 | grep -qi musl` → sugiere musl
- Sino → sugiere glibc
- El usuario confirma con Enter o cambia

## Naming de assets upstream

Patrón: `curl-{os}-{arch}-{libc}-{version}.tar.xz`

Ejemplos:
- `curl-linux-x86_64-glibc-8.20.0.tar.xz`
- `curl-linux-aarch64-musl-8.20.0.tar.xz`
- `curl-macos-arm64-8.20.0.tar.xz` (sin libc)
- `curl-macos-x86_64-8.20.0.tar.xz`

Nota: macOS usa `arm64` en el nombre del asset (no `aarch64`). El mapeo de arch debe contemplar esto según OS.

## Manejo de errores

- Dependencia faltante: mensaje con instrucción de instalación, exit 1
- Sin conexión: `"Error: cannot reach GitHub API. Check your internet connection."`, exit 1
- Asset no encontrado: `"Error: no release found for {os}-{arch}-{libc}. Available platforms: ..."` + lista de plataformas del release, exit 1
- Directorio de instalación no existe: lo crea con `mkdir -p`
- Permisos insuficientes: sugiere usar otro path o `sudo`

## Distribución

### Repositorio (GitHub del proyecto scurl-mngr)
- `install.sh` — bootstrap
- `conf-scurl` — el gestor (se publica como release asset también)
- `README.md` — documentación
- `docs/` — specs y planes

### Cloudflare
Solo `install.sh` hosteado en el dominio custom para el one-liner público.

## Fuera de scope (v1)

- Windows / PowerShell (port futuro)
- Verificación de checksums SHA256 (mejora futura — los hashes están en el release body)
- Soporte para versiones pre-release
- Instalación de paquetes `-dev`
- Múltiples versiones simultáneas
