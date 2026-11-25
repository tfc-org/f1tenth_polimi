# Shared by the scripts in this folder. Sourced, not run.
#   SERVICE=x86 bash scripts/sim/start.real.sh    # override the compose service
#   FOXGLOVE=0 bash scripts/sim/start.real.sh     # don't open Foxglove in the browser

# Repo root: the scripts work from any directory.
cd "$(dirname "${BASH_SOURCE[0]}")/../../.." || exit 1

if [ -z "${SERVICE:-}" ]; then
    case "$(uname -m)" in
        arm64 | aarch64) SERVICE=arm ;;
        *) SERVICE=x86 ;;
    esac
fi

# Run a command in the container with ROS, the workspace and our shell helpers loaded.
in_container() {
    docker compose exec "$SERVICE" bash -c "source /etc/bashrc_polimi && $*"
}

# Start the container if needed. A branch switch can leave the bashrc bind mount stale: restart fixes it.
ensure_up() {
    docker compose up -d "$SERVICE"
    if ! docker compose exec -T "$SERVICE" test -f /etc/bashrc_polimi; then
        echo "==> /etc/bashrc_polimi is stale, restarting $SERVICE"
        docker compose restart "$SERVICE"
    fi
}

# Open Foxglove in the host's browser, connected to the simulator. FOXGLOVE=0 skips it.
FOXGLOVE_URL="https://app.foxglove.dev/?ds=foxglove-websocket&ds.url=ws://localhost:${FOXGLOVE_PORT:-8765}"
open_foxglove() {
    [ "${FOXGLOVE:-1}" = "0" ] && return 0
    if command -v open > /dev/null; then
        open "$FOXGLOVE_URL"
    elif command -v xdg-open > /dev/null; then
        xdg-open "$FOXGLOVE_URL" > /dev/null 2>&1 &
    else
        echo "Open Foxglove yourself: $FOXGLOVE_URL"
    fi
}

# Map of the running simulator, empty if it is not running.
running_map() {
    docker compose exec -T "$SERVICE" pgrep -af 'sim_car.launch.py' 2>/dev/null \
        | grep -o 'map:=[^ ]*' | head -n 1 | cut -d= -f2 || true
}

require_sim() {
    if [ -z "$(running_map)" ]; then
        echo "The simulator is not running. Start it with scripts/sim/start.real.sh or start.ideal.sh." >&2
        exit 1
    fi
}
