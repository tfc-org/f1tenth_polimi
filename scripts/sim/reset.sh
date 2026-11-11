#!/bin/bash
# Put the car somewhere and zero its odometry, through polimi_sim's sim_reset.
#   reset.sh            start pose of the running map (/sim/reset)
#   reset.sh levine     start pose of that map (ros2_ws/config/maps/levine.yaml, else polimi_sim's default)
#   reset.sh 3.0 1.5 0.26   x [m], y [m], yaw [rad] of the rear axle in sim_world (the simulator's truth)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.utils/common.sh"

require_sim
if [ $# -eq 0 ]; then
    in_container "ros2 service call /sim/reset std_srvs/srv/Empty" > /dev/null
    echo "==> reset to the start, odometry zeroed"
    exit 0
elif [ $# -eq 3 ]; then
    x=$1 y=$2 yaw=$3
elif [ $# -eq 1 ]; then
    map_file="ros2_ws/config/maps/$1.yaml"
    [ -f "$map_file" ] || map_file="ros2_ws/src/f1tenth_gym_ros/polimi_sim/config/defaults/maps/$1.yaml"
    [ -f "$map_file" ] || { echo "maps/$1.yaml is in neither ros2_ws/config nor polimi_sim's defaults" >&2; exit 1; }
    value() { awk -v key="$1:" '$1 == key { print $2 }' "$map_file"; }
    x=$(value sx) y=$(value sy) yaw=$(value stheta)
else
    echo "usage: reset.sh [map | x y yaw]" >&2
    exit 2
fi

# Yaw as a quaternion about z.
qz=$(awk -v yaw="$yaw" 'BEGIN { printf "%.6f", sin(yaw / 2) }')
qw=$(awk -v yaw="$yaw" 'BEGIN { printf "%.6f", cos(yaw / 2) }')

echo "==> reset to x=$x y=$y yaw=$yaw"
in_container "ros2 topic pub --once /sim/reset_pose geometry_msgs/msg/PoseStamped \
  '{header: {frame_id: sim_world}, pose: {position: {x: $x, y: $y}, orientation: {z: $qz, w: $qw}}}'" > /dev/null
echo "==> odometry zeroed"
