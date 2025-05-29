# ROS data collection workflow (with docker)

This section outlines the setup used for running ORB-SLAM3 inside docker, publishing data through ROS and collecting it for later processing.

---

## Workspace structure
- ROS workspace (`~/orb_ws`):
    Contains the ORB-SLAM3 source code and custom ROS nodes (ros_mono, ros_mono_inertial, etc.)
- Dataset directory
    Contains .bag files and calibration/config YAMLs
- Volumes
    When launching the docker container, mount both:
    - The ROS workspace (to be able to build + run nodes)
    - The dataset directory (for access to .bag files and saving output)

example command: 

                    docker run --rm \
                    -v {path_to_workspace}:/root/orb_ws \
                    -v {path_to_dataset}:/root/data \
                    -e DISPLAY=$DISPLAY \
                    -v /tmp/.X11-unix:/tmp/.X11-unix \
                    --net=host \
                    -it \
                    orbslam3_ros


## Launching ORB-SLAM3

```
# inside the docker container
source ~/orb_ws/devel/setup.bash

# Launch the SLAM system with the correct sensor config
roslaunch orb_slam3_ros mono_inertial.launch
```

The launch file:
- Starts the correct SLAM node (ie ros_mono_inertial)
- Loads parameters (vocabulary, camera model params)
- Remaps topics to match the bag file
- Sets up publishers

## Running a dataset and logging output

```
# In a separate terminal
rosbag play dataset.bag
```

Then to record the data in a new bag file for offline processing

```
rosbag record /topic1 /topic2 ... 
```

