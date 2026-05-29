#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/logs/UKBB -j y
#$ -N Cerebnet_UKBB
#$ -V
#$ -l h_vmem=24G,hostslots=1
#$ -q compute9.q
#$ -t 1:7034


SUBJECTS=($(cat /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/UKBB_T1w_NIFTI_20252_2_0_paths.txt))
# SUBJECT_PATH="${SUBJECTS[$((SGE_TASK_ID-1))]}"
SUBJECT_PATH=/ifs/loni/faculty/njahansh/datasets/UKBB/dataset/unzipped/T1w_NIFTI_20252_2_0/1306688_20252_2_0/T1/T1.nii.gz
SUBJECT="$(basename "$(dirname "$(dirname "$SUBJECT_PATH")")")"


echo "Running CerebNet for SUBJECT: $SUBJECT"
echo "SUBJECT_PATH: $SUBJECT_PATH"

cmd="apptainer exec --no-home \
  -B /ifs/loni/faculty:/ifs/loni/faculty \
  -B /scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data:/output \
  -B /usr/local/freesurfer-8.1.0:/fs \
  /scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/apptainers/fastsurfer-cpu-v2.4.2.sif \
  /fastsurfer/run_fastsurfer.sh \
  --fs_license /fs/license.txt \
  --sid \"$SUBJECT\" --sd /output --t1 \"$SUBJECT_PATH\" \
  --seg_only \
  --no_hypothal \
  --threads 4 \
  --tal_reg \
  --3T"

echo "Executing:"
echo "$cmd"
eval "$cmd"
