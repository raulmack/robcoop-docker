# turtlebot3_gz_bringup (v0.2) — simulación multirrobot

N TurtleBot3 Burger en Gazebo Fortress con **la misma convención de tópicos y frames que los
robots reales** lanzados con `robot.launch.py namespace:=tb3_i`. Así el código de los alumnos
pasa de simulación a robots reales sin cambios.

## Uso

```bash
cb                                                  # compilar (alias en el contenedor)
ros2 launch turtlebot3_gz_bringup multi_robot.launch.py                       # 3 robots, mundo vacío
ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=4 world:=arena layout:=grid
ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=2 poses:="0,0,0; 1,0,1.57"
```

| Argumento | Por defecto | Valores |
|---|---|---|
| `num_robots` | 3 | 1 … 8 (más es posible, pero cuesta CPU) |
| `world` | `empty` | `empty`, `arena` (4×4 m con obstáculos) o ruta a un `.sdf` |
| `layout` | `line` | `line`, `grid`, `circle` (mirando al centro) |
| `spacing` | 0.5 | separación en metros |
| `poses` | — | `"x,y,yaw; x,y,yaw; ..."` (tiene prioridad sobre `layout`) |
| `gui` | true | `false` = Gazebo sin ventana (más ligero) |
| `rviz` | true | abre RViz con un modelo y un LaserScan de color por robot |
| `follower_demo` | false | los robots 1…N-1 copian los `cmd_vel` de `tb3_0` |

Teleoperar un robot (otra terminal: `./robcoop.sh shell`):

```bash
ros2 run turtlebot3_teleop teleop_keyboard --ros-args -r __ns:=/tb3_0
```

## Interfaz por robot (`tb3_0`, `tb3_1`, …)

| Tópico | Tipo | Notas |
|---|---|---|
| `/tb3_i/cmd_vel` | `geometry_msgs/Twist` | entrada (máx. 0.22 m/s, 2.84 rad/s) |
| `/tb3_i/odom` | `nav_msgs/Odometry` | odometría de ruedas, frame `tb3_i/odom` |
| `/tb3_i/scan` | `sensor_msgs/LaserScan` | 360 muestras, 0.12–3.5 m, 5 Hz, frame `tb3_i/base_scan` |
| `/tb3_i/imu` | `sensor_msgs/Imu` | 100 Hz, frame `tb3_i/imu_link` |
| `/tb3_i/joint_states` | `sensor_msgs/JointState` | ruedas |
| `/tb3_i/ground_truth` | `nav_msgs/Odometry` | **solo simulación**: pose real en `map` |
| `/tf`, `/tf_static` | | compartidos; frames con prefijo `tb3_i/` |

Árbol de frames: `map → tb3_i/odom → tb3_i/base_footprint → tb3_i/base_link → tb3_i/base_scan …`.
La transformada `map → tb3_i/odom` es estática (pose inicial). Con robots reales la
proporcionará AMCL sobre un mapa común.

## Cambios respecto a la versión del curso pasado

- `num_robots` y demás argumentos funcionan de verdad (`OpaqueFunction`).
- Namespaces `tb3_i` idénticos a los reales (antes `robot_i` en ROS y `tb3_i` en Gazebo).
- Puentes para LiDAR, IMU, TF y joint_states de cada robot (antes solo `cmd_vel` y `odom`).
- El mundo declara los sistemas `Sensors` e `Imu`: sin ellos el LiDAR no publica.
- Mundo sin dependencia de Gazebo Fuel (sin Internet) y una arena con paredes y obstáculos.
- Mallas tomadas de `turtlebot3_description` (no hace falta copiarlas).
- Corregidos links sin inercia (Gazebo les asignaba 1 kg), la rueda loca bajo el suelo y la
  caja de colisión del chasis que rozaba el suelo.
- Pose real (`ground_truth`) para evaluar algoritmos.

## Comprobaciones tras el primer arranque

```bash
ros2 topic list | grep tb3_0
ros2 topic hz /tb3_0/scan                  # ≈ 5 Hz
ros2 topic echo --once /tb3_0/scan | grep frame_id      # tb3_0/base_scan
ros2 topic echo --once /tb3_0/ground_truth | grep -A3 position
ros2 run tf2_tools view_frames             # genera frames_*.pdf con el árbol
```
