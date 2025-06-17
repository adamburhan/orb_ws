import rosbag
import cv2
import shutil
from cv_bridge import CvBridge
import os

# Euroc sequences to extract
sequences = [
    "MH_01_easy",
    "MH_02_easy",
    "MH_03_medium",
    "MH_04_difficult",
    "MH_05_difficult",
    "V1_01_easy",
    "V1_02_medium",
    "V1_03_difficult",
    "V2_01_easy",
    "V2_02_medium",
    "V2_03_difficult"
]

for seq in sequences:
    bag_path = f"/root/data/euroc/{seq}/{seq}.bag"
    output_dir = f"/root/data/euroc/{seq}/images_cam0"
    topic = "/cam0/image_raw"

    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)  # Remove existing directory and contents
    os.makedirs(output_dir)

    bridge = CvBridge()

    frame_counter = 0  # starts at 0 and increments like mnId

    with rosbag.Bag(bag_path, "r") as bag:
        for topic_name, msg, t in bag.read_messages(topics=[topic]):
            try:
                cv_img = bridge.imgmsg_to_cv2(msg, desired_encoding="bgr8")
                out_path = os.path.join(output_dir, f"{frame_counter:06d}.png")
                cv2.imwrite(out_path, cv_img)
                frame_counter += 1
            except Exception as e:
                print(f"[{seq}] Skipped frame due to error: {e}")
