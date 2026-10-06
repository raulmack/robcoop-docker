#!/usr/bin/env python3
"""Lanza N TurtleBot3 Burger en Gazebo Fortress con la MISMA convención que los reales.

Por cada robot tb3_i:
  Tópicos ROS:  /tb3_i/cmd_vel  /tb3_i/odom  /tb3_i/scan  /tb3_i/imu  /tb3_i/joint_states
                /tb3_i/ground_truth   (solo simulación: pose real en el marco 'map')
  Frames TF:    map -> tb3_i/odom -> tb3_i/base_footprint -> tb3_i/base_link -> ...
                (map -> tb3_i/odom es estático, igual a la pose inicial del robot)

Ejemplos:
  ros2 launch turtlebot3_gz_bringup multi_robot.launch.py
  ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=4 world:=arena layout:=grid
  ros2 launch turtlebot3_gz_bringup multi_robot.launch.py poses:="0,0,0; 1,0,1.57" num_robots:=2
  ros2 launch turtlebot3_gz_bringup multi_robot.launch.py gui:=false rviz:=true   # Gazebo sin ventana
"""
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, ExecuteProcess, OpaqueFunction, TimerAction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

from turtlebot3_gz_bringup import sim_utils


def _true(value):
    return str(value).lower() in ('true', '1', 'yes', 'si', 'sí')


def launch_setup(context, *args, **kwargs):
    pkg = get_package_share_directory('turtlebot3_gz_bringup')

    # --- Argumentos (se leen aquí, en tiempo de ejecución) ---------------------
    n = int(LaunchConfiguration('num_robots').perform(context))
    world = LaunchConfiguration('world').perform(context)
    layout = LaunchConfiguration('layout').perform(context)
    spacing = float(LaunchConfiguration('spacing').perform(context))
    poses_arg = LaunchConfiguration('poses').perform(context)
    gui = _true(LaunchConfiguration('gui').perform(context))
    rviz = _true(LaunchConfiguration('rviz').perform(context))
    follow = _true(LaunchConfiguration('follower_demo').perform(context))

    world_file = world if world.endswith('.sdf') else os.path.join(pkg, 'worlds', world + '.sdf')
    wname = sim_utils.world_name(world_file)
    names = sim_utils.robot_names(n)
    poses = sim_utils.robot_poses(n, layout, spacing, poses_arg)
    urdf = sim_utils.robot_urdf()

    actions = []

    # --- Gazebo ------------------------------------------------------------------
    # '-r' arranca la simulación; '-s' solo servidor (sin ventana).
    # En WSL el envoltorio de 'ign' añade '--render-engine ogre' automáticamente.
    gz_cmd = ['ign', 'gazebo', '-r', world_file] if gui else ['ign', 'gazebo', '-r', '-s', world_file]
    actions.append(ExecuteProcess(cmd=gz_cmd, output='screen', name='gazebo'))

    # Reloj de simulación (uno para todos)
    actions.append(Node(
        package='ros_gz_bridge', executable='parameter_bridge', name='bridge_clock',
        arguments=['/clock@rosgraph_msgs/msg/Clock[ignition.msgs.Clock'],
        output='screen'))

    # --- Robots ------------------------------------------------------------------
    for ns, (x, y, yaw) in zip(names, poses):
        # 1) Insertar el robot en Gazebo (SDF generado con su nombre y frames)
        spawn = Node(
            package='ros_gz_sim', executable='create', name=f'spawn_{ns}', output='screen',
            arguments=['-world', wname, '-name', ns, '-string', sim_utils.robot_sdf(ns),
                       '-x', str(x), '-y', str(y), '-z', '0.01', '-Y', str(yaw)])

        # 2) Puente Gazebo <-> ROS (tópicos con el mismo nombre que en el robot real)
        g = f'/model/{ns}'
        bridge = Node(
            package='ros_gz_bridge', executable='parameter_bridge', name=f'bridge_{ns}',
            output='screen',
            parameters=[{'use_sim_time': True}],
            arguments=[
                f'{g}/cmd_vel@geometry_msgs/msg/Twist]ignition.msgs.Twist',
                f'{g}/odometry@nav_msgs/msg/Odometry[ignition.msgs.Odometry',
                f'{g}/tf@tf2_msgs/msg/TFMessage[ignition.msgs.Pose_V',
                f'{g}/scan@sensor_msgs/msg/LaserScan[ignition.msgs.LaserScan',
                f'{g}/imu@sensor_msgs/msg/Imu[ignition.msgs.IMU',
                f'{g}/ground_truth@nav_msgs/msg/Odometry[ignition.msgs.Odometry',
                f'/world/{wname}/model/{ns}/joint_state@sensor_msgs/msg/JointState[ignition.msgs.Model',
            ],
            remappings=[
                (f'{g}/cmd_vel', f'/{ns}/cmd_vel'),
                (f'{g}/odometry', f'/{ns}/odom'),
                (f'{g}/tf', '/tf'),
                (f'{g}/scan', f'/{ns}/scan'),
                (f'{g}/imu', f'/{ns}/imu'),
                (f'{g}/ground_truth', f'/{ns}/ground_truth'),
                (f'/world/{wname}/model/{ns}/joint_state', f'/{ns}/joint_states'),
            ])

        # 3) Árbol de frames del robot con prefijo tb3_i/
        rsp = Node(
            package='robot_state_publisher', executable='robot_state_publisher',
            namespace=ns, name='robot_state_publisher', output='screen',
            parameters=[{'use_sim_time': True, 'robot_description': urdf,
                         'frame_prefix': f'{ns}/'}])

        # 4) Marco común: map -> tb3_i/odom = pose inicial del robot
        map_tf = Node(
            package='tf2_ros', executable='static_transform_publisher', name=f'map_to_{ns}_odom',
            arguments=['--x', str(x), '--y', str(y), '--z', '0', '--yaw', str(yaw),
                       '--pitch', '0', '--roll', '0',
                       '--frame-id', 'map', '--child-frame-id', f'{ns}/odom'])

        actions += [spawn, bridge, rsp, map_tf]

    # --- Demostración: todos replican los comandos de tb3_0 ------------------------
    if follow:
        for ns in names[1:]:
            actions.append(Node(
                package='turtlebot3_gz_bringup', executable='follower_node', namespace=ns,
                name='follower_node', output='screen',
                parameters=[{'master_namespace': names[0], 'use_sim_time': True}]))

    # --- RViz (se retrasa para que Gazebo arranque antes) --------------------------
    if rviz:
        actions.append(TimerAction(period=3.0, actions=[Node(
            package='rviz2', executable='rviz2', name='rviz2', output='log',
            arguments=['-d', sim_utils.rviz_config(names)],
            parameters=[{'use_sim_time': True}])]))

    return actions


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('num_robots', default_value='3', description='Número de robots'),
        DeclareLaunchArgument('world', default_value='empty',
                              description='empty | arena | ruta a un .sdf'),
        DeclareLaunchArgument('layout', default_value='line', description='line | grid | circle'),
        DeclareLaunchArgument('spacing', default_value='0.5', description='Separación (m)'),
        DeclareLaunchArgument('poses', default_value='',
                              description='Poses explícitas "x,y,yaw; x,y,yaw; ..."'),
        DeclareLaunchArgument('gui', default_value='true', description='Ventana de Gazebo'),
        DeclareLaunchArgument('rviz', default_value='true', description='Abrir RViz'),
        DeclareLaunchArgument('follower_demo', default_value='false',
                              description='Los robots 1..N-1 replican cmd_vel de tb3_0'),
        OpaqueFunction(function=launch_setup),
    ])
