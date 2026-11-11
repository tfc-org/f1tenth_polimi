# Docker

One image, built per machine type, holds ROS 2, the drivers' dependencies and (off the car) the simulator. The repo's code and configs are mounted into it, so you edit on the host and run in the container.

## Services

Pick the service for your machine. `arm` is used in the examples; replace it with `x86` on a PC.

| Service | Use | Simulator | Networking |
|---|---|---|---|
| `arm` | Apple Silicon Mac | yes | ports: `8765` (Foxglove) |
| `x86` | Linux / Windows PC | yes | ports: `8765` (Foxglove) |
| `jet` | Orin Nano on the car | no | host |
| `novnc` | Optional browser display for RViz (profile `gui`) | – | port `8080` |

- One image per target, built from `docker/ros/Dockerfile` on `ros:jazzy` (Ubuntu 24.04, Python 3.12). The distro is the build argument `ROS_DISTRO`; images are tagged `f1tenth_polimi:jazzy_<service>`.
- The container user gets the host's UID and GID (`HOST_UID`, `HOST_GID`). The base image's own `ubuntu` user (UID 1000) is removed first, so a host UID of 1000 (usual on the Jetson and on Linux PCs) works too.
- Bind mounts: `ros2_ws/src`, `ros2_ws/config`, `ros2_ws/maps`, `ros2_ws/runs` (the simulator's lap CSVs), `docker/ros/bashrc_polimi` (read-only, over the copy baked into the image), and `docker/ros/python3-ros` (read-only, see [PyCharm interpreter](#pycharm-interpreter)).
- `build/`, `install/`, `log/` live in Docker volumes named after the distro (`build_jazzy_arm`, …), not in the repo: build output stays out of git and is kept between container restarts.
- Ports bind to `127.0.0.1` only.

## Everyday commands

The container runs in the background; you open as many shells into it as you need.

```bash
docker compose up -d arm                   # start
docker compose exec arm bash               # shell (repeat per terminal)
docker compose ps                          # what is running
docker compose logs -f arm                 # container output
docker compose exec arm cat /tmp/zenohd.log   # zenoh router log
docker compose restart arm                 # restart (e.g. zenoh router died)
docker compose down                        # stop and remove containers
```

Inside the container:

```bash
cb [colcon args]                           # colcon build --symlink-install + source, e.g. cb --packages-select f1tenth_stack
sauce                                      # re-source ROS + workspace
simcar [map] [launch args]                 # simulator as the car, see simulator.md (arm / x86)
```

`cb` and `sauce` are shell functions, so they also work from a non-interactive shell:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && cb"
```

### Volume ownership

Only matters if `cb` fails with a permission error.

- The image creates `~/ws/build`, `~/ws/install`, `~/ws/log` owned by the user; a **new** volume inherits that.
- Volumes created by an older image stay root-owned and `cb` fails with `PermissionError … log/build_…`. Fix once, either way:

```bash
docker compose exec -u root arm bash -c 'chown -R $USER: /home/$USER/ws/{build,install,log}'
docker compose down -v && docker compose up -d arm   # or: recreate the volumes
```

## Rebuild

What to do after a change, from cheapest to most expensive:

| You change | You do |
|---|---|
| Code in `ros2_ws/src` | `cb` in the container |
| `ros2_ws/config`, `ros2_ws/maps` | nothing |
| `docker/ros/bashrc_polimi` | open a new shell (`docker compose exec arm bash`). After a branch switch that replaces it (`/etc/bashrc_polimi: No such file or directory`): `docker compose restart arm` |
| `docker/ros/python3-ros` (also after a branch switch that replaces it) | `docker compose restart arm` |
| `docker-compose.yaml` | `docker compose up -d arm` (recreates, no rebuild) |
| a `package.xml` dependency, `Dockerfile`, `GYM_REF` | rebuild (below) |

A `package.xml` needs a rebuild because rosdep runs at build time. Bump `GYM_REF` on purpose, never follow the branch. The bridge is the submodule `ros2_ws/src/f1tenth_gym_ros`, built by `cb`: bumping its pointer needs no rebuild unless its `package.xml` changes.

### OpenCV and NumPy

The image holds two copies of each. Apt's (`/usr/lib/python3/dist-packages`) come with `cv_bridge`, which `compressed_image_transport` and `orbbec_camera` need. The simulator's pip copies (`/usr/local/lib/python3.12/dist-packages`) come with the gym and are first on Python's path. Rules:

1. The apt layer stays before the gym's pip layer in the Dockerfile, so the pip copies win.
2. Python nodes never import `cv_bridge`, `tf_transformations` or `transforms3d`: they are built against apt's NumPy and break under the gym's NumPy 2. Convert images with NumPy and quaternions with our own helpers. C++ nodes are not affected.
3. No `python3-opencv`, `python3-pil` or `python3-numba` in our `package.xml` files.

Check in the container:

```bash
python3 -c "import cv2, numpy; print(cv2.__file__, cv2.__version__, numpy.__file__, numpy.__version__)"
```

Both paths must be under `/usr/local/`. On the Jazzy images (9 Nov 2026): `cv2` 5.0.0, NumPy 2.5.4, both from `/usr/local/lib/python3.12/dist-packages`.

Build arguments (`USER`, `UID`, `GID`, `WITH_SIM`, `GYM_REF`, `ROSDEP_SKIP`) are declared right before their first use: every `RUN` after an `ARG` misses the cache when its value changes, so keep them low in the file and the apt layer stays shared by every target and user. apt's packages and pip's wheels are kept in BuildKit cache mounts, so a rebuilt layer reuses what an earlier build downloaded; `docker builder prune` empties them.

A rebuild reuses the cache up to the first changed step. If it downloads everything again, the cache was pruned (`docker builder prune`, or Docker Desktop's automatic cleanup) or the image predates a Dockerfile change: one slow build, then it's fast again.

```bash
docker compose build arm                   # after package.xml / Dockerfile / GYM_REF changes
docker compose build --no-cache arm        # from scratch
docker compose up -d --force-recreate arm  # use the new image
```

## Car bringup (`jet`)

The car is not built yet, so this has not run on hardware. It starts the drivers: VESC, joystick teleop, the command mux and the static transform to the LiDAR.

```bash
docker compose build jet
docker compose up -d jet
docker compose exec jet bash
ros2 launch f1tenth_stack no_lidar_bringup_launch.py
```

The VESC packages build with the rest of the workspace: `cb`. What is still missing before the first run is in the TDD's open items (`docs/software/PDF_Documentation/car/`).

## PyCharm interpreter

All Python runs in the container: `rclpy` and the ROS packages have no host install. There is no host virtual environment.

`docker/ros/python3-ros` is mounted at `/opt/ros-python/bin/python`. It sources ROS and the workspace overlay, then runs `/usr/bin/python3`, so the IDE resolves `rclpy`, messages and the colcon packages.

1. `docker compose up -d arm` and `cb` once, so the workspace overlay exists.
2. Settings > Python > Interpreter > Add Interpreter > On Docker Compose, service `arm`.
3. As interpreter path enter `/opt/ros-python`. PyCharm appends `/bin/python` itself.
4. Mark each package folder in `ros2_ws/src` as Sources Root.

Afterwards:

- New packages or messages: run `cb`, then reload the interpreter paths.
- Run configurations: set Docker Compose "Command and options" to `exec` to reuse the running container.
- PyCharm leaves stopped `f1tenth_polimi-arm-run-*` containers behind. Remove them with `docker compose down --remove-orphans`, then `docker compose up -d arm`.
- `No such file or directory` on the interpreter: the bind mount is stale, see the Rebuild table above.

## Optional noVNC (RViz)

Foxglove covers day-to-day visualization. For RViz, this side container serves a desktop in the browser.

```bash
docker compose --profile gui up -d novnc   # then http://localhost:8080
docker compose rm -sf novnc                # stop and remove
```

## Cleanup

Docker images and build cache grow over time.

```bash
docker compose down -v                     # also delete build/install/log volumes
docker system df                           # disk usage
docker image prune                         # dangling images
docker builder prune                       # build cache
```
