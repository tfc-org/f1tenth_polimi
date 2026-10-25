# F1tenth_PoliMI

Politecnico di Milano's [F1TENTH](https://f1tenth.org/) autonomous racing stack, developed for the ACAV course.

## Overview

F1TENTH is a 1/10-scale autonomous racing platform: a modified RC car with onboard compute and sensors that must map a track, localize itself, and race around it at high speed with no human input. This repository holds everything for our car:

- **Hardware:** parts selection, bill of materials, datasheets, CAD and wiring.
- **Software:** a ROS 2 workspace (`ros2_ws/`) with the perception, localization (SLAM), planning and control stack, and a simulator that behaves like the car so the stack can be written before the car exists.
- **Documentation:** requirements and design as LaTeX documents (RASD, TDD), runbooks in Markdown.

Our course setup is not a standard F1TENTH track: the car races in a room on a track drawn with tape on the floor. See the [requirements (RASD)](docs/software/PDF_Documentation/car/.RASD_F1tenth.latest.pdf).

> 🚧 Work in progress: the hardware is still being selected and the car is not built. Meanwhile the software is developed against the simulator.

## Hardware

- **Compute:** NVIDIA Jetson Orin Nano Developer Kit
- **LiDAR:** Orbbec Pulsar SL450 (see the [TDD](docs/software/PDF_Documentation/car/.TDD_F1tenth.latest.pdf), Hardware Selection)
- **Camera:** Orbbec Gemini 335L (see the [TDD](docs/software/PDF_Documentation/car/.TDD_F1tenth.latest.pdf), Hardware Selection)
- **Chassis:** Traxxas Ford Fiesta ST Rally VXL (74276-4); see the [TDD](docs/software/PDF_Documentation/car/.TDD_F1tenth.latest.pdf), Hardware Selection
- **Full parts list:** [Master BOM](hardware/bom/master_bom.xlsx)

## Repository structure

```
f1tenth_polimi/
├── docs/
│   ├── Latex_Templates/  # Submodule: LaTeX templates and docbuild
│   ├── Makefile          # make status / build / release for the documents
│   └── software/         # Runbooks (.md), Source_Documentation/ (.tex), PDF_Documentation/
├── hardware/             # BOM, datasheets, CAD, electronics
├── docker/
│   ├── ros/              # ROS image (ros:humble + deps + simulator)
│   └── novnc/            # Optional browser display for RViz
├── docker-compose.yaml   # Services: arm, x86, jet, novnc
├── ros2_ws/
│   ├── src/
│   │   ├── f1tenth_system/   # Submodule: drivers (our fork)
│   │   └── polimi_*/         # Our packages
│   ├── config/               # maps, lidar, car, sim: one file per thing, no rebuild
│   └── maps/                 # Our own map images (none yet)
└── scripts/              # setup_git.sh, sim/ (start, teleop, reset, stop the simulator)
```

## Quick start (simulator)

Everything runs in Docker; nothing is installed on the host besides Docker itself.

```bash
git clone --recurse-submodules https://github.com/tfc-org/f1tenth_polimi.git
cd f1tenth_polimi && bash scripts/setup_git.sh
cp .env.example .env              # set HOST_UID / HOST_GID
docker compose build arm          # x86 on a PC
docker compose up -d arm
docker compose exec arm bash
cb                                # build the workspace (first time)
simcar                            # simulator as the car: map spielberg, laser sl450
```

Once the image is built, `bash scripts/sim/start.real.sh` does the last four lines in one go.

- `setup_git.sh` fetches the submodules and sets `push.recurseSubmodules=check`, `submodule.recurse=true` and an `upstream` remote in the fork. Safe to re-run.
- `HOST_UID` / `HOST_GID` (from `id -u`, `id -g`) make the container user match yours, so files created in the bind-mounted folders stay yours on the host.
- Pick the service for your machine: `arm` Apple Silicon, `x86` PC, `jet` Orin Nano on the car. The first build takes a while (gym and gym_ros).
- Code, configs and maps are bind-mounted, so most changes need only `cb`. Rebuild the image only when the `Dockerfile`, a `package.xml` (rosdep runs at build time) or `GYM_REF` / `GYM_ROS_REF` changes. Bump the pins on purpose, never follow the branch.

Then open Foxglove at `ws://localhost:8765` to see the track, the car and the scan. The car stands still until it gets a command: [Simulator](docs/software/simulator.md) shows how to drive it.

## Documentation

New here: Quick start above, then Simulator. The others are references for when you need them.

Requirements and design are LaTeX documents, built from `docs/` with `make build` (sources in `docs/software/Source_Documentation/`):

| Document | Contents |
|---|---|
| [RASD_F1tenth](docs/software/PDF_Documentation/car/.RASD_F1tenth.latest.pdf) | Environment (room, taped track), what the car must do, acceptance, summer school exercises, open items |
| [TDD_F1tenth](docs/software/PDF_Documentation/car/.TDD_F1tenth.latest.pdf) | Stack layers, car interface, deployment, design decisions, hardware selection (LiDAR, camera, chassis) |
| [TDD_Gym](docs/software/PDF_Documentation/sim/.TDD_Gym.latest.pdf) | The simulator: gym, model nodes and their parameters, sim vs car, known limits |

Runbooks:

| Doc | Contents |
|---|---|
| [Docker](docs/software/docker.md) | Services, networking, day-to-day commands, rebuilds, car bringup, PyCharm interpreter, cleanup |
| [Simulator](docs/software/simulator.md) | `simcar`: run, map / laser configs, live parameters, Foxglove, teleop, reset |
| [Contributing](CONTRIBUTING.md) | Fork and submodule workflow, teams, permissions, rulesets, who can review and merge |

## License

Released under the [MIT License](LICENSE).
