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

# Recordatorio del entorno al abrir una terminal
echo -e "\e[1;34m[robcoop]\e[0m ROS_DOMAIN_ID=${ROS_DOMAIN_ID}  RMW=${RMW_IMPLEMENTATION}  TB3=${TURTLEBOT3_MODEL}"
