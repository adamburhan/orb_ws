import rosbag, rospy, cv2
import os, sys, glob, argparse
from cv_bridge import CvBridge
from sensor_msgs.msg import Image, CompressedImage

def raw_topic_name_from_compressed(topic: str) -> str:
    # Strip trailing "/compressed"
    return topic[:-11] if topic.endswith("/compressed") else topic

def copy_topics(in_bag_path, out_bag_path, topic_list):
    """Copy selected topics from an input bag into an open output bag"""
    bridge = CvBridge()
    copied = 0
    decompressed = 0
    with rosbag.Bag(out_bag_path, 'w') as bag_out:
        with rosbag.Bag(in_bag_path, 'r') as bag_in:
            for topic, msg, t in bag_in.read_messages():
                if topic in topic_list:
                    if topic == "/camera/color/image_raw/compressed":
                        cv_img = bridge.compressed_imgmsg_to_cv2(msg, desired_encoding="bgr8")
                        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
                        img_msg = bridge.cv2_to_imgmsg(gray, encoding="mono8")
                        img_msg.header = msg.header
                        
                        out_topic = raw_topic_name_from_compressed(topic)
                        bag_out.write(out_topic, img_msg, t)
                    else:
                        bag_out.write(topic, msg, t)
                        copied += 1
    print(f"[OK] Copied {copied} messages from {in_bag_path}.")

def parse_args():
    ap = argparse.ArgumentParser(
        description="Copy selected topics from a bag; decode CompressedImage to uncompressed Image."
    )
    ap.add_argument("--inbag", required=True, help="Path to input bag.")
    ap.add_argument("--outbag", required=True, help="Path to output bag.")
    ap.add_argument("--topics", default="",
                    help="Comma-separated list of topics to copy. "
                         "If empty, copy all (except /clock). "
                         "If a compressed topic is selected, it will be decoded and written to its raw name.")
    return ap.parse_args()

def main():
    args = parse_args()
    topics = [t.strip() for t in args.topics.split(",") if t.strip()] if args.topics else []
    rospy.init_node("copy_and_decompress_bag", anonymous=True, disable_signals=True)

    copy_topics(
        in_bag_path=args.inbag,
        out_bag_path=args.outbag,
        topic_list=topics
    )

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        sys.stderr.write(f"[ERROR] {e}\n")
        sys.exit(1)
