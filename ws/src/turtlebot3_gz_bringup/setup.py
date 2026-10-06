import os
from glob import glob

from setuptools import setup

package_name = 'turtlebot3_gz_bringup'

setup(
    name=package_name,
    version='0.2.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
        (os.path.join('share', package_name, 'worlds'), glob('worlds/*.sdf')),
        (os.path.join('share', package_name, 'models', 'tb3_burger'),
         glob('models/tb3_burger/*')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Raúl Fernández',
    maintainer_email='raul.fernandez@uclm.es',
    description='Simulación multirrobot de TurtleBot3 Burger en Gazebo Fortress (Robótica Cooperativa).',
    license='Apache-2.0',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'follower_node = turtlebot3_gz_bringup.follower_node:main',
        ],
    },
)
