import math
import sys

import rclpy
from sensor_msgs.msg import LaserScan

TOPICS = ('/scan', '/sim/scan_unused')


def main() -> None:
    rclpy.init()
    node = rclpy.create_node('scan_compare')
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
