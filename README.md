# Robótica Cooperativa — entorno de prácticas (ROS 2 Humble)

Entorno para las prácticas con TurtleBot3 Burger: **Windows → WSL2 → Docker → Ubuntu 22.04 + ROS 2 Humble
+ Gazebo Fortress**. Todo lo necesario (ROS, simulador, Nav2, paquetes TurtleBot3) va dentro de una imagen
ya preparada: no hay que instalar ROS a mano.

> **Sesión 0 (antes de la primera clase):** sigue los pasos 1–6 y entrega el informe del paso 6.
> Tiempo estimado: 1 h, la mayor parte esperando descargas.

## Requisitos

| | Recomendado | Mínimo |
|---|---|---|
| Sistema | Windows 11 22H2 o posterior | Windows 10 21H2 (solo simulación; robots con ayuda del profesor) |
| RAM | 16 GB | 8 GB (Gazebo con 2 robots) |
| Disco libre | 40 GB | 25 GB |
| Otros | Permisos de administrador; virtualización activada | |

Comprueba la virtualización en *Administrador de tareas → Rendimiento → CPU → Virtualización: Habilitado*.
Si pone *Deshabilitado*, actívala en la BIOS (Intel VT-x / AMD SVM).

¿Linux nativo o Mac? Ver [otros sistemas](#otros-sistemas).

## 1. Descargar este repositorio en Windows

Botón **Code → Download ZIP** en GitHub (o el .zip del campus virtual) y descomprímelo, por ejemplo en
`C:\robcoop`. Solo se usa para el paso 2; después se trabaja con una copia dentro de Linux.

## 2. Preparar Windows (PowerShell como administrador)

Clic derecho en Inicio → *Terminal (Administrador)*:

Si es la primera vez que usas WSL en ese ordenador, ejecuta primero `wsl --install --no-distribution`,
**reinicia** Windows y vuelve a abrir la PowerShell de administrador.


```powershell
cd C:\robcoop\robcoop-docker-main\windows
Set-ExecutionPolicy -Scope Process Bypass
.\setup_windows.ps1 -InstallDistro
```

- Activa la red de WSL en modo espejo, abre en el firewall los puertos de ROS 2 e instala una distro
  Linux dedicada llamada **`U24.04_Docker_ROS2`**.
- Te pedirá un **usuario y contraseña de Linux**: apúntalos (la contraseña se pide con `sudo`).
- Al terminar quedas dentro de Linux: escribe `exit`.

Después, en la misma PowerShell:

```powershell
wsl --shutdown
wsl -l -v
```

Debe aparecer `U24.04_Docker_ROS2`, versión 2.

**¿Ya usas WSL para otra asignatura?** No se toca tu distro: se crea otra aparte. El modo de red
espejo sí es global (afecta a todas), pero no rompe el uso habitual; el script guarda una copia de tu
`.wslconfig`.

## 3. Instalar Docker dentro de la distro

```powershell
wsl -d U24.04_Docker_ROS2
```

Ya en Linux (a partir de aquí, todo en esta terminal):

```bash
cd ~
git clone https://github.com/raulmack/robcoop-docker.git
cd robcoop-docker
bash wsl/install_docker.sh
```

Si el script pide reiniciar la distro o te añade al grupo `docker`: escribe `exit`, vuelve a entrar con
`wsl -d U24.04_Docker_ROS2` y repite `cd ~/robcoop-docker && bash wsl/install_docker.sh`.

> Trabaja siempre en `~/robcoop-docker` (dentro de Linux), **no** en `/mnt/c/...` ni en OneDrive:
> compilar ahí es muy lento.

## 4. Descargar la imagen y comprobar el entorno

```bash
./robcoop.sh pull      # ~6-8 GB, solo la primera vez
./robcoop.sh check
```

En `check` deben salir en verde: el renderer (`D3D12 (...)` = GPU), tu IP de la red local y
*Publicar/suscribir funciona*. Un aviso amarillo de *Render por CPU* no impide trabajar.

## 5. Probar la simulación

```bash
./robcoop.sh shell                 # terminal dentro del contenedor
cb                                 # compila el workspace
ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=3 world:=arena
```

Se abren Gazebo y RViz con 3 robots. En **otra** terminal de Linux:

```bash
cd ~/robcoop-docker && ./robcoop.sh shell
ros2 run turtlebot3_teleop teleop_keyboard --ros-args -r __ns:=/tb3_0
```

Mueve `tb3_0` con `w a s d x` y haz una **captura de pantalla de RViz** con el robot desplazado.
Para todo con `Ctrl+C`.

## 6. Generar y entregar el informe de la Sesión 0

En una terminal de Linux (fuera del contenedor):

```bash
cd ~/robcoop-docker
./robcoop.sh s0
```

Tarda unos 2 minutos: guarda la comprobación del entorno y una prueba de simulación sin ventanas en
`informe_s0_<usuario>.txt`. **Entrega ese fichero y la captura del paso 5** en el campus virtual.

Para abrir la carpeta desde Windows: en el Explorador, `\\wsl$\U24.04_Docker_ROS2\home\<usuario>\robcoop-docker`.

---

## Uso diario

```bash
wsl -d U24.04_Docker_ROS2
cd ~/robcoop-docker
./robcoop.sh shell        # una terminal dentro del contenedor (repetir para más)
./robcoop.sh down         # al terminar
./robcoop.sh update       # cuando el profesor publique cambios
```

| Dentro del contenedor | Qué hace |
|---|---|
| `cb` | Compila el workspace (`colcon build --symlink-install`) y lo carga |
| `cbp <paquete>` | Compila solo ese paquete |
| `ros2 launch turtlebot3_gz_bringup multi_robot.launch.py num_robots:=4` | Simulación con 4 robots |
| `... gui:=false` | Sin ventana de Gazebo (más ligero; RViz sigue abierto) |

**Dónde va vuestro código:** en `ws/src/`. Lo que hay ahí se conserva aunque se borre el contenedor.
El repositorio de la pareja se clona en `ws/src/` en la primera sesión.

**VS Code:** instala la extensión *WSL*, abre la carpeta con `code .` desde la distro y, si quieres
editar dentro del contenedor, la extensión *Dev Containers* → *Reopen in Container*.

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `setup_windows.ps1` no se ejecuta | PowerShell **como administrador** y `Set-ExecutionPolicy -Scope Process Bypass` antes |
| `wsl --install ... --name` falla | `wsl --update` y repetir el paso 2 |
| `permission denied ... docker.sock` | `exit` y volver a entrar en la distro (grupo `docker`) |
| Gazebo se abre y se cierra solo | Ver `.env`: alternativa `ROBCOOP_RENDER_ENGINE=` y `LIBGL_ALWAYS_SOFTWARE=1`, luego `./robcoop.sh down` |
| Gazebo va a tirones | Normal en WSL; usa `gui:=false` y trabaja en RViz |
| `check` no muestra la IP de tu red | Falta `wsl --shutdown` tras el paso 2, o tu Windows no admite red espejo (Windows 10) |
| Muy lento compilando | Estás en `/mnt/c`: trabaja en `~/robcoop-docker` |

Si sigue sin funcionar, envía al profesor la salida de `./robcoop.sh check`.

## Otros sistemas

- **Windows 10:** los pasos son los mismos; el script detecta que no hay red espejo. La simulación
  funciona igual. Para los robots reales se usará un puente (Zenoh) que configura el profesor.
- **Linux nativo (Ubuntu 22.04/24.04):** instala Docker Engine, clona el repositorio, y en `.env` pon
  `COMPOSE_FILE=compose.yaml:compose.linux.yaml`; ejecuta `xhost +local:docker` y sigue desde el paso 4.
- **Mac:** consulta al profesor antes de la Sesión 0.

## Contenido del repositorio

```
robcoop-docker/
├── robcoop.sh                  atajos: pull | shell | check | s0 | update | down
├── windows/setup_windows.ps1   preparación de Windows (paso 2)
├── wsl/install_docker.sh       Docker dentro de la distro (paso 3)
├── docker/                     receta de la imagen (Dockerfile, check_env…)
├── compose*.yaml, .env.example cómo se arranca el contenedor
├── ws/src/turtlebot3_gz_bringup  simulación multirrobot (Gazebo + RViz)
├── robot/                      arranque de los robots reales (profesor)
└── docs/PROFESOR.md            publicación, robots reales, Zenoh
```
