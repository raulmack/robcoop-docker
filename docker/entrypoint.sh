#!/usr/bin/env bash
# Entrypoint: carga ROS 2 y el workspace (si está compilado) y ejecuta el comando.
set -e
source /opt/ros/humble/setup.bash
if [ -f "$HOME/ws/install/setup.bash" ]; then
    source "$HOME/ws/install/setup.bash"
fi
exec "$@"
