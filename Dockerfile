FROM amd64/ros:noetic-perception-focal

ARG DEBIAN_FRONTEND=noninteractive
ARG ROS_DISTRO=noetic
ARG SYNC_DATESTAMP=final

# Replace broken repo key & URL
RUN rm -f /etc/apt/sources.list.d/ros1-latest.list \
    && echo "deb [signed-by=/usr/share/keyrings/ros1-snapshot.gpg] \
        http://snapshots.ros.org/noetic/final/ubuntu focal main" \
       > /etc/apt/sources.list.d/ros1-snapshot.list \
    && (apt-key del F42ED6FBAB17C654 || true) \
    && set -eux; \
       key='4B63CF8FDE49746E98FA01DDAD19BAB3CBF125EA'; \
       export GNUPGHOME="$(mktemp -d)"; \
       gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
       mkdir -p /usr/share/keyrings; \
       gpg --batch --export "$key" > /usr/share/keyrings/ros1-snapshot.gpg; \
       gpgconf --kill all; rm -rf "$GNUPGHOME"


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

# script to run the whole pipeline
COPY scripts/run_slam.sh /root/scripts/run_slam.sh
RUN chmod +x scripts/run_slam.sh

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