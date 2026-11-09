#!/bin/bash
# Put the car back on the track and zero its odometry, as if the simulator had just started.
#   reset.sh            start pose of the running map
#   reset.sh levine     start pose of that map (ros2_ws/config/maps/levine.yaml, else polimi_sim's default)
#   reset.sh 3.0 1.5 0.26   x [m], y [m], yaw [rad] in the map frame
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/.utils/common.sh"

require_sim
if [ $# -eq 3 ]; then
    x=$1 y=$2 yaw=$3
elif [ $# -le 1 ]; then
    map="${1:-$(running_map)}"
    map_file="ros2_ws/config/maps/$map.yaml"
    [ -f "$map_file" ] || map_file="ros2_ws/src/f1tenth_gym_ros/polimi_sim/config/defaults/maps/$map.yaml"
    [ -f "$map_file" ] || { echo "maps/$map.yaml is in neither ros2_ws/config nor polimi_sim's defaults" >&2; exit 1; }
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
in_container "ros2 topic pub --once /initialpose geometry_msgs/msg/PoseWithCovarianceStamped \
  '{header: {frame_id: map}, pose: {pose: {position: {x: $x, y: $y}, orientation: {z: $qz, w: $qw}}}}'" > /dev/null

# Wheel odometry would keep integrating from the old place: start it again from 0.
in_container "ros2 service call /odom_model/reset std_srvs/srv/Empty" > /dev/null
echo "==> odometry reset"
