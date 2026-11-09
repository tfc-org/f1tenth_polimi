SHELL := /bin/bash
.DEFAULT_GOAL := help

SERVICE ?= $(if $(filter arm64 aarch64,$(shell uname -m)),arm,x86)
export SERVICE

MAP ?=
ARGS ?=
POSE ?=
WINDOW ?= 10

SIM := scripts/sim
PY_IN_CONTAINER = docker compose exec -T $(SERVICE) bash -c 'source /etc/bashrc_polimi && python3 - $(1)'

.PHONY: env help setup sim sim-ideal teleop reset stop stop-volumes pose-rate scan-compare

help: ## List the commands
	@echo "usage: make <command> [MAP=levine] [ARGS='lidar:=sl450'] [POSE='x y yaw'] [SERVICE=$(SERVICE)]"
	@echo
	@awk 'BEGIN { FS = ":.*## " } /^[a-z-]+:.*## / { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

env:
	@test -f .env || { echo ".env missing: cp .env.example .env and set HOST_UID / HOST_GID (git-ignored, so each checkout or worktree needs its own)" >&2; exit 1; }

setup: ## One-time git setup of a fresh clone (submodules, upstreams, branches)
	bash scripts/setup_git.sh

sim: env ## Start the simulator as the car, with all its imperfections [MAP, ARGS]
	bash $(SIM)/start.real.sh $(MAP) $(ARGS)

sim-ideal: env ## Start the simulator without sensor and actuator imperfections [MAP, ARGS]
	bash $(SIM)/start.ideal.sh $(MAP) $(ARGS)

teleop: env ## Keyboard control of the running simulator (second terminal)
	bash $(SIM)/start.teleop.sh

reset: env ## Put the car back at the start pose and zero /odom [MAP or POSE]
	bash $(SIM)/reset.sh $(or $(POSE),$(MAP))

stop: env ## Stop the simulator and the container
	bash $(SIM)/stop.sh

stop-volumes: env ## Stop and delete the build/install/log volumes (next start rebuilds all)
	bash $(SIM)/stop.sh --volumes

pose-rate: env ## Measure /ego_racecar/odom rate and distinct poses per second [WINDOW s]
	$(call PY_IN_CONTAINER,$(WINDOW)) < $(SIM)/.utils/pose_rate.py

scan-compare: env ## Compare /scan with the gym's /sim/scan_unused (fails above 1 cm median)
	$(call PY_IN_CONTAINER) < $(SIM)/.utils/scan_compare.py
