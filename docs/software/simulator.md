# Simulator

How to run the simulator: f1tenth_gym + f1tenth_gym_ros for the physics, plus our `polimi_sim` model nodes, in the `arm` / `x86` containers. How it is built (graph, models and their parameters, sim vs car, ideal mode, known limits) is in `TDD_Gym` (`docs/software/PDF_Documentation/sim/`).

## Run

One command, `simcar`, starts everything. Build the workspace once before the first run.

```bash
docker compose up -d arm
docker compose exec arm bash -c "source /etc/bashrc_polimi && cb"        # first time, and after adding files
docker compose exec arm bash -c "source /etc/bashrc_polimi && simcar"    # map spielberg, laser sl450
```

Another map:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && simcar levine"
```

Options go after the map:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && simcar levine debug_map_to_odom:=truth"   # scan drawn on the map
docker compose exec arm bash -c "source /etc/bashrc_polimi && simcar levine ideal:=true"                   # no imperfections, see Ideal mode
```

- From the host, the same in one line each: `bash scripts/sim/start.real.sh`, `start.ideal.sh`, `start.teleop.sh`, `reset.sh`, `stop.sh` (see [scripts/sim](../../scripts/sim/README.md)).
- `simcar [map] [launch args]` is a shell function from `docker/ros/bashrc_polimi`. `map` is a file name in `ros2_ws/config/maps/`. The rest goes to `ros2 launch polimi_sim sim_car.launch.py`.
- The car only moves when commanded (teleop or `/drive`).
- Stop: `Ctrl-C`.

## Configs

Under `ros2_ws/config/`, bind-mounted: no rebuild. They are chosen independently and merged at launch (see `TDD_Gym`).

| File | Holds | Chosen with |
|---|---|---|
| `maps/<map>.yaml` | `map_path`, start pose `sx`, `sy`, `stheta` | `simcar <map>` |
| `lidar/<lidar>.yaml` | The laser: rate, FOV, resolution, ranges, effects | `lidar:=<lidar>` (default `sl450`) |
| `car/laser_mount.yaml` | `base_link → laser`: `x 0.27, y 0.0, z 0.11, yaw 0.0, roll 0.0` **[MEASURE]** | – |
| `sim/gym.yaml` | Everything else the gym needs: topics, vehicle preset, opponents | – |

- Maps: `spielberg` (default; Red Bull Ring, a closed track about 2.2 m wide), `levine` (a corridor loop, start at (-12, 0)).
- New map: a file with those four keys. `map_path` is absolute or relative to f1tenth_gym_ros's share directory (bundled: `maps/levine`, `maps/levine_obs`, `maps/levine_blocked`, `maps/blank`, `maps/Spielberg`). Any other `gym_bridge` parameter put there overrides `sim/gym.yaml`.
- New laser: copy `lidar/sl450.yaml`, then `simcar spielberg lidar:=<name>`.
- `sim/gym.yaml` is f1tenth_gym_ros's `config/sim.yaml` at the pinned commit, minus the keys above. Re-copy it when `GYM_ROS_REF` in the Dockerfile is bumped; its header lists what differs.

## Parameters

Defaults and what each one means are in `TDD_Gym`. `actuation_model`, `odom_model` and `teleop_bridge` defaults are in `ros2_ws/src/polimi_sim/config/`; the laser's are in `ros2_ws/config/lidar/`. Edits apply on the next launch. Override a whole file with a launch argument:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && simcar levine odom_params:=/path/my_odom.yaml"
```

## Ideal mode

`simcar <map> ideal:=true`: same nodes, topics and frames, imperfections off (overrides in `TDD_Gym`). Launch it and the normal run one after the other to see what each model changes.

## Change parameters while running

Useful to feel what one imperfection does: change it, watch the stack react, no relaunch.

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && ros2 param set /lidar_model noise_std 0.0"
docker compose exec arm bash -c "source /etc/bashrc_polimi && ros2 param set /actuation_model servo_delay 0.05"
```

Live: all `lidar_model` effects, all `actuation_model` and `teleop_bridge` values, the `odom_model` error values. Fixed at start: rates, scan geometry, `range_max`, topics, frames.

Ideal scan, to compare with the gym's (`/sim/scan_unused`, noise-free):

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && ros2 param set /lidar_model effects_enabled false"
```

- Car standing still: the two scans match, except a few beams (the gym rounds beam angles to a table, so a block can start one entry later).
- Car moving: they differ by the motion distortion. Set `blocks: 1` in the lidar file to remove it.

## Foxglove

### Connect

- Browser: https://app.foxglove.dev (free account) or the desktop app.
- **Open connection → Foxglove WebSocket →** `ws://localhost:8765`.
- Ready-made layout, then **Layouts → Import from file**:
  ```bash
  docker cp f1tenth_polimi_arm:/opt/sim_ws/src/f1tenth_gym_ros/config/foxglove/gym_bridge_foxglove.json ~/Desktop/
  ```
  The layout predates `simcar`: its scan entry points at the gym's scan, so enable `/scan` by hand.

### Truth and estimate

There are two frame trees, and by default nothing connects them: `map → ego_racecar/base_link` (where the car really is) and `odom → base_link → laser` (where the car thinks it is). On the real car, SLAM or localization provides the missing `map → odom`. Until the stack has one, `debug_map_to_odom` fakes it.

- Display frame `map`: `ego_racecar/base_link` is the truth.
- `/scan` is in frame `laser`: it shows only when `laser` connects to the display frame. Display frame `odom` or `base_link`, or a `debug_map_to_odom` mode.
- `debug_map_to_odom:=truth`: scan on the map. Use it to look at the scan.
- `debug_map_to_odom:=static`: the scan and `base_link` rotate away from the map as the odometry drifts, about 8° per 90° corner. Use it to look at the drift.
- A wall hit makes the truth jump: the gym zeroes the car's heading on collision. `/odom` does not follow.

### Messages you will see

- `N Infinity invalid values detected`: harmless. Those are the beams with no return (`inf`, REP 117); Foxglove cannot colour them by distance. Set the scan's colour mode to flat to silence it.
- `Missing transform from frame <laser> to frame <...>`: the display frame is in the truth tree and nothing links `map` to `odom`. Launch with `debug_map_to_odom:=truth`, or set the display frame to `base_link`.

## Drive (teleop)

Teleop goes through the mux, exactly like the joystick on the car. Use the Foxglove **Teleop** panel on `/cmd_vel` (up / down as `linear-x`, left / right as `angular-z`, which is the steering angle in rad), or the keyboard in a second shell:

```bash
docker compose exec arm bash \
  -c "source /opt/ros/humble/setup.bash && ros2 run teleop_twist_keyboard teleop_twist_keyboard"
```

- Teleop has priority 100, autonomy (`/drive`) 10. While teleop messages arrive, they win.
- The mux input times out after 0.2 s: **hold** the key or the panel button. One key press does not keep driving until `k`, as it does with the gym alone.
- Let go: autonomy takes over again. With no autonomy the car stops 0.5 s later (VESC timeout).
- Keyboard: keys work only while that terminal has focus. No arrow keys (they send zeros).
- `i` forward · `,` reverse · `k` stop · `u` / `o` forward-left / forward-right. `q` / `z`: speed ±10% (starts at 0.5 m/s).
- Keyboard `angular.z` is 1.0, so `u` / `o` give full lock (clamped to 0.4189 rad).

## Reset position

Puts the car back on the track after a crash or to start again from a known place.

Stop the car first: a reset keeps the last speed. Then:

Foxglove 3D panel → publish tool → **Pose estimate** → click and drag; or
```bash
docker compose exec arm bash \
  -c "source /opt/ros/humble/setup.bash && ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped '{header: {frame_id: map}, pose: {pose: {position: {x: -12.0, y: 0.0}, orientation: {w: 1.0}}}}'"
```

The command above is the `levine` start. For `spielberg` use `position: {x: 0.0, y: 0.0}, orientation: {z: 0.1296, w: 0.9916}`.

After a crash the car stays stuck until reset.

Both of these move only the true car. To also start `/odom` again from 0, use `bash scripts/sim/reset.sh` from the host, or add:
```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && ros2 service call /odom_model/reset std_srvs/srv/Empty"
```

## Topics

The stack uses only `/scan`, `/odom`, TF `odom → base_link → laser`, and publishes `/drive`; never `ego_racecar/*`, which is the ground truth. The full list is in `TDD_Gym`.

## RViz (optional, via noVNC)

```bash
docker compose --profile gui up -d novnc          # on the host
rviz2 -d /opt/sim_ws/src/f1tenth_gym_ros/config/rviz/gym_bridge.rviz   # in the container
```

- View at http://localhost:8080.
- Software rendering breaks the **Map** display (GLSL error): untick it; scan and car still draw.

## Tests

The model logic is plain Python without ROS, unit-tested on synthetic data:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && cd ~/ws/src/polimi_sim && python3 -m pytest test -q"
```

## The gym alone

No model nodes, no mux, upstream config (ideal 250 Hz scan, `ego_racecar/*` frames, SICK TIM571 LiDAR). Only for checking whether a problem is in the gym or in `polimi_sim`:

```bash
docker compose exec arm bash \
  -c "source /etc/bashrc_polimi && ros2 launch f1tenth_gym_ros gym_bridge_launch.py open_foxglove:=false"
```

## Troubleshooting

- `ros2 topic list` shows only `/rosout`, `/parameter_events`: zenoh router down. `docker compose restart arm`.
- `/cmd_vel` all zeros: wrong window focused or arrow keys.
- Foxglove can't connect: sim not running, or container started before this compose change (`docker compose up -d --force-recreate arm`).
- `simcar: command not found` or `/etc/bashrc_polimi: No such file or directory`: `docker compose restart arm` (see [docker.md](docker.md)).
- `Package 'polimi_sim' not found`: build it, `cb`.
