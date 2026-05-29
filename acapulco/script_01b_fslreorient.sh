#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/logs/UKBB_T1w_NIFTI_20252_2_0 -j y
#$ -N AP3_UKBB
#$ -V
#$ -l h_vmem=24G,hostslots=2
#$ -q compute9.q
#$ -t 1:7034

printf "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+\n"
printf "FSL Reorient AC3 Outputs\n"
printf "Written by Sunanda \n"
printf "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+\n"
SUBJECTS=($(cat /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/UKBB_T1w_NIFTI_20252_2_0_paths.txt))
SUBJECT_PATH="${SUBJECTS[$((SGE_TASK_ID-1))]}"
SUBJECT="$(basename "$(dirname "$(dirname "$SUBJECT_PATH")")")"
echo "Running fslreorient on ${SUBJECT}"

fslreorient2std /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/${SUBJECT}/mni/T1_n4_mni.nii.gz /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/${SUBJECT}/mni/T1_n4_mni_std.nii.gz
fslreorient2std /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/${SUBJECT}/parc/T1_n4_mni_seg_post.nii.gz /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/${SUBJECT}/parc/T1_n4_mni_seg_post_std.nii.gz

echo "Done fslreorient on ${SUBJECT}"
