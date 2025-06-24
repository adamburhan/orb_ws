import os
import subprocess

DATASETS = {
    "euroc": [
        "MH_01_easy", 
        "MH_03_medium",
        "MH_04_difficult",
        "MH_05_difficult",
        "V1_01_easy",
        "V1_03_difficult",
        "V2_01_easy",
        "V2_02_medium",
        "V2_03_difficult",
        "MH_02_easy",
        "V1_02_medium",
        ],
    # "tum_vi": [
    #     # "dataset-magistrale2_512_16",
    #     # "dataset-magistrale3_512_16",
    #     # "dataset-magistrale4_512_16",
    #     # "dataset-magistrale5_512_16",
    #     # "dataset-magistrale6_512_16",
    #     "dataset-outdoors1_512_16",
    #     "dataset-outdoors2_512_16",
    #     "dataset-outdoors3_512_16",
    #     "dataset-outdoors4_512_16",
    #     "dataset-outdoors5_512_16",
    #     "dataset-outdoors6_512_16",
    #     "dataset-outdoors7_512_16",
    #     "dataset-outdoors8_512_16",
    #     # "dataset-room1_512_16",
    #     # "dataset-room2_512_16",
    #     # "dataset-room3_512_16",
    #     # "dataset-room4_512_16",
    #     # "dataset-room5_512_16",
    #     # "dataset-room6_512_16",
    #     # "dataset-slides1_512_16",
    #     # "dataset-slides2_512_16",
    #     "dataset-slides3_512_16"
    #     ]
}

MODES = ["mono"]

docker_image = "orb_slam3_ros"
data_path = os.path.abspath("data")

for dataset, sequences in DATASETS.items():
    for sequence in sequences:
        for mode in MODES:
            print(f"\nRunning {dataset}/{sequence} in {mode} mode")

            subprocess.run(
                f"xhost +local:docker && docker run --rm "
                f"-v /media/adam/T91/ood_slam_data/datasets:/root/data "
                f"-v /home/adam/Documents/MILA/projects/ood_slam/orb_slam_3_ros/orb_ws:/root/orb_ws "
                f"-e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix "
                f"--net=host {docker_image} bash -c "
                f"'./scripts/run_slam.sh {dataset} {sequence} {mode}'",
                shell=True,
                check=True,
            )


