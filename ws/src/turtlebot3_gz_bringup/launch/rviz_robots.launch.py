#!/usr/bin/env python3
"""RViz para robots REALES (o cualquier conjunto de namespaces).

    ros2 launch turtlebot3_gz_bringup rviz_robots.launch.py robots:=tb3_0
    ros2 launch turtlebot3_gz_bringup rviz_robots.launch.py robots:=tb3_0,tb3_1 fixed_frame:=map

Con un solo robot real y sin mapa, el marco fijo por defecto es '<primer robot>/odom'.
"""
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node

from turtlebot3_gz_bringup import sim_utils


def setup(context, *args, **kwargs):
    names = [n.strip().strip('/') for n in
             LaunchConfiguration('robots').perform(context).split(',') if n.strip()]
    fixed = LaunchConfiguration('fixed_frame').perform(context) or f'{names[0]}/odom'
    return [Node(package='rviz2', executable='rviz2', name='rviz2', output='log',
                 arguments=['-d', sim_utils.rviz_config(names, fixed_frame=fixed)])]


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('robots', default_value='tb3_0',
                              description='Namespaces separados por comas'),
        DeclareLaunchArgument('fixed_frame', default_value='',
                              description='Marco fijo (por defecto <primer robot>/odom)'),
        OpaqueFunction(function=setup),
    ])
