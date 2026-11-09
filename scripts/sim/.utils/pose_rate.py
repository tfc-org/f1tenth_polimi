import sys
import time

import rclpy
from nav_msgs.msg import Odometry

WINDOW = float(sys.argv[1]) if len(sys.argv) > 1 else 10.0


def main() -> None:
    rclpy.init()
    node = rclpy.create_node('pose_rate')
    seen = {'msgs': 0, 'distinct': 0, 'last': None}

    def on_odom(msg: Odometry) -> None:
        p = msg.pose.pose
        pose = (p.position.x, p.position.y, p.orientation.z, p.orientation.w)
        seen['msgs'] += 1
        if pose != seen['last']:
            seen['distinct'] += 1
            seen['last'] = pose

    node.create_subscription(Odometry, '/ego_racecar/odom', on_odom, 100)
    end = time.monotonic() + WINDOW
    while time.monotonic() < end:
        rclpy.spin_once(node, timeout_sec=0.1)
    print(f"{seen['msgs'] / WINDOW:.1f} msgs/s, {seen['distinct'] / WINDOW:.1f} distinct poses/s over {WINDOW:.0f} s")
    node.destroy_node()
    rclpy.shutdown()


if __name__ == '__main__':
    main()
