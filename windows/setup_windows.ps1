<#
=============================================================================
 Robótica Cooperativa — preparación de Windows (ejecutar UNA vez)

 Uso (PowerShell como ADMINISTRADOR):
   Set-ExecutionPolicy -Scope Process Bypass
   .\setup_windows.ps1                 # configura red + firewall
   .\setup_windows.ps1 -InstallDistro  # además crea la distro 'U24.04_Docker_ROS2'

 Qué hace:
   1. Comprueba versión de Windows y de WSL.
   2. Añade al .wslconfig (con copia de seguridad) el modo de red espejo.
      OJO: .wslconfig es GLOBAL -> afecta a todas tus distros WSL.
   3. Abre en el firewall de Hyper-V SOLO los puertos UDP de DDS y el TCP de
      Zenoh hacia WSL (en lugar de abrirlo todo).
   4. (Opcional) Crea una distro dedicada 'U24.04_Docker_ROS2' (Ubuntu 24.04), separada
      de las que usas para otras asignaturas.
=============================================================================
#>
param(
    [switch]$InstallDistro,
    [string]$DistroName = "U24.04_Docker_ROS2",
    [string]$BaseDistro = "Ubuntu-24.04"
)
$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "[robcoop] $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "[robcoop] $m" -ForegroundColor Yellow }

# --- 0. Administrador ---------------------------------------------------------
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Ejecuta PowerShell como Administrador." }

# --- 1. Versiones -------------------------------------------------------------
$build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
$mirroredOK = $build -ge 22621   # Windows 11 22H2
Info "Windows build $build"
if (-not $mirroredOK) {
    Warn "Este Windows NO admite networkingMode=mirrored (requiere Windows 11 22H2)."
    Warn "Funcionará la simulación, pero para los robots reales usa el perfil 'zenoh'."
}

Info "Actualizando WSL (wsl --update)..."
wsl --update | Out-Null
$wslVer = (wsl --version | Select-Object -First 1) -replace '[^\d\.]', ''
Info "Versión de WSL: $wslVer"

# --- 2. .wslconfig ------------------------------------------------------------
if ($mirroredOK) {
    $cfg = Join-Path $env:USERPROFILE ".wslconfig"
    $settings = [ordered]@{
        "networkingMode" = "mirrored"
        "dnsTunneling"   = "true"
        "firewall"       = "true"
        "autoProxy"      = "true"
    }
    $lines = @()
    if (Test-Path $cfg) {
        $bak = "$cfg.bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        Copy-Item $cfg $bak
        Info "Copia de seguridad: $bak"
        $lines = @(Get-Content $cfg)
    }
    # Localiza (o crea) la sección [wsl2] y fija cada clave dentro de ella
    $start = [Array]::FindIndex([string[]]$lines, [Predicate[string]]{ param($l) $l.Trim() -match '^\[wsl2\]$' })
    if ($start -lt 0) { $lines += "", "[wsl2]"; $start = $lines.Count - 1 }
    foreach ($k in $settings.Keys) {
        $end = $lines.Count
        for ($i = $start + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -match '^\[.+\]$') { $end = $i; break } }
        $found = $false
        for ($i = $start + 1; $i -lt $end; $i++) {
            if ($lines[$i] -match "^\s*$k\s*=") { $lines[$i] = "$k=$($settings[$k])"; $found = $true }
        }
        if (-not $found) {
            $before = if ($end -gt 0) { $lines[0..($end - 1)] } else { @() }
            $after  = if ($end -lt $lines.Count) { $lines[$end..($lines.Count - 1)] } else { @() }
            $lines = @($before) + "$k=$($settings[$k])" + @($after)
        }
    }
    Set-Content -Path $cfg -Value $lines -Encoding ascii
    Info ".wslconfig actualizado:"
    Get-Content $cfg | ForEach-Object { Write-Host "    $_" }
}

# --- 3. Firewall de Hyper-V (solo puertos necesarios) -------------------------
$vmCreator = "{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}"   # ID fijo de WSL
$rules = @(
    @{ Name = "ROBCOOP-DDS-UDP";  Protocol = "UDP"; Ports = "7400-32999" },  # dominios ROS 0-101
    @{ Name = "ROBCOOP-ZENOH-TCP"; Protocol = "TCP"; Ports = "7447" }
)
# (los cmdlets de firewall de Hyper-V solo existen en Windows 11 22H2+; en
#  Windows 10 no hace falta: con Zenoh la conexión sale desde WSL hacia el robot)
if ($mirroredOK) { foreach ($r in $rules) {
    if (Get-NetFirewallHyperVRule -Name $r.Name -ErrorAction SilentlyContinue) {
        Info "Regla $($r.Name) ya existe"
    } else {
        New-NetFirewallHyperVRule -Name $r.Name -DisplayName "Robótica Cooperativa $($r.Protocol) $($r.Ports)" `
            -Direction Inbound -VMCreatorId $vmCreator -Protocol $r.Protocol -LocalPorts $r.Ports -Action Allow | Out-Null
        Info "Regla $($r.Name) creada"
    }
} }

# --- 4. Distro dedicada -------------------------------------------------------
if ($InstallDistro) {
    $existing = (wsl -l -q) -replace "`0", "" | Where-Object { $_ -ne "" }
    if ($existing -contains $DistroName) {
        Info "La distro '$DistroName' ya existe; no se toca."
    } else {
        Info "Instalando $BaseDistro como '$DistroName' (te pedirá usuario y contraseña)..."
        wsl --install $BaseDistro --name $DistroName
        if ($LASTEXITCODE -ne 0) {
            Warn "Tu WSL no admite --name (requiere WSL >= 2.4.4). Alternativa:"
            Warn "  wsl --install $BaseDistro   (y usa esa distro, o expórtala/impórtala con otro nombre)"
        }
    }
}

Warn "Para aplicar .wslconfig hay que reiniciar WSL: 'wsl --shutdown'"
Warn "(cierra TODAS las distros abiertas, también las de otras asignaturas)."
Info "Siguiente paso:  wsl -d $DistroName   y dentro:  bash wsl/install_docker.sh"
