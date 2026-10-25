# Simulator scripts

Shortcuts to run the simulator from the host, without typing the `docker compose exec …` lines. They work from any directory and start the container if it is not running. How to run and tune it is in [docs/software/simulator.md](../../docs/software/simulator.md); how it works is in [TDD_Gym](../../docs/software/PDF_Documentation/sim/.TDD_Gym.latest.pdf).

| Script | Does |
|---|---|
| `start.real.sh [map] [launch args]` | The simulator as the car, with all its imperfections. |
| `start.ideal.sh [map] [launch args]` | Same, without sensor and actuator imperfections, to compare. |
| `start.teleop.sh` | Keyboard control. Run it in a second terminal. |
| `reset.sh [map \| x y yaw]` | Puts the car back at the start pose of the running map, of another map, or at a pose, and zeroes `/odom`. |
| `stop.sh [--volumes]` | Stops the simulator and the container. |

## Typical session

```bash
bash scripts/sim/start.real.sh            # terminal 1: map spielberg; Ctrl-C stops the simulator
bash scripts/sim/start.teleop.sh          # terminal 2: hold i / u / o / , to drive
```
```bash
bash scripts/sim/reset.sh                 # terminal 3: after a crash
```
```bash
bash scripts/sim/stop.sh                  # when done
```

The start scripts open Foxglove in the browser, already pointed at `ws://localhost:8765`.

## Details

- Map: a file name in `ros2_ws/config/maps/`, default `spielberg`. `bash scripts/sim/start.real.sh levine`.
- Anything after the map goes to the launch: `bash scripts/sim/start.real.sh spielberg debug_map_to_odom:=truth`.
- The start scripts build the workspace first (`cb`): slow the first time, a few seconds afterwards.
- `Ctrl-C` in a start script stops the simulator only; the container keeps running, so the next start is quick.
- `reset.sh 2.0 1.0 1.57` takes x [m], y [m], yaw [rad] in the map frame. It moves the true car and restarts `/odom` from 0, so the state is the same as right after a start. No relaunch needed.
- `stop.sh` keeps the build volumes. `stop.sh --volumes` deletes them: the next start rebuilds the whole workspace.
- `FOXGLOVE=0 bash scripts/sim/start.real.sh` starts without opening the browser, e.g. when the tab is already open.
- Service: `arm` on Apple Silicon, `x86` elsewhere. Override with `SERVICE=x86 bash scripts/sim/start.real.sh`.
- `.utils/` holds the helpers the scripts share (`common.sh`, `start_mask.sh`); don't run them directly.
