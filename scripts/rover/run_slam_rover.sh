#!/usr/bin/env bash
set -e
trap cleanup EXIT

cleanup() {
    echo "[INFO] Cleaning up processes..."
    kill $LOGGER_PID $SLAM_PID $ROSCORE_PID $BAG_PID 2>/dev/null || true
}


DATASET=$1 
SEQUENCE=$2
MODE=$3

# ROS envrionment
source /opt/ros/noetic/setup.bash


cd /root/orb_ws 

if [ ! -d .catkin_tools ]; then
    catkin init
    catkin config \
    --extend /opt/ros/noetic 
fi

catkin build -j$(nproc) 
source /root/orb_ws/devel/setup.bash

LOG_DIR="/root/data/${DATASET}/${SEQUENCE}/${MODE}/logs"
mkdir -p "$LOG_DIR"
BAG_PATH="/root/data/${DATASET}/bags/${SEQUENCE}.bag"

if [ ! -f "$BAG_PATH" ]; then
  echo "[ERROR] Bag file not found: $BAG_PATH"
  exit 1
fi


# Start master
roscore &
ROSCORE_PID=$!
sleep 2

# Logger
roslaunch orb_data_logger orb_data_logger.launch output_dir:=${LOG_DIR} &
LOGGER_PID=$!
sleep 2

# SLAM
roslaunch --wait orb_slam3_ros "${DATASET}_${MODE}.launch" &
SLAM_PID=$!
sleep 2

# Rosbag play
rosbag play "$BAG_PATH" --clock --pause --quiet __name:=rosbag_play &
BAG_PID=$!

# Wait for rosbag service to be ready
for i in {1..10}; do
    if rosservice list | grep -q "/rosbag_play/pause_playback"; then
        break
    fi
    echo "[INFO] Waiting for rosbag service..."
    sleep 1
done

# Start playback
rosservice call /rosbag_play/pause_playback "data: false" || true
wait $BAG_PID

echo "[INFO] Bag finished. Calling logger flush..."


# if rosnode list 2>/dev/null | grep -q /listener ; then
#     # ---- call flush once and wait for it to finish ----------------------
#     rosservice call /listener/save_and_exit || true
#     # give the node time to exit on its own
#     while rosnode list 2>/dev/null | grep -q /listener ; do
#         sleep 0.5
#     done
# fi

LOGGER_TIMEOUT=20   # seconds

echo "[INFO] Flushing logger ..."
rosservice call /listener/save_and_exit || true

t0=$(date +%s)
while rosnode list 2>/dev/null | grep -q /listener ; do
    if (( $(date +%s) - t0 > LOGGER_TIMEOUT )); then
        echo "[WARN] Logger did not exit in ${LOGGER_TIMEOUT}s – forcing kill"
        kill -SIGINT $LOGGER_PID 2>/dev/null || true
        break
    fi
    sleep 0.5
done

echo "[INFO] Stopping SLAM node ..."
# polite SIGINT → same effect as Ctrl-C inside its own terminal
kill -SIGINT $SLAM_PID 2>/dev/null || true
wait  $SLAM_PID 2>/dev/null || true

echo "[INFO] Stopping roscore ..."
kill -SIGINT $ROSCORE_PID 2>/dev/null || true
wait  $ROSCORE_PID 2>/dev/null || true   # roscore pulls rosout down with it

# the trap will pick up anything that’s still running (e.g. rosbag)
echo "[INFO] FINISHED ${DATASET}/${SEQUENCE} (${MODE})"
echo "[INFO] Logs saved in ${LOG_DIR}"