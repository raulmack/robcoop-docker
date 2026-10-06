#!/usr/bin/env bash
# =============================================================================
#  robcoop — atajos para el entorno de prácticas (ejecutar en la distro WSL)
#    ./robcoop.sh pull     descarga la imagen publicada (la primera vez, ~6-8 GB)
#    ./robcoop.sh shell    abre una terminal dentro (repetir para más terminales)
#    ./robcoop.sh check    comprueba gráficos, red y DDS
#    ./robcoop.sh s0       genera el informe de la sesión 0 (informe_s0_<usuario>.txt)
#    ./robcoop.sh update   actualiza el repositorio y la imagen
#    ./robcoop.sh down     para y elimina el contenedor (el workspace se conserva)
#    ./robcoop.sh up       arranca el contenedor en segundo plano
#    ./robcoop.sh build    construye la imagen en local (alternativa a pull)
#    ./robcoop.sh zenoh    arranca el puente Zenoh (Windows 10)
# =============================================================================
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

if [ ! -f .env ]; then
    cp .env.example .env
    sed -i "s/^HOST_UID=.*/HOST_UID=$(id -u)/; s/^HOST_GID=.*/HOST_GID=$(id -g)/" .env
    echo "[robcoop] Creado .env a partir de .env.example"
fi
mkdir -p ws/src

IMG=$(grep -E '^ROBCOOP_IMAGE=' .env | cut -d= -f2-)
IMG=${IMG:-ghcr.io/raulmack/robcoop:humble}

running() { [ "$(docker inspect -f '{{.State.Running}}' robcoop 2>/dev/null)" = "true" ]; }

ensure_image() {
    docker image inspect "$IMG" >/dev/null 2>&1 && return 0
    echo "[robcoop] No está la imagen $IMG: descargándola (solo la primera vez)..."
    docker compose pull ros || {
        echo "[robcoop] No se pudo descargar; se construye en local (20-40 min)"
        docker compose build ros; }
}

start() { running || { ensure_image; docker compose up -d ros; }; }

# Ejecuta un comando dentro del contenedor con el entorno de ROS cargado
inside() { docker compose exec -T ros bash -lc "$1"; }

s0_report() {
    local out="informe_s0_$(whoami).txt"
    start
    {
        echo "#### Informe S0 — Robótica Cooperativa"
        echo "fecha: $(date -Iseconds)"
        echo "usuario WSL: $(whoami)   distro: ${WSL_DISTRO_NAME:-no-WSL}"
        echo "Windows: $(cd /mnt/c 2>/dev/null && /mnt/c/Windows/System32/cmd.exe /c ver 2>/dev/null | iconv -f CP850 -t UTF-8 2>/dev/null | tr -d '\r' | grep -ai windows || echo 'no disponible')"
        echo "kernel: $(uname -r)"
        echo "CPU: $(nproc) hilos   RAM: $(free -g | awk '/Mem:/{print $2}') GB   disco libre: $(df -h ~ | awk 'NR==2{print $4}')"
        echo "docker: $(docker version --format '{{.Server.Version}}' 2>/dev/null)"
        echo "imagen: $IMG  $(docker image inspect --format '{{index .RepoDigests 0}}' "$IMG" 2>/dev/null | sed 's/.*@//' | cut -c1-19)"
        echo
        echo "#### check_env"
        inside "check_env" 2>&1 || true
        echo
        echo "#### Prueba de simulación (2 robots, sin ventanas, ~80 s)"
        inside "cd ~/ws && colcon build --packages-select turtlebot3_gz_bringup >/dev/null 2>&1 && source install/setup.bash && \
          (timeout -s INT 80 ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=2 gui:=false rviz:=false >/tmp/s0_launch.log 2>&1 &) ; \
          sleep 40; \
          echo \"tópicos tb3_*: \$(ros2 topic list | grep -c tb3_)  (esperado: 14 o más)\"; \
          rate() { timeout 12 ros2 topic hz \$1 2>/dev/null | grep 'average rate' | tail -1 | awk '{print \$3}'; }; \
          check() { r=\$(rate \$1); if [ -z \"\$r\" ]; then echo \"\$1: SIN DATOS  -> FALLO\"; \
            elif awk -v r=\$r -v lo=\$2 'BEGIN{exit !(r>=lo)}'; then echo \"\$1: \$r Hz  -> OK\"; \
            else echo \"\$1: \$r Hz (mínimo \$2)  -> FALLO\"; fi; }; \
          check /tb3_0/scan 3.5; check /tb3_1/odom 25; \
          sleep 15" 2>&1 || true
        echo
        echo "#### Fin del informe"
    } 2>&1 | sed -u 's/\x1b\[[0-9;]*m//g' | tee "$out"
    echo
    echo "[robcoop] Informe guardado en: $(pwd)/$out"
    echo "[robcoop] Entrégalo junto con una captura de RViz con los robots teleoperados."
}

case "${1:-shell}" in
    pull)   docker compose pull ros ;;
    build)  docker compose build ros ;;
    up)     start ;;
    shell)  start; docker compose exec ros bash ;;
    check)  start; docker compose exec ros check_env ;;
    s0)     s0_report ;;
    update) git pull --ff-only || true; docker compose pull ros
            running && echo "[robcoop] Reinicia el contenedor para usar la imagen nueva: ./robcoop.sh down" || true ;;
    zenoh)  docker compose --profile zenoh up -d zenoh && docker compose logs -f zenoh ;;
    down)   docker compose --profile zenoh down ;;
    *) sed -n '3,13p' "$0"; exit 1 ;;
esac
