#!/usr/bin/env python3
import rospy
import message_filters
from geometry_msgs.msg import PoseStamped
from sensor_msgs.msg import Imu
from std_srvs.srv import Trigger, TriggerResponse
from orb_slam3_ros.msg import VOStats  
from orb_slam3_ros.srv import SaveMap
import csv
from datetime import datetime
import os

class ORBDataLogger:
    def __init__(self):
        rospy.init_node('orb_data_logger', anonymous=True)
        self.node_name = rospy.get_name()

        # Output folder setup
        #pose_topic = rospy.get_param("~pose_topic", "/orb_slam3/camera_pose")
        stats_topic = rospy.get_param("~stats_topic", "/orb_slam3/vo_stats")
        self.output_dir = rospy.get_param("~output_dir", "logger_output")
        os.makedirs(self.output_dir, exist_ok=True)

        # Open output files
        self.traj_file = open(os.path.join(self.output_dir, "stamped_traj_estimate.txt"), 'w')
        self.vo_file = open(os.path.join(self.output_dir, "vo_features.csv"), 'w')
        self.imu_file = open(os.path.join(self.output_dir, "imu_data.csv"), 'w')
        
        self.vo_writer = csv.writer(self.vo_file)
        self.vo_writer.writerow(["timestamp", "id", "num_matches", "num_inliers", "state"])  
        self.imu_writer = csv.writer(self.imu_file)
        self.imu_writer.writerow(["timestamp", "acc_x", "acc_y", "acc_z", "gyro_x", "gyro_y", "gyro_z"])  

        # flush and exit service
        self._srv = rospy.Service("~save_and_exit", Trigger, self._handle_save)
        rospy.on_shutdown(self.__shutdown)

        # Subscribers
        #pose_sub = message_filters.Subscriber(pose_topic, PoseStamped)
        stats_sub = message_filters.Subscriber(stats_topic, VOStats)
        self.imu_sub = message_filters.Subscriber("/imu", Imu, self.imu_callback)

        # Synchronize topics
        sync = message_filters.ApproximateTimeSynchronizer(
            [stats_sub],
            queue_size=50,
            slop=0.01  # delta in seconds for syncing
        )
        sync.registerCallback(self.synced_callback)

        rospy.loginfo(f"{self.node_name} initialized. Logging to {self.output_dir}")
        rospy.spin()

    def synced_callback(self, stats_msg):
        """
        This is the core logic to handle synchronized messages.
        """
        ts = stats_msg.header.stamp.to_sec()

        # TUM style trajectory: ts tx ty tz qx qy qz qw
        p = stats_msg.pose.position
        q = stats_msg.pose.orientation

        # Write trajectory 
        self.traj_file.write(f"{ts:.9f} {p.x:.9f} {p.y:.9f} {p.z:.9f} "
                             f"{q.x:.9f} {q.y:.9f} {q.z:.9f} {q.w:.9f}\n")

        # Write VO stats 
        self.vo_writer.writerow([
            f"{ts:.9f}",
            stats_msg.id,
            stats_msg.n_tracked,
            stats_msg.n_inliers,
            stats_msg.state
        ])

    def imu_callback(self, imu_msg):
        """Process raw IMU data"""
        ts = imu_msg.header.stamp.to_sec()
        acc = imu_msg.linear_acceleration
        gyro = imu_msg.angular_velocity

        # Write IMU data
        self.imu_writer.writerow([
            f"{ts:.9f}",
            acc.x, acc.y, acc.z,
            gyro.x, gyro.y, gyro.z
        ])
        
    def _handle_save(self, req):
        self.__shutdown()
        rospy.signal_shutdown("SaveAndExit called")
        return TriggerResponse(success=True,
                               message="files flushed, node shutting down")

    def __shutdown(self):
        # close files
        self.traj_file.close()
        self.vo_file.close()
        self.imu_file.close()
        rospy.loginfo(f"{self.node_name}: files closed and flushed.")

        # call save trajectory service
        rospy.wait_for_service('/orb_slam3/save_traj')
        save_srv = rospy.ServiceProxy('/orb_slam3/save_traj', SaveMap)
        save_srv(os.path.join(self.output_dir, "orb"))

if __name__ == "__main__":
    try:
        ORBDataLogger()
    except rospy.ROSInterruptException:
        pass
