#!/bin/bash
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output="/network/scratch/a/adam.burhan/run_slam_rover_slurm-%A_%a.out"
#SBATCH --array=0-38%10

module load singularity


sequences=(
        "campus_large_autumn_2023-11-07"
        "campus_large_day_2024-09-25"
        "campus_large_dusk_2024-09-24_2"
        "campus_large_night_2024-09-24_3"
        "campus_large_night-light_2024-09-24_4"
        "campus_large_spring_2024-04-14"
        "campus_large_summer_2023-07-20"
        "campus_large_winter_2024-01-27"
        "campus_small_autumn_2023-11-23"
        "campus_small_day_2024-05-07"
        "campus_small_dusk_2024-05-08_1"
        "campus_small_night_2024-05-08_2"
        "campus_small_night-light_2024-05-24_1"
        "campus_small_spring_2024-04-14"
        "campus_small_summer_2023-09-11"
        "campus_small_winter_2024-02-19"
        "garden_large_autumn_2023-12-21"
        "garden_large_day_2024-05-29_1"
        "garden_large_dusk_2024-05-29_2"
        "garden_large_night_2024-05-30_1"
        "garden_large_night-light_2024-05-30_2"
        "garden_large_spring_2024-04-11"
        "garden_large_summer_2023-08-18"
        "garden_large_winter_2024-01-13"
        "garden_small_autumn_2023-09-15"
        "garden_small_day_2024-05-29_1"
        "garden_small_dusk_2024-05-29_2"
        "garden_small_night_2024-05-29_3"
        "garden_small_night-light_2024-05-29_4"
        "garden_small_spring_2024-04-11"
        "garden_small_summer_2023-08-18"
        "garden_small_winter_2024-01-13"
        "park_autumn_2023-11-07"
        "park_day_2024-05-08"
        "park_dusk_2024-05-13_1"
        "park_night_2024-05-13_2"
        "park_night-light_2024-05-24_2"
        "park_spring_2024-04-14"
        "park_summer_2023-07-31"
)

idx=$SLURM_ARRAY_TASK_ID

if [ "$idx" -ge "${#sequences[@]}" ]; then
    echo "Invalid SLURM_ARRAY_TASK_ID: $idx"
    exit 1
fi

sequence=${sequences[$idx]}

rsync -avz $SCRATCH/orb_slam3_ros.sif $SLURM_TMPDIR

mkdir -p $SLURM_TMPDIR/rover/bags
rsync -avz $SCRATCH/datasets/ood_slam/rover/bags/${sequence}.bag $SLURM_TMPDIR/rover/bags/

singularity exec \
    -B $HOME/projects/ood_slam/orb_ws:/root/orb_ws \
    -B $SLURM_TMPDIR:/root/data \
    $SLURM_TMPDIR/orb_slam3_ros.sif \
    /root/orb_ws/scripts/rover/run_slam_rover.sh rover ${sequence} mono 


mkdir -p $SCRATCH/datasets/ood_slam/rover/${sequence}/mono/   

rsync -avz $SLURM_TMPDIR/rover/${sequence}/mono/logs $SCRATCH/datasets/ood_slam/rover/${sequence}/mono/