# F1tenth_PoliMI dev / car image. Built by docker-compose.yaml (build context = repo root).
#
# One image for all targets:
#   arm, x86  WITH_SIM=1  -> + f1tenth_gym (pip); the bridge and polimi_sim build in the workspace
#   jet       WITH_SIM=0  -> drivers and autonomy only, no simulator on the car
#
# ros2_ws/src is bind-mounted at run time; it is copied here only so rosdep can
# read the package.xml files. Rebuild the image when a package.xml changes.
ARG ROS_DISTRO=jazzy
FROM ros:${ROS_DISTRO}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
        sudo git tmux nano less wget jq net-tools joystick \
        python3-pip python3-dev python3-colcon-common-extensions python3-colcon-clean \
        libasio-dev \
        ros-${ROS_DISTRO}-rmw-zenoh-cpp \
        ros-${ROS_DISTRO}-ackermann-msgs \
        ros-${ROS_DISTRO}-asio-cmake-module \
        ros-${ROS_DISTRO}-tf-transformations \
        ros-${ROS_DISTRO}-tf2-tools \
        ros-${ROS_DISTRO}-xacro \
        ros-${ROS_DISTRO}-robot-state-publisher \
        ros-${ROS_DISTRO}-slam-toolbox \
        ros-${ROS_DISTRO}-nav2-amcl \
        ros-${ROS_DISTRO}-robot-localization \
        ros-${ROS_DISTRO}-image-transport-plugins \
        ros-${ROS_DISTRO}-cv-bridge \
        ros-${ROS_DISTRO}-nav2-map-server \
        ros-${ROS_DISTRO}-nav2-lifecycle-manager \
        ros-${ROS_DISTRO}-foxglove-bridge \
        ros-${ROS_DISTRO}-rviz2

# Simulator: f1tenth_gym (Python, JAX on the CPU). The bridge (f1tenth_gym_ros, our
# fork) is a submodule and builds in the workspace.
# pip quirks copied from upstream gym_ros: a fresh pip is needed for the gym's
# build backend. Pins, if ever needed, go in /tmp/pip-constraints.txt.
ARG WITH_SIM=1
# Pinned upstream commit (dev-jax). Bump on purpose, never follow the branch.
ARG GYM_REF=ec3b1a4693ed20317e42e57a9454d94b824cec81
ENV JAX_PLATFORMS=cpu
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ "${WITH_SIM}" = "1" ]; then \
        pip3 install --ignore-installed pip \
        && touch /tmp/pip-constraints.txt \
        && git clone https://github.com/f1tenth/f1tenth_gym.git /opt/f1tenth_gym \
        && git -C /opt/f1tenth_gym checkout -q ${GYM_REF} \
        && pip3 install --ignore-installed -c /tmp/pip-constraints.txt /opt/f1tenth_gym; \
    fi

# Non-root user matching the host's UID/GID, so files in bind mounts stay yours.
ARG USER
ARG UID
ARG GID
RUN if id -u ubuntu >/dev/null 2>&1; then userdel -r ubuntu; fi \
    && (getent group ${GID} || groupadd -g ${GID} ${USER}) \
    && useradd -m -s /bin/bash -u ${UID} -g ${GID} -G sudo,dialout,plugdev ${USER} \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER}

# System deps of everything in ros2_ws/src. Kept last: any change under
# ros2_ws/src re-runs this step, and nothing expensive should sit after it.
# f1tenth_stack depends on drivers we don't use (Hokuyo, SICK, rosbridge).
ARG ROSDEP_SKIP="urg_node sick_scan_xd rosbridge_server"
COPY ros2_ws/src /tmp/src
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ "${WITH_SIM}" = "1" ]; then sim=/tmp/src/f1tenth_gym_ros/polimi_sim; else rm -rf /tmp/src/f1tenth_gym_ros; sim=; fi \
    && apt-get update \
    && (rosdep init 2>/dev/null || true) && rosdep update --rosdistro ${ROS_DISTRO} \
    && rosdep install --from-paths /tmp/src ${sim} --ignore-src --rosdistro ${ROS_DISTRO} -y \
        --skip-keys "${ROSDEP_SKIP}" \
    && rm -rf /tmp/src

# build/install/log are named volumes: a new, empty volume takes the ownership
# of the image directory it is mounted on, so these must exist and be the user's.
RUN mkdir -p /home/${USER}/ws/build /home/${USER}/ws/install /home/${USER}/ws/log \
    && chown -R ${UID}:${GID} /home/${USER}/ws

COPY docker/ros/bashrc_polimi /etc/bashrc_polimi
RUN echo "source /etc/bashrc_polimi" >> /home/${USER}/.bashrc

USER ${USER}
WORKDIR /home/${USER}/ws
CMD ["/bin/bash"]
