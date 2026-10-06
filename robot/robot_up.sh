#!/usr/bin/env bash
# =============================================================================
#  Robótica Cooperativa — arranca un TurtleBot3 real con namespace desde el PC
#  Ejecutar en la distro WSL (NO en el contenedor):
#
#     robot/robot_up.sh IP NAMESPACE [opciones]
#     robot/robot_up.sh 192.168.0.198 tb3_0
#     robot/robot_up.sh 192.168.0.198 tb3_0 --set-time      # router sin Internet
#
#  Opciones:
#     --set-time     pone en el robot la hora del PC (pide la contraseña de sudo del robot)
#     --user U       usuario SSH del robot (ubuntu)
#     --domain N     ROS_DOMAIN_ID solo para este arranque (30)
#     --lds M        LDS-01 | LDS-02 (LDS-01)
#
#  Qué cambia en el robot: solo copia ~/robcoop/robcoop_robot.launch.py.
#  No toca ~/.bashrc, ni el workspace, ni servicios. Ctrl+C para el robot.
# =============================================================================
set -euo pipefail
[ $# -lt 2 ] && { sed -n '3,19p' "$0"; exit 1; }
IP=$1; NS=$2; shift 2
USR=ubuntu; DOMAIN=30; LDS=LDS-01; SETTIME=0
while [ $# -gt 0 ]; do
    case "$1" in
        --set-time) SETTIME=1 ;;
        --user) USR=$2; shift ;;
        --domain) DOMAIN=$2; shift ;;
        --lds) LDS=$2; shift ;;
        *) echo "Opción desconocida: $1"; exit 1 ;;
    esac
    shift
done
DIR=$(dirname "$(readlink -f "$0")")
T="$USR@$IP"
# Una sola conexión SSH reutilizada (pide la contraseña una vez)
CTL="/tmp/robcoop-ssh-$IP"
SSH=(ssh -o ControlMaster=auto -o ControlPath="$CTL" -o ControlPersist=60)

echo "[robcoop] Copiando launch a $T:~/robcoop/"
"${SSH[@]}" "$T" "mkdir -p ~/robcoop"
scp -q -o ControlPath="$CTL" "$DIR/robcoop_robot.launch.py" "$T:~/robcoop/"

if [ "$SETTIME" = 1 ]; then
    echo "[robcoop] Ajustando la hora del robot a la del PC"
    "${SSH[@]}" -t "$T" "sudo date -u -s @$(date -u +%s) >/dev/null && date"
fi

# Comprobar desfase de reloj (las TF fallan si robot y PC no coinciden)
RT=$("${SSH[@]}" "$T" "date -u +%s.%N"); PT=$(date -u +%s.%N)
SKEW=$(python3 -c "print(abs($RT-$PT))")
echo "[robcoop] Desfase de reloj robot-PC: ${SKEW} s"
python3 -c "import sys; sys.exit(0 if $SKEW < 0.5 else 1)" || {
    echo -e "\e[33m[robcoop] AVISO: reloj desfasado. Conecta el router a Internet o usa --set-time\e[0m"; }

echo "[robcoop] Lanzando $NS (dominio $DOMAIN, $LDS). Ctrl+C para parar."
exec "${SSH[@]}" -t "$T" "export ROS_DOMAIN_ID=$DOMAIN TURTLEBOT3_MODEL=burger LDS_MODEL=$LDS; \
  source /opt/ros/humble/setup.bash; source ~/turtlebot3_ws/install/setup.bash; \
  ros2 launch ~/robcoop/robcoop_robot.launch.py ns:=$NS lds:=$LDS"
