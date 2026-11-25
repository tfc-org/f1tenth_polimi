#!/bin/bash
# Start the simulator: start_mask.sh [map] [launch args...]
# Used by start.real.sh and start.ideal.sh; Ctrl-C stops the simulator, the container keeps running.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

ensure_up

# Needed the first time and after adding files; a few seconds when nothing changed.
in_container "cb"

# The page keeps retrying until the simulator's bridge is up, a few seconds later.
open_foxglove
echo "==> simcar $*   (Foxglove: ws://localhost:${FOXGLOVE_PORT:-8765})"
in_container "simcar $*"
