"""Utilidades para lanzar varios TurtleBot3 en Gazebo Fortress.

- Calcula las poses iniciales de los robots.
- Genera el SDF de cada robot a partir de la plantilla (nombre y frames propios).
- Genera una configuración de RViz con un RobotModel y un LaserScan por robot.
"""
import math
import os
import re
import tempfile

from ament_index_python.packages import get_package_share_directory

# Colores RGB (0-255) para distinguir los robots en RViz
COLORS = [(230, 25, 75), (60, 180, 75), (0, 130, 200), (245, 130, 48),
          (145, 30, 180), (70, 240, 240), (240, 50, 230), (128, 128, 0)]


def robot_names(num_robots, prefix='tb3_'):
    """Lista de nombres/namespaces: tb3_0, tb3_1, ..."""
    return [f'{prefix}{i}' for i in range(num_robots)]


def robot_poses(num_robots, layout='line', spacing=0.5, poses=''):
    """Devuelve [(x, y, yaw), ...].

    poses: cadena 'x,y,yaw; x,y,yaw; ...' que, si se da, tiene prioridad.
    layout: 'line' (en fila sobre el eje y), 'grid' o 'circle'.
    """
    if poses.strip():
        result = []
        for item in poses.split(';'):
            if item.strip():
                vals = [float(v) for v in item.split(',')]
                vals += [0.0] * (3 - len(vals))
                result.append(tuple(vals[:3]))
        if len(result) < num_robots:
            raise ValueError(f'Se han dado {len(result)} poses para {num_robots} robots')
        return result[:num_robots]

    n = num_robots
    if layout == 'grid':
        cols = math.ceil(math.sqrt(n))
        rows = math.ceil(n / cols)
        return [((i // cols - (rows - 1) / 2) * spacing,
                 (i % cols - (cols - 1) / 2) * spacing, 0.0) for i in range(n)]
    if layout == 'circle':
        radius = max(spacing, spacing * n / (2 * math.pi))
        result = []
        for i in range(n):
            x = radius * math.cos(2 * math.pi * i / n)
            y = radius * math.sin(2 * math.pi * i / n)
            result.append((x, y, math.atan2(-y, -x)))   # mirando al centro
        return result
    # 'line'
    return [(0.0, (i - (n - 1) / 2) * spacing, 0.0) for i in range(n)]


def world_name(world_file):
    """Lee el atributo name de <world> (hace falta para spawn y para los puentes)."""
    with open(world_file, 'r') as f:
        m = re.search(r'<world\s+name\s*=\s*["\']([^"\']+)["\']', f.read())
    if not m:
        raise RuntimeError(f'No se encuentra <world name=...> en {world_file}')
    return m.group(1)


def robot_sdf(ns):
    """SDF del robot 'ns' a partir de la plantilla models/tb3_burger/model.sdf.in."""
    pkg = get_package_share_directory('turtlebot3_gz_bringup')
    meshes = os.path.join(get_package_share_directory('turtlebot3_description'), 'meshes')
    with open(os.path.join(pkg, 'models', 'tb3_burger', 'model.sdf.in'), 'r') as f:
        sdf = f.read()
    return sdf.replace('@NS@', ns).replace('@MESHES@', meshes)


def robot_urdf():
    """URDF del Burger (procesado con xacro por si la versión instalada lo requiere)."""
    model = os.environ.get('TURTLEBOT3_MODEL', 'burger')
    path = os.path.join(get_package_share_directory('turtlebot3_description'),
                        'urdf', f'turtlebot3_{model}.urdf')
    try:
        import xacro
        return xacro.process_file(path).toxml()
    except Exception:  # URDF plano
        with open(path, 'r') as f:
            return f.read()


def rviz_config(names, fixed_frame='map'):
    """Escribe un .rviz temporal con TF + RobotModel + LaserScan por robot."""
    displays = [
        '    - Class: rviz_default_plugins/Grid\n'
        '      Name: Grid\n'
        '      Enabled: true\n'
        '      Cell Size: 0.5\n'
        '      Plane Cell Count: 20\n'
        f'      Reference Frame: {fixed_frame}\n',
        '    - Class: rviz_default_plugins/TF\n'
        '      Name: TF\n'
        '      Enabled: true\n'
        '      Show Names: false\n'
        '      Marker Scale: 0.3\n',
    ]
    for i, ns in enumerate(names):
        r, g, b = COLORS[i % len(COLORS)]
        displays.append(
            '    - Class: rviz_default_plugins/RobotModel\n'
            f'      Name: {ns} modelo\n'
            '      Enabled: true\n'
            '      Description Source: Topic\n'
            f'      TF Prefix: {ns}\n'   # URDF sin prefijo, TF con prefijo tb3_i/
            '      Description Topic:\n'
            f'        Value: /{ns}/robot_description\n'
            '        Depth: 5\n'
            '        Durability Policy: Transient Local\n'
            '        Reliability Policy: Reliable\n'
            '        History Policy: Keep Last\n')
        displays.append(
            '    - Class: rviz_default_plugins/LaserScan\n'
            f'      Name: {ns} scan\n'
            '      Enabled: true\n'
            '      Topic:\n'
            f'        Value: /{ns}/scan\n'
            '        Depth: 5\n'
            '        Durability Policy: Volatile\n'
            '        Reliability Policy: Best Effort\n'
            '        History Policy: Keep Last\n'
            '      Style: Points\n'
            '      Size (Pixels): 4\n'
            '      Color Transformer: FlatColor\n'
            f'      Color: {r}; {g}; {b}\n')
    text = (
        'Panels:\n'
        '  - Class: rviz_common/Displays\n'
        '    Name: Displays\n'
        'Visualization Manager:\n'
        '  Class: ""\n'
        '  Displays:\n' + ''.join(displays) +
        '  Enabled: true\n'
        '  Global Options:\n'
        f'    Fixed Frame: {fixed_frame}\n'
        '    Background Color: 48; 48; 48\n'
        '    Frame Rate: 30\n'
        '  Tools:\n'
        '    - Class: rviz_default_plugins/MoveCamera\n'
        '    - Class: rviz_default_plugins/Select\n'
        '    - Class: rviz_default_plugins/SetGoal\n'
        '      Topic:\n'
        '        Value: /goal_pose\n'
        '    - Class: rviz_default_plugins/PublishPoint\n'
        '      Topic:\n'
        '        Value: /clicked_point\n'
        '  Views:\n'
        '    Current:\n'
        '      Class: rviz_default_plugins/TopDownOrtho\n'
        '      Scale: 120\n'
        '      X: 0\n'
        '      Y: 0\n'
        f'      Target Frame: {fixed_frame}\n'
        'Window Geometry:\n'
        '  Height: 900\n'
        '  Width: 1400\n')
    f = tempfile.NamedTemporaryFile('w', suffix='_robcoop.rviz', delete=False)
    f.write(text)
    f.close()
    return f.name
