# Simulator

How to run the simulator: f1tenth_gym (`dev-jax`, JAX on the CPU) and f1tenth_gym_ros for the physics, plus our `polimi_sim` model nodes, in the `arm` / `x86` containers. Both packages are in our fork `tfc-org/f1tenth_gym_polimi`, the submodule `ros2_ws/src/f1tenth_gym_ros`; what `polimi_sim` is and how its config overlay works is in its `README.md` there. How it is built (graph, models and their parameters, sim vs car, ideal mode, known limits) is in `TDD_Gym` (`docs/software/PDF_Documentation/sim/`).

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

- From the host, the same in one line each: `bash scripts/sim/start.real.sh`, `start.ideal.sh`, `start.teleop.sh`, `reset.sh`, `stop.sh` (see [scripts/sim](../../scripts/sim/README.md)), or `make sim`, `make sim-ideal`, `make teleop`, `make reset`, `make stop` from the root `Makefile`.
- `simcar [map] [launch args]` is a shell function from `docker/ros/bashrc_polimi`. `map` is a file name in `maps/` (ours or the defaults, below). It passes `config_dir:=~/ws/config`; the rest goes to `ros2 launch polimi_sim sim_car.launch.py`.
- The car only moves when commanded (teleop or `/drive`).
- Stop: `Ctrl-C`.

## Configs

Each file comes from `ros2_ws/config/` (our car's measured files, bind-mounted: no rebuild) if it is there, otherwise from polimi_sim's labelled defaults in `ros2_ws/src/f1tenth_gym_ros/polimi_sim/config/defaults/` (stock f1tenth and datasheet values). The launch logs where each one came from, and warns for each file we don't have. Today `ros2_ws/config/` holds `car/laser_mount.yaml`, `car/body.yaml`, `lidar/sl450.yaml` and the generated `maps/demo_room.yaml`; everything else is a default. The files are chosen independently and merged at launch (see `TDD_Gym`).

| File | Holds | Chosen with |
|---|---|---|
| `maps/<map>.yaml` | `map_path`, start pose `sx`, `sy`, `stheta` | `simcar <map>` |
| `lidar/<lidar>.yaml` | The laser: rate, FOV, resolution, ranges, effects | `lidar:=<lidar>` (default `sl450`) |
| `car/laser_mount.yaml` | `base_link → laser`: `x 0.27, y 0.0, z 0.11, yaw 0.0, roll 0.0` **[MEASURE]** | – |
| `car/body.yaml` | Track width 0.281 m, servo clamp 0.3135 rad left and 0.2634 rad right **[MEASURE]** | – |
| `sim/gym.yaml` | Everything else the gym needs: topics, vehicle preset, opponents | – |
| `actuation_model.yaml`, `odom_model.yaml`, `teleop_bridge.yaml` | The other models | – |

- Maps: `spielberg` (default; Red Bull Ring, a closed track about 2.2 m wide), `levine` (a corridor loop, start at (-12, 0)), and the room world `demo_room` (below).
- Start poses `sx`, `sy`, `stheta` are the rear axle (`base_link` on the car).
- New map: a file with those four keys in `ros2_ws/config/maps/`. `map_path` is absolute, relative to the map file's folder when it starts with `./` or `../`, or else relative to f1tenth_gym_ros's share directory (bundled: `maps/levine`, `maps/levine_obs`, `maps/levine_blocked`, `maps/blank`, `maps/Spielberg`). Any other `gym_bridge` parameter put there overrides `sim/gym.yaml`.
- New laser: copy `lidar/sl450.yaml` into `ros2_ws/config/lidar/`, then `simcar spielberg lidar:=<name>`.
- To override a default, copy it to the same path under `ros2_ws/config/` and edit it.

## Parameters

Defaults and what each one means are in `TDD_Gym`. The model files resolve like the configs above. Edits apply on the next launch. Override a whole file with a launch argument:

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
- Ready-made layout: **Layouts → Import from file** → `ros2_ws/src/f1tenth_gym_ros/polimi_sim/config/foxglove/polimi_sim.json`: fixed frame `sim_world`, the gym's map on `/sim/map`, **Pose estimate** on `/sim/initialpose`. Upstream's `config/foxglove/gym_bridge_foxglove.json` still uses `map` and `/initialpose`, which the gym no longer listens to.
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
  -c "source /etc/bashrc_polimi && ros2 run teleop_twist_keyboard teleop_twist_keyboard"
```

- Teleop has priority 100, autonomy (`/drive`) 10. While teleop messages arrive, they win.
- The mux input times out after 0.2 s: **hold** the key or the panel button. One key press does not keep driving until `k`, as it does with the gym alone.
- Let go: autonomy takes over again. With no autonomy the car stops 0.5 s later (VESC timeout).
- Keyboard: keys work only while that terminal has focus. No arrow keys (they send zeros).
- `i` forward · `,` reverse · `k` stop · `u` / `o` forward-left / forward-right. `q` / `z`: speed ±10% (starts at 0.5 m/s).
- Keyboard `angular.z` is 1.0, so `u` / `o` give full lock (clamped to 0.4189 rad).

## Room worlds

A room with furniture and a taped loop on the floor, as the car will run (`TDD_Gym`, Worlds). One source file per world, `ros2_ws/maps/src/<world>.yaml`: the room outline, boxes and prisms with a height, the track as straights and arcs with its width and tape, the floor colour and the start. `demo_room` is a placeholder until the real room is surveyed.

- `simcar demo_room` (or `make sim MAP=demo_room`) regenerates the world at every start, so editing the source is the only step. By hand: `ros2 run polimi_sim make_world ~/ws/maps/src/demo_room.yaml` prints the checks, the lap and tape lengths and the start pose.
- A corner tighter than the car can turn plus 0.2 m (about 1.02 m left, 1.22 m right) or a loop that does not close stops the run with the reason; `--allow-tight` lets a tight corner through with a warning.
- The generated folder `ros2_ws/maps/<world>/` is git-ignored; `ros2_ws/config/maps/<world>.yaml` is tracked and comes out byte-identical, so `git status` stays clean.
- The LiDAR sees the room at laser height: walls, the objects taller than 0.11 m, never the tape. The car collides with every object.
- Evaluation, from the truth: `/sim/eval/on_track`, `lateral_offset`, `progress`, `lap`, `lap_time`, `collisions`, `/sim/health/physics_rate` (≈ 100) and `odom_rate` (≈ 250); `/sim/truth/tape` draws the tape in Foxglove. Off track means the car's centre is more than 0.69 m from the centre line: all four wheels past a tape.
- One CSV line per lap (`lap,time_s,valid,max_offset_m,time_off_track_s`) in `ros2_ws/runs/` on the host. A lap with a contact or a reset is `valid: false`. After pulling this change, recreate the container once (`docker compose up -d arm`) so `ros2_ws/runs` is mounted; until then the CSVs go to `/tmp/polimi_sim/` in the container.
- `make scan-compare` is for walled maps: it refuses a room world, whose laser slice differs from the gym's collision map by design.

## Reset position

Puts the car back on the track after a crash or to start again from a known place.

Stop the car first: a reset keeps the last speed. Then, from the host:
```bash
bash scripts/sim/reset.sh              # the start of the running map (or: make reset)
bash scripts/sim/reset.sh 2.0 1.0 1.57 # rear axle at x, y [m], yaw [rad] in sim_world
```
Both go through `sim_reset` (`/sim/reset`, `/sim/reset_pose`), which also zeroes `/odom`, as after moving the car by hand. Inside the container: `ros2 service call /sim/reset std_srvs/srv/Empty`.

Foxglove's **Pose estimate** with our layout publishes on `/sim/initialpose`: it moves only the true car and leaves `/odom` integrating. After a crash the car stays stuck until reset.

## Topics

The stack uses only `/scan`, `/odom`, TF `odom → base_link → laser`, and publishes `/drive`; never `ego_racecar/*`, which is the ground truth. The full list is in `TDD_Gym`.

## RViz (optional, via noVNC)

```bash
docker compose --profile gui up -d novnc          # on the host
rviz2 -d ~/ws/src/f1tenth_gym_ros/config/rviz/gym_bridge.rviz   # in the container
```

- View at http://localhost:8080.
- Software rendering breaks the **Map** display (GLSL error): untick it; scan and car still draw.

## Tests

The model logic is plain Python without ROS, unit-tested on synthetic data:

```bash
docker compose exec arm bash -c "source /etc/bashrc_polimi && cd ~/ws/src/f1tenth_gym_ros/polimi_sim && python3 -m pytest test -q"
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
