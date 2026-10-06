#!/usr/bin/env python3
"""Bringup de un TurtleBot3 REAL con namespace, SIN modificar el software del robot.

Se copia a ~/robcoop/ en la Raspberry y se lanza por ruta (no hace falta compilar):
    ros2 launch ~/robcoop/robcoop_robot.launch.py ns:=tb3_0

Mismos tópicos y frames que la simulación (turtlebot3_gz_bringup):
    /tb3_0/cmd_vel  /tb3_0/odom  /tb3_0/scan  /tb3_0/imu  /tb3_0/joint_states ...
    TF: tb3_0/odom -> tb3_0/base_footprint -> tb3_0/base_link -> tb3_0/base_scan ...

Funciona con el turtlebot3 de ROBOTIS (humble-devel) aunque su robot.launch.py no admita
namespace: los frames se fijan aquí por parámetros (odometría, LiDAR y robot_state_publisher).
Limitaciones conocidas en versiones antiguas del software del robot:
  - IMU: su frame sigue siendo 'imu_link' (sin prefijo).
  - LDS-02 (ld08_driver antiguo): el frame 'base_scan' está fijo en el código (sin prefijo).
"""
import os
import tempfile

import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, LogInfo, OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def _urdf(model):
    path = os.path.join(get_package_share_directory('turtlebot3_description'),
                        'urdf', f'turtlebot3_{model}.urdf')
    try:
        import xacro
        return xacro.process_file(path).toxml()
    except Exception:
        with open(path, 'r') as f:
            return f.read()


def _tb3_params(ns, model):
    """Copia los parámetros de ROBOTIS con las claves del nodo con namespace y frames con prefijo."""
    share = get_package_share_directory('turtlebot3_bringup')
    candidates = [os.path.join(share, 'param', 'humble', f'{model}.yaml'),
                  os.path.join(share, 'param', f'{model}.yaml')]
    src = next(p for p in candidates if os.path.exists(p))
    with open(src, 'r') as f:
        params = yaml.safe_load(f)

    out = {f'/{ns}/{node}': body for node, body in params.items()}
    ddc = out.setdefault(f'/{ns}/diff_drive_controller', {'ros__parameters': {}})
    odom = ddc['ros__parameters'].setdefault('odometry', {})
    odom['frame_id'] = f'{ns}/odom'
    odom['child_frame_id'] = f'{ns}/base_footprint'

    tmp = tempfile.NamedTemporaryFile('w', suffix=f'_{ns}_tb3.yaml', delete=False)
    yaml.safe_dump(out, tmp)
    tmp.close()
    return src, tmp.name


def setup(context, *args, **kwargs):
    ns = LaunchConfiguration('ns').perform(context).strip('/')
    lds = LaunchConfiguration('lds').perform(context)
    usb_port = LaunchConfiguration('usb_port').perform(context)
    lidar_port = LaunchConfiguration('lidar_port').perform(context)
    model = os.environ.get('TURTLEBOT3_MODEL', 'burger')

    src, params_file = _tb3_params(ns, model)
    actions = [LogInfo(msg=f'[robcoop] {ns}: modelo={model} lidar={lds} '
                           f'ROS_DOMAIN_ID={os.environ.get("ROS_DOMAIN_ID", "0")} '
                           f'parametros={src}')]

    # Árbol de frames del robot con prefijo ns/
    actions.append(Node(
        package='robot_state_publisher', executable='robot_state_publisher',
        namespace=ns, output='screen',
        parameters=[{'robot_description': _urdf(model), 'frame_prefix': f'{ns}/'}]))

    # LiDAR
    if lds == 'LDS-02':
        actions.append(LogInfo(msg='[robcoop] AVISO: ld08_driver antiguo publica frame "base_scan" '
                                   'sin prefijo'))
        actions.append(Node(package='ld08_driver', executable='ld08_driver',
                            namespace=ns, output='screen'))
    else:
        actions.append(Node(
            package='hls_lfcd_lds_driver', executable='hlds_laser_publisher',
            name='hlds_laser_publisher', namespace=ns, output='screen',
            parameters=[{'port': lidar_port, 'frame_id': f'{ns}/base_scan'}]))

    # Motores, odometría, IMU, batería (OpenCR). Sin 'name': el proceso crea dos nodos
    # (turtlebot3_node y diff_drive_controller) y ambos reciben el namespace.
    actions.append(Node(
        package='turtlebot3_node', executable='turtlebot3_ros',
        namespace=ns, output='screen',
        parameters=[params_file],
        arguments=['-i', usb_port]))
    return actions


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('ns', default_value='tb3_0', description='Namespace del robot'),
        DeclareLaunchArgument('lds', default_value=os.environ.get('LDS_MODEL', 'LDS-01'),
                              description='LDS-01 | LDS-02'),
        DeclareLaunchArgument('usb_port', default_value='/dev/ttyACM0', description='OpenCR'),
        DeclareLaunchArgument('lidar_port', default_value='/dev/ttyUSB0', description='LiDAR'),
        OpaqueFunction(function=setup),
    ])
