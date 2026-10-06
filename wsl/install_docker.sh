#!/usr/bin/env bash
# =============================================================================
#  Robótica Cooperativa — instala Docker Engine DENTRO de la distro WSL
#  Uso (en la distro 'U24.04_Docker_ROS2'):   bash wsl/install_docker.sh
# =============================================================================
set -euo pipefail
info() { echo -e "\e[36m[robcoop]\e[0m $*"; }
warn() { echo -e "\e[33m[robcoop]\e[0m $*"; }
die()  { echo -e "\e[31m[robcoop]\e[0m $*"; exit 1; }

grep -qi microsoft /proc/version || warn "No parece WSL; continúo igualmente."

# --- 1. No mezclar con Docker Desktop ----------------------------------------
if [ -e /mnt/wsl/docker-desktop ] || readlink -f "$(command -v docker 2>/dev/null || echo /x)" | grep -q docker-desktop; then
    die "Detectada integración de Docker Desktop en esta distro. Desactívala en Docker Desktop > Settings > Resources > WSL integration."
fi

# --- 2. systemd (necesario para que dockerd arranque solo) --------------------
if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
    info "Activando systemd en /etc/wsl.conf"
    if grep -q '^\[boot\]' /etc/wsl.conf 2>/dev/null; then
        sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
    else
        printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
    fi
    warn "Ejecuta en Windows 'wsl --terminate $WSL_DISTRO_NAME', vuelve a entrar y relanza este script."
    exit 0
fi

# --- 3. Docker Engine desde el repositorio oficial ----------------------------
if command -v dockerd >/dev/null; then
    info "Docker Engine ya instalado: $(docker --version)"
else
    info "Instalando Docker Engine..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    . /etc/os-release
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

sudo systemctl enable --now docker
if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "Añadido $USER al grupo docker: cierra la terminal y vuelve a entrar."
fi

# --- 4. Comprobaciones --------------------------------------------------------
[ -e /dev/dxg ] && info "GPU WSL (/dev/dxg) disponible" || warn "/dev/dxg no encontrado: Gazebo irá por CPU"
[ -d /mnt/wslg ] && info "WSLg disponible" || warn "WSLg no encontrado: no se abrirán ventanas"
if ip -4 -o addr show | grep -qE "inet (192\.168|10\.)"; then
    info "Red en modo espejo detectada (IP de la LAN visible desde WSL)"
else
    warn "No se ve la IP de la LAN: ¿.wslconfig con networkingMode=mirrored y 'wsl --shutdown'?"
fi
info "Listo. Siguiente paso:  ./robcoop.sh build   (o ./robcoop.sh pull)"
