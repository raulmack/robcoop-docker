# Notas del profesor

## Publicación (una vez por curso)

1. **Repositorio en GitHub** `raulmack/robcoop-docker` (público), desde la distro WSL:

   ```bash
   cd ~/robcoop-docker
   git init -b main && git add -A && git commit -m "Entorno de prácticas 2026-27"
   git remote add origin https://github.com/raulmack/robcoop-docker.git
   git push -u origin main
   ```

   Para autenticarse en `git push`, un token personal (*Settings → Developer settings → Personal access
   tokens*, permiso `repo`) como contraseña, o `gh auth login` si está instalado.

2. **Imagen en GHCR:** el push de `docker/` lanza la acción *Imagen Docker* (pestaña *Actions*; también
   a mano con *Run workflow*). Tarda ~30 min. Al terminar:
   *perfil → Packages → robcoop → Package settings → Change visibility → Public*.
   Comprobar desde otra máquina: `docker pull ghcr.io/raulmack/robcoop:humble`.

3. **Zip para el campus virtual:** `git archive --format=zip -o robcoop-docker.zip --prefix=robcoop-docker-main/ main`
   (mismo nombre de carpeta que la descarga de GitHub, así sirve la misma guía).

La imagen se construye con UID/GID 1000 (el primer usuario de WSL). Si un alumno tiene otro UID,
`./robcoop.sh build` en su equipo (20–40 min).

## Robots reales

Los robots los comparten otros grupos: **no** se modifica su software. Todo se lanza desde el PC.

```bash
robot/diagnose_robot.sh                    # (en el robot) informe de solo lectura
robot/robot_up.sh <IP> tb3_<N>             # (desde la distro) copia ~/robcoop/robcoop_robot.launch.py y lo lanza
robot/robot_up.sh <IP> tb3_<N> --set-time  # si el router no tiene Internet
```

En el contenedor: `ros2 launch turtlebot3_gz_bringup rviz_robots.launch.py robots:=tb3_0,tb3_1`.

- Convención idéntica a la simulación: `/tb3_N/{cmd_vel,odom,scan,imu,joint_states}`, TF `tb3_N/...`.
- Software de los robots (humble-devel 2022): IMU con frame `imu_link` sin prefijo; LDS-02 con frame fijo.
- Reloj: los robots no tienen RTC; con el router conectado a Internet se sincronizan solos (timesyncd).
  `robot_up.sh` avisa si el desfase con el PC supera 0.5 s.

## Windows 10 y Zenoh

Windows 10 no admite la red espejo de WSL: DDS no llega del robot al PC. Alternativa: puente
`zenoh-bridge-ros2dds` en cada robot y `./robcoop.sh zenoh` en el PC (`ZENOH_ARGS` en `.env`).
**Pendiente:** instalarlo en las Raspberry Pi (el .deb de Eclipse exige glibc 2.38; Ubuntu 22.04 tiene 2.35)
y fijar la misma versión (`ZENOH_VERSION`) en PC y robots.

## Construir la imagen en local

`ROBCOOP_IMAGE=robcoop:humble` en `.env` y `./robcoop.sh build`. Detalles técnicos de la imagen:

- Gazebo con `--render-engine ogre`: en WSL la GPU llega por D3D12 con OpenGL 4.2 y ogre2 necesita 4.3.
  El envoltorio `/usr/local/bin/ign` lo añade (`ROBCOOP_RENDER_ENGINE`).
- `network_mode: host` + `ipc: host` (memoria compartida de Fast DDS).
- Zenoh no va en la imagen: servicio aparte con la imagen oficial de Eclipse.
