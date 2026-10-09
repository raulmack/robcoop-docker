# Directorio de ejecución propio (también para terminales abiertas con 'exec')
[ -n "$XDG_RUNTIME_DIR" ] && mkdir -p -m 0700 "$XDG_RUNTIME_DIR" 2>/dev/null
# Entorno ROS 2 para shells interactivos dentro del contenedor
source /opt/ros/humble/setup.bash
if [ -f "$HOME/ws/install/setup.bash" ]; then
    source "$HOME/ws/install/setup.bash"
fi
if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
fi

# Atajos
alias cb='cd ~/ws && colcon build --symlink-install && source install/setup.bash'
alias cbp='cd ~/ws && colcon build --symlink-install --packages-select'
alias rs='source ~/ws/install/setup.bash'

# -----------------------------------------------------------------------------
# Modo de trabajo (se guarda en ~/ws/.robcoop_modo y vale para todas las terminales)
#   modo_sim   ROS solo dentro de este PC: tus robots simulados no se mezclan con
#              los del laboratorio ni con los de otras parejas (por defecto)
#   modo_real  ROS en la red del router: para trabajar con los TurtleBot3 reales
# -----------------------------------------------------------------------------
_ROBCOOP_MODE_FILE="$HOME/ws/.robcoop_modo"
_ROBCOOP_PS1="${_ROBCOOP_PS1:-$PS1}"

_robcoop_apply_mode() {
    local m
    m=$(cat "$_ROBCOOP_MODE_FILE" 2>/dev/null)
    if [ "$m" = "real" ]; then
        export ROS_LOCALHOST_ONLY=0 ROBCOOP_MODE=real
        PS1="\[\e[1;31m\][REAL]\[\e[0m\] $_ROBCOOP_PS1"
    else
        export ROS_LOCALHOST_ONLY=1 ROBCOOP_MODE=sim
        PS1="\[\e[1;32m\][SIM]\[\e[0m\] $_ROBCOOP_PS1"
    fi
}

_robcoop_set_mode() {
    echo "$1" > "$_ROBCOOP_MODE_FILE"
    _robcoop_apply_mode
    ros2 daemon stop >/dev/null 2>&1
    echo -e "\e[1;34m[robcoop]\e[0m Modo $ROBCOOP_MODE (ROS_LOCALHOST_ONLY=$ROS_LOCALHOST_ONLY)."
    echo "          Las demás terminales abiertas siguen en el modo anterior: ciérralas y ábrelas de nuevo."
}
modo_sim()  { _robcoop_set_mode sim; }
modo_real() { _robcoop_set_mode real; }
_robcoop_apply_mode

# Recordatorio del entorno al abrir una terminal
echo -e "\e[1;34m[robcoop]\e[0m ROS_DOMAIN_ID=${ROS_DOMAIN_ID}  RMW=${RMW_IMPLEMENTATION}  TB3=${TURTLEBOT3_MODEL}  MODO=${ROBCOOP_MODE} (modo_sim | modo_real)"
