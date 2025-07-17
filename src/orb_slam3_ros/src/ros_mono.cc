/**
 *
 * Adapted from ORB-SLAM3: Examples/ROS/src/ros_mono.cc
 *
 */

#include "common.h"

using namespace std;

class ImageGrabber
{
public:
    ImageGrabber() : GTPoseMap(nullptr) {};

    void GrabImage(const sensor_msgs::ImageConstPtr &msg);

    bool LoadGroundTruthPoses(const std::string &gt_poses_file);

private:
    // map from timestamp to ground truth pose
    std::unordered_map<double, Sophus::SE3f>* GTPoseMap;

    bool GetClosestGroundTruthPose(double timestamp, Sophus::SE3f &gt_pose);
};

int main(int argc, char **argv)
{
    ros::init(argc, argv, "Mono");
    ros::console::set_logger_level(ROSCONSOLE_DEFAULT_NAME, ros::console::levels::Info);
    if (argc > 1)
    {
        ROS_WARN("Arguments supplied via command line are ignored.");
    }

    std::string node_name = ros::this_node::getName();

    ros::NodeHandle node_handler;
    image_transport::ImageTransport image_transport(node_handler);

    std::string voc_file, settings_file, gt_poses_file;
    node_handler.param<std::string>(node_name + "/voc_file", voc_file, "file_not_set");
    node_handler.param<std::string>(node_name + "/settings_file", settings_file, "file_not_set");
    node_handler.param<std::string>(node_name + "/gt_poses_file", gt_poses_file, "file_not_set");

    if (voc_file == "file_not_set" || settings_file == "file_not_set" || gt_poses_file == "file_not_set")
    {
        ROS_ERROR("Please provide voc_file, settings_file and gt_poses_file in the launch file");
        ros::shutdown();
        return 1;
    }

    node_handler.param<std::string>(node_name + "/world_frame_id", world_frame_id, "map");
    node_handler.param<std::string>(node_name + "/cam_frame_id", cam_frame_id, "camera");

    bool enable_pangolin;
    node_handler.param<bool>(node_name + "/enable_pangolin", enable_pangolin, true);

    // Create SLAM system. It initializes all system threads and gets ready to process frames.
    sensor_type = ORB_SLAM3::System::MONOCULAR;
    pSLAM = new ORB_SLAM3::System(voc_file, settings_file, sensor_type, enable_pangolin);
    ImageGrabber igb;

    // load gt poses
    igb.LoadGroundTruthPoses(gt_poses_file);

    ros::Subscriber sub_img = node_handler.subscribe("/camera/image_raw", 1, &ImageGrabber::GrabImage, &igb);

    setup_publishers(node_handler, image_transport, node_name);
    setup_services(node_handler, node_name);

    ros::spin();

    // Stop all threads
    pSLAM->Shutdown();
    ros::shutdown();

    return 0;
}

//////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////

void ImageGrabber::GrabImage(const sensor_msgs::ImageConstPtr &msg)
{
    // Copy the ros image message to cv::Mat.
    cv_bridge::CvImageConstPtr cv_ptr;
    try
    {
        cv_ptr = cv_bridge::toCvShare(msg);
    }
    catch (cv_bridge::Exception &e)
    {
        ROS_ERROR("cv_bridge exception: %s", e.what());
        return;
    }

    // Get timestamp and ground truth pose
    double timestamp = cv_ptr->header.stamp.toSec();
    Sophus::SE3f gt_pose;
    Sophus::SE3f* gt_pose_ptr = nullptr;

    if(GetClosestGroundTruthPose(timestamp, gt_pose)) {
        gt_pose_ptr = &gt_pose;
        ROS_DEBUG("Found GT pose for timestamp %.3f", timestamp);
    }

    // ORB-SLAM3 runs in TrackMonocular()
    Sophus::SE3f Tcw = pSLAM->TrackMonocular(cv_ptr->image, timestamp, gt_pose_ptr);

    ros::Time msg_time = msg->header.stamp;

    publish_topics(msg_time);
}

bool ImageGrabber::LoadGroundTruthPoses(const std::string &gt_poses_file)
{
    if (!GTPoseMap) 
    {
        GTPoseMap = new std::unordered_map<double, Sophus::SE3f>();
    } else 
    {
        GTPoseMap->clear();
    }

    std::ifstream file(gt_poses_file);
    if (!file.is_open())
    {
        ROS_ERROR("Could not open ground truth poses file: %s", gt_poses_file.c_str());
        return false;
    }

    std::string line;
    while (std::getline(file, line)) 
    {
        std::stringstream ss(line);
        double timestamp;
        float tx, ty, tz, qx, qy, qz, qw;

        ss >> timestamp >> tx >> ty >> tz >> qx >> qy >> qz >> qw;

        // std::cout << "Loaded GT pose at timestamp: " << timestamp << std::endl;
        // std::cout << "Position: (" << tx << ", " << ty << ", " << tz << ")" << std::endl;
        // std::cout << "Orientation: (" << qx << ", " << qy << ", " << qz << ", " << qw << ")" << std::endl;

        Eigen::Quaternionf q(qw, qx, qy, qz);
        Eigen::Vector3f t(tx, ty, tz);
        Sophus::SE3f gt_pose(q, t);

        (*GTPoseMap)[timestamp] = gt_pose;
    }
    return true;
}

bool ImageGrabber::GetClosestGroundTruthPose(double timestamp, Sophus::SE3f &gt_pose)
{
    if (!GTPoseMap || GTPoseMap->empty())
    {
        ROS_WARN("Ground truth poses map is empty or not initialized.");
        return false;
    }

    const double max_time_diff = 0.02;

    auto it = GTPoseMap->find(timestamp);
    if (it != GTPoseMap->end())
    {
        gt_pose = it->second;
        return true;
    }

    double closest_diff = std::numeric_limits<double>::max();
    double closest_ts = 0;
    Sophus::SE3f closest_pose;

    for (const auto& entry : *GTPoseMap)
    {
        double diff = std::abs(entry.first - timestamp);
        if (diff < closest_diff) 
        {
            closest_diff = diff;
            closest_pose = entry.second;
            closest_ts = entry.first;
        }
    }

    if(closest_diff > max_time_diff) {
        ROS_WARN("No GT pose found within %f seconds of timestamp %f", 
                max_time_diff, timestamp);
        return false;
    }
    
    gt_pose = closest_pose;
    return true;
}