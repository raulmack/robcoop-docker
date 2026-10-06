#!/usr/bin/env python3
"""
Nodo Follower: replica los movimientos del robot master (por defecto tb3_0).
Cada robot esclavo ejecuta una instancia en su namespace (tb3_1, tb3_2...).
"""
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist


class FollowerNode(Node):
    """
    Nodo que suscribe a los comandos de velocidad del master
    y los replica para el robot follower.
    """

    def __init__(self):
        super().__init__('follower_node')

        # Declarar parámetros
        self.declare_parameter('master_namespace', 'tb3_0')
        # NO declarar use_sim_time - ya lo declara ROS 2 automáticamente

        # Obtener parámetros
        self.master_ns = self.get_parameter('master_namespace').value

        # Suscriptor al cmd_vel del master
        master_topic = f'/{self.master_ns}/cmd_vel'
        self.subscription = self.create_subscription(
            Twist,
            master_topic,
            self.cmd_vel_callback,
            10
        )

        # Publicador al cmd_vel propio (relativo al namespace actual)
        self.publisher = self.create_publisher(
            Twist,
            'cmd_vel',
            10
        )

        self.get_logger().info(f'Follower iniciado. Siguiendo a: {master_topic}')
        self.get_logger().info(f'Publicando en: {self.get_namespace()}/cmd_vel')

    def cmd_vel_callback(self, msg):
        """
        Callback que recibe comandos del master y los replica.
        """
        # Replicar exactamente el mensaje recibido
        self.publisher.publish(msg)

        # Log opcional (comentar para reducir spam)
        # self.get_logger().debug(
        #     f'Replicando: linear.x={msg.linear.x:.2f}, angular.z={msg.angular.z:.2f}'
        # )


def main(args=None):
    rclpy.init(args=args)

    follower = FollowerNode()

    try:
        rclpy.spin(follower)
    except KeyboardInterrupt:
        pass
    finally:
        follower.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
