FROM amd64/ros:noetic-perception-focal

ARG DEBIAN_FRONTEND=noninteractive
ARG ROS_DISTRO=noetic

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        git \
        build-essential \
        cmake \
        libeigen3-dev \
        ros-${ROS_DISTRO}-hector-trajectory-server \
        python3-catkin-tools \
        python3-pip \
        libepoxy-dev \
        libopencv-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

WORKDIR /root 

# Install Pangolin
RUN git clone --branch v0.9 --depth 1 https://github.com/stevenlovegrove/Pangolin.git && \
    cd Pangolin && \
    mkdir build && cd build && \
    cmake .. && \
    make -j && \
    make install


 # Python dependencies
COPY requirements.txt /root/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /root/requirements.txt


#
# install RealSenseSDK / RealSense ROS wrapper
#

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE || apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key F6E65AC044F831AC80A06380C8B3A55A6F3EFCDE
RUN add-apt-repository "deb https://librealsense.intel.com/Debian/apt-repo $(lsb_release -sc) main"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libssl-dev \
        libudev-dev \
        libusb-1.0-0-dev \
        librealsense2-dev \
        librealsense2-utils \
        ros-${ROS_DISTRO}-realsense2-camera &&  \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean