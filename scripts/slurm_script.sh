#!/bin/bash
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --output="/network/scratch/a/adam.burhan/slurm-%j.out"

module load singularity

rsync -avz $SCRATCH/orb_slam3_ros.sif $SLURM_TMPDIR

rsync -avz $SCRATCH/datasets/ood_slam/euroc_test $SLURM_TMPDIR

singularity exec \
    -B $HOME/projects/ood_slam/orb_ws:/root/orb_ws \
    -B $SLURM_TMPDIR:/root/data \
    $SLURM_TMPDIR/orb_slam3_ros.sif \
    /root/orb_ws/scripts/run_slam.sh euroc_test MH_01_easy mono 

rsync -avz $SLURM_TMPDIR/euroc_test/MH_01_easy/mono/logs $SCRATCH/datasets/ood_slam/euroc_test/MH_01_easy/mono/