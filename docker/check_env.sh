#!/usr/bin/env bash
# =============================================================================
#  check_env — comprobación rápida del entorno dentro del contenedor
# =============================================================================
source /opt/ros/humble/setup.bash

ok()   { echo -e "  \e[32m✔\e[0m $*"; }
warn() { echo -e "  \e[33m!\e[0m $*"; }
bad()  { echo -e "  \e[31m✘\e[0m $*"; }

echo "== ROS 2 =="
ok "ROS_DISTRO=${ROS_DISTRO}  ROS_DOMAIN_ID=${ROS_DOMAIN_ID}  RMW=${RMW_IMPLEMENTATION}"
[ "${ROS_LOCALHOST_ONLY:-0}" = "1" ] && warn "ROS_LOCALHOST_ONLY=1: no verás a los robots"

echo "== Gráficos =="
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    ok "DISPLAY=${DISPLAY}  WAYLAND_DISPLAY=${WAYLAND_DISPLAY}"
else
    bad "Sin DISPLAY: las ventanas no se abrirán"
fi
if [ -e /dev/dxg ]; then ok "/dev/dxg presente (GPU de WSL)"; else warn "/dev/dxg ausente (no es WSL o falta el montaje)"; fi
if command -v glxinfo >/dev/null; then
    R=$(glxinfo -B 2>/dev/null | grep -E "OpenGL renderer string" | cut -d: -f2-)
    V=$(glxinfo -B 2>/dev/null | grep -E "OpenGL core profile version string" | cut -d: -f2-)
    if [ -z "$R" ]; then
        bad "glxinfo no puede abrir el display"
    elif echo "$R" | grep -qi llvmpipe; then
        warn "Render por CPU (llvmpipe):$R"
    else
        ok "Renderer:$R  (core$V)"
    fi
fi

echo "== Gazebo =="
if [ -n "$ROBCOOP_RENDER_ENGINE" ]; then
    ok "ign gazebo usará --render-engine ${ROBCOOP_RENDER_ENGINE}"
else
    ok "ign gazebo usará su motor por defecto (ogre2)"
fi

echo "== Red =="
ip -4 -o addr show | awk '{print "  · "$2"  "$4}'
if ip -4 -o addr show | grep -qE "inet 172\.(1[6-9]|2[0-9]|3[01])\." && ! ip -4 -o addr show | grep -qE "inet (192\.168|10\.)"; then
    warn "Solo se ve una IP interna de WSL: ¿está activo networkingMode=mirrored?"
fi

echo "== Comunicación DDS local =="
timeout 6 ros2 topic pub -r 5 /robcoop_check std_msgs/msg/String "{data: ok}" >/dev/null 2>&1 &
if timeout 5 ros2 topic echo --once /robcoop_check std_msgs/msg/String >/dev/null 2>&1; then
    ok "Publicar/suscribir funciona"
else
    bad "No llegan mensajes en local"
fi
wait 2>/dev/null

echo "== Nodos visibles en el dominio ${ROS_DOMAIN_ID} =="
ros2 node list --no-daemon 2>/dev/null | sed 's/^/  · /' || true
echo
echo "Pruebas gráficas:  rviz2    |    ign gazebo shapes.sdf"
