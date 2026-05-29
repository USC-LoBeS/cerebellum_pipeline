#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/logs/UKBB -j y
#$ -N Cerebnet_UKBB
#$ -V
#$ -l h_vmem=24G,hostslots=1
#$ -q compute9.q
#$ -t 1:7034

export FREESURFER_HOME="/usr/local/freesurfer-8.1.0"
source $FREESURFER_HOME/SetUpFreeSurfer.sh

SUBJECTS=($(cat /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/UKBB_T1w_NIFTI_20252_2_0_paths.txt))
SUBJECT_PATH="${SUBJECTS[$((SGE_TASK_ID-1))]}"
SUBJECT="$(basename "$(dirname "$(dirname "$SUBJECT_PATH")")")"

CEREBNET_DIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data/${SUBJECT}
FS_T1_nu="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_nu.nii.gz"
FS_T1_orig_nu="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig_nu.nii.gz"
FS_T1_orig="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig.nii.gz"
echo "SUBJECT: $SUBJECT"
echo "SUBJECT_PATH: $SUBJECT_PATH"

# Convert nu.mgz to T1 space
if [ ! -e ${FS_T1_nu} ]; then
    ${FREESURFER_HOME}/bin/mri_convert ${CEREBNET_DIR}/mri/nu.mgz ${FS_T1_nu} 
    fslreorient2std ${FS_T1_nu} ${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_nu_std.nii.gz
fi

if [ ! -e ${FS_T1_orig_nu} ]; then
    ${FREESURFER_HOME}/bin/mri_convert ${CEREBNET_DIR}/mri/orig_nu.mgz ${FS_T1_orig_nu}
    fslreorient2std ${FS_T1_orig_nu} ${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig_nu_std.nii.gz
fi

if [ ! -e ${FS_T1_orig} ]; then
    ${FREESURFER_HOME}/bin/mri_convert ${CEREBNET_DIR}/mri/orig.mgz ${FS_T1_orig}
    fslreorient2std ${FS_T1_orig} ${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig_std.nii.gz
fi

fslreorient2std ${CEREBNET_DIR}/mri/cerebellum.CerebNet.nii.gz ${CEREBNET_DIR}/mri/cerebellum.CerebNet_std.nii.gz