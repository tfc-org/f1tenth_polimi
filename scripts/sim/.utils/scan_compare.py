import math
import sys

import rclpy
from rcl_interfaces.srv import GetParameters
from rclpy.node import Node
from sensor_msgs.msg import LaserScan

TOPICS = ('/scan', '/sim/scan_unused')


def lidar_map(node: Node) -> str:
    """lidar_model's own map: set on a room world, whose laser slice differs from the gym's map by design."""
    client = node.create_client(GetParameters, '/lidar_model/get_parameters')
    if not client.wait_for_service(timeout_sec=10.0):
        print('lidar_model is not running: start the simulator first')
        sys.exit(1)
    future = client.call_async(GetParameters.Request(names=['lidar_map']))
    rclpy.spin_until_future_complete(node, future, timeout_sec=10.0)
    values = future.result().values if future.result() else []
    return values[0].string_value if values else ''


def main() -> None:
    rclpy.init()
    node = rclpy.create_node('scan_compare')
    if lidar_map(node):
        print('this map has a world: block, so lidar_model casts on its laser slice and the gym on the collision '
              'map: the scans differ by design. scan-compare is for walled maps such as spielberg.')
        sys.exit(1)
    scans: dict[str, LaserScan] = {}
    for topic in TOPICS:
        node.create_subscription(LaserScan, topic, lambda msg, t=topic: scans.setdefault(t, msg), 10)
    while len(scans) < len(TOPICS) and rclpy.ok():
        rclpy.spin_once(node, timeout_sec=0.5)
    ours, gym = (scans[t] for t in TOPICS)
    if len(ours.ranges) != len(gym.ranges) or abs(ours.angle_min - gym.angle_min) > 1e-6:
        print(f'geometry differs: {len(ours.ranges)} vs {len(gym.ranges)} beams, '
              f'angle_min {ours.angle_min:.6f} vs {gym.angle_min:.6f}')
        sys.exit(1)
    limit = min(ours.range_max, gym.range_max) - 1e-3
    diffs = sorted(abs(a - b) for a, b in zip(ours.ranges, gym.ranges)
                   if math.isfinite(a) and math.isfinite(b) and a < limit and b < limit)
    median = diffs[len(diffs) // 2]
    print(f'{len(diffs)} of {len(ours.ranges)} beams compared, median |diff| {median * 100:.2f} cm, '
          f'max {diffs[-1] * 100:.2f} cm')
    sys.exit(0 if median < 0.01 else 1)


if __name__ == '__main__':
    main()
