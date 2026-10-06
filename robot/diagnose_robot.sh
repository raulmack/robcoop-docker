#!/usr/bin/env bash
# =============================================================================
#  Robótica Cooperativa — diagnóstico de un TurtleBot3 (ejecutar EN LA RASPBERRY)
#  Solo lee información; no cambia nada.
#     bash diagnose_robot.sh            (o:  bash diagnose_robot.sh > informe.txt)
# =============================================================================
sec() { echo; echo "=== $* ==="; }

sec "Sistema"
echo "hostname: $(hostname)"
grep PRETTY_NAME /etc/os-release
echo "kernel:   $(uname -r)   arch: $(uname -m)"
echo "usuario:  $USER"
uptime -p 2>/dev/null

sec "Red"
ip -4 -o addr show | awk '{print $2, $4}'
ip route | grep default
command -v iwgetid >/dev/null && echo "SSID: $(iwgetid -r)"
grep -rh "ssid\|access-points" /etc/netplan/ 2>/dev/null | head -5

sec "Hora (sincronización)"
timedatectl 2>/dev/null | grep -E "Local time|synchronized|NTP service"
for s in chrony systemd-timesyncd ntp; do
    systemctl is-active --quiet "$s" 2>/dev/null && echo "servicio activo: $s"
done

sec "Variables de entorno de ROS en ~/.bashrc"
grep -nE "ROS_DOMAIN_ID|ROS_LOCALHOST_ONLY|RMW_IMPLEMENTATION|TURTLEBOT3_MODEL|LDS_MODEL|ROS_NAMESPACE|setup.bash|FASTRTPS|CYCLONEDDS" ~/.bashrc

sec "Instalación de ROS 2"
ls /opt/ros/ 2>/dev/null
for ws in ~/turtlebot3_ws ~/ros2_ws ~/colcon_ws; do
    [ -d "$ws/src" ] && { echo "workspace: $ws"; ls "$ws/src"; }
done

sec "Versiones de los paquetes del robot (git)"
for d in ~/turtlebot3_ws/src/*/ ; do
    [ -d "$d/.git" ] && echo "$(basename "$d"): rama $(git -C "$d" rev-parse --abbrev-ref HEAD) · $(git -C "$d" log -1 --format='%h %cs')"
done

sec "Soporte de namespace en el bringup"
RL=$(find ~/turtlebot3_ws/src -path "*turtlebot3_bringup/launch/robot.launch.py" 2>/dev/null | head -1)
if [ -n "$RL" ]; then
    grep -q "namespace" "$RL" && echo "robot.launch.py: acepta namespace" || echo "robot.launch.py: SIN namespace"
    grep -n "frame_id" "$RL"
fi
grep -rln "name_space_" ~/turtlebot3_ws/src/turtlebot3/turtlebot3_node/src 2>/dev/null | sed 's/^/prefijo de frames en: /'

sec "Driver del LiDAR LDS-02 (ld08_driver)"
LD=$(find ~/turtlebot3_ws/src -maxdepth 2 -type d -name "ld08_driver*" 2>/dev/null | head -1)
if [ -n "$LD" ]; then
    echo "ruta: $LD"
    find "$LD" -name "*.launch.py" -exec echo "--- {}" \; -exec cat {} \;
    echo "--- parámetros y frame_id en el código:"
    grep -rn "declare_parameter\|frame_id\|base_scan" "$LD/src" 2>/dev/null | head -20
else
    echo "ld08_driver no encontrado en el workspace"
    ls /opt/ros/*/share 2>/dev/null | grep -i ld08
fi

sec "Dispositivos"
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null

sec "Servicios propios que arranquen ROS"
systemctl list-unit-files 2>/dev/null | grep -iE "turtle|ros|bringup"

echo; echo "=== Fin. Copia toda la salida y pásasela a Claude ==="
