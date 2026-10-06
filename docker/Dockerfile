# =============================================================================
#  Robótica Cooperativa — Imagen de la máquina de control
#  ROS 2 Humble (Ubuntu 22.04) + Gazebo Fortress + Nav2 + SLAM + TurtleBot3
# =============================================================================
FROM osrf/ros:humble-desktop

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# --- Herramientas básicas y repositorio de Gazebo (OSRF) ---------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget gnupg lsb-release ca-certificates \
    && curl -sSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/gazebo-stable.list \
    && rm -rf /var/lib/apt/lists/*

# --- Gazebo Fortress, ROS 2 y paquetes del curso ------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ignition-fortress \
        ros-humble-ros-gz \
        ros-humble-navigation2 ros-humble-nav2-bringup \
        ros-humble-slam-toolbox \
        ros-humble-cartographer ros-humble-cartographer-ros \
        ros-humble-turtlebot3 ros-humble-turtlebot3-msgs ros-humble-dynamixel-sdk \
        ros-humble-robot-localization \
        ros-humble-teleop-twist-keyboard \
        ros-humble-foxglove-bridge \
        ros-humble-rmw-cyclonedds-cpp \
        ros-humble-tf-transformations \
        ros-humble-xacro \
        python3-colcon-common-extensions python3-vcstool python3-rosdep python3-pip \
        python3-numpy python3-scipy python3-matplotlib \
        git sudo nano vim less bash-completion \
        iputils-ping iproute2 net-tools mesa-utils \
    && pip3 install --no-cache-dir "transforms3d>=0.4" \
    && rm -rf /var/lib/apt/lists/*

# --- Usuario sin privilegios con el mismo UID que el usuario de WSL ----------
#     (así los ficheros del workspace no quedan como propiedad de root)
RUN if ! getent group "$USER_GID" >/dev/null; then groupadd --gid "$USER_GID" "$USERNAME"; fi \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" \
    && echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME" \
    && usermod -aG video "$USERNAME"

# --- Variables del curso (se pueden sobrescribir desde .env / compose) --------
ENV TURTLEBOT3_MODEL=burger \
    LDS_MODEL=LDS-01 \
    ROS_DOMAIN_ID=30 \
    RMW_IMPLEMENTATION=rmw_fastrtps_cpp

COPY ros_bashrc.sh /etc/profile.d/ros_bashrc.sh
COPY entrypoint.sh /entrypoint.sh
COPY check_env.sh /usr/local/bin/check_env
COPY ign_wrapper.sh /usr/local/bin/ign
RUN chmod +x /entrypoint.sh /usr/local/bin/check_env /usr/local/bin/ign \
    && echo "source /etc/profile.d/ros_bashrc.sh" >> "/home/$USERNAME/.bashrc"

USER $USERNAME
WORKDIR /home/$USERNAME/ws
RUN rosdep update --rosdistro humble

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
