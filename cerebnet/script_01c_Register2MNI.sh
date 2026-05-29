#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/logs/UKBB -j y
#$ -N Cerebnet_UKBB_2MNI
#$ -V
#$ -l h_vmem=24G,hostslots=1
#$ -q compute9.q
#$ -t 1:7034

export ANTSPATH="/usr/local/ANTs_2.2.0/bin/bin/"

SUBJECTS=($(cat /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/UKBB_T1w_NIFTI_20252_2_0_paths.txt))
SUBJECT_PATH="${SUBJECTS[$((SGE_TASK_ID-1))]}"
SUBJECT="$(basename "$(dirname "$(dirname "$SUBJECT_PATH")")")"

CEREBNET_DIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data/${SUBJECT}
FS_T1_nu_std="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_nu_std.nii.gz"
FS_T1_orig_nu_std="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig_nu_std.nii.gz"
FS_T1_orig_std="${CEREBNET_DIR}/mri/${SUBJECT}_FS_T1_orig_std.nii.gz"

#### FSL MNI Template with trilinear interpolation
# mni=/usr/local/fsl-5.0.9/data/standard/MNI152_T1_1mm.nii.gz

# OUTPUT_DIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data/${SUBJECT}/mni_trilinear
# rm -rf ${OUTPUT_DIR}
# mkdir -p ${OUTPUT_DIR}

# echo "SUBJECT: $SUBJECT"
# echo "SUBJECT_PATH: $SUBJECT_PATH"
# echo "MNI: ${mni}"

# if [ -e ${FS_T1_orig_nu_std} ]; then

#     cmd="flirt -dof 6 -cost normmi -interp trilinear -in ${FS_T1_orig_nu_std} -ref ${mni} -omat ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat  -out ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.nii.gz"
#     echo $cmd
#     eval $cmd

#     #convert linear xfm to IRK format for ANTs
#     cmd="/ifshome/jfaskow/programs/c3d-1.0.0-Linux-x86_64/bin/c3d_affine_tool -ref ${mni} -src ${FS_T1_orig_nu_std} ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat -fsl2ras -oitk ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt" 
#     echo $cmd
#     eval $cmd

# fi

# ### Cerebellum Segmentation to MNI
# cmd="${ANTSPATH}/antsApplyTransforms -d 3 --float -n NearestNeighbor -i ${CEREBNET_DIR}/mri/cerebellum.CerebNet_std.nii.gz -r ${mni} -o ${OUTPUT_DIR}/cerebellum.CerebNet_std_2MNI.nii.gz -t ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt "
# echo $cmd
# eval $cmd
# echo "Done moving ${OUTPUT_DIR}/cerebellum.CerebNet_std.nii.gz to MNI"

#### FSL MNI Template with spline interpolation
# mni=/usr/local/fsl-5.0.9/data/standard/MNI152_T1_1mm.nii.gz

# OUTPUT_DIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data/${SUBJECT}/mni
# rm -rf ${OUTPUT_DIR}
# mkdir -p ${OUTPUT_DIR}

# echo "SUBJECT: $SUBJECT"
# echo "SUBJECT_PATH: $SUBJECT_PATH"
# echo "MNI: ${mni}"

# if [ -e ${FS_T1_orig_nu_std} ]; then

#     cmd="flirt -dof 6 -cost normmi -interp spline -in ${FS_T1_orig_nu_std} -ref ${mni} -omat ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat  -out ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.nii.gz"
#     echo $cmd
#     eval $cmd

#     #convert linear xfm to IRK format for ANTs
#     cmd="/ifshome/jfaskow/programs/c3d-1.0.0-Linux-x86_64/bin/c3d_affine_tool -ref ${mni} -src ${FS_T1_orig_nu_std} ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat -fsl2ras -oitk ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt" 
#     echo $cmd
#     eval $cmd

# fi

# ### Cerebellum Segmentation to MNI
# cmd="${ANTSPATH}/antsApplyTransforms -d 3 --float -n NearestNeighbor -i ${CEREBNET_DIR}/mri/cerebellum.CerebNet_std.nii.gz -r ${mni} -o ${OUTPUT_DIR}/cerebellum.CerebNet_std_2MNI.nii.gz -t ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt "
# echo $cmd
# eval $cmd
# echo "Done moving ${OUTPUT_DIR}/cerebellum.CerebNet_std.nii.gz to MNI"



mni=/scratch/faculty/njahansh/projects/cerebellum_segmentation/mni_icbm152_t1_tal_nlin_sym_09c.nii

OUTPUT_DIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/cerebnet/UKBB/data/${SUBJECT}/mni_ICBM
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}

echo "SUBJECT: $SUBJECT"
echo "SUBJECT_PATH: $SUBJECT_PATH"
echo "MNI: ${mni}"

if [ -e ${FS_T1_orig_nu_std} ]; then

    cmd="flirt -dof 6 -cost normmi -interp trilinear -in ${FS_T1_orig_nu_std} -ref ${mni} -omat ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat  -out ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.nii.gz"
    echo $cmd
    eval $cmd

    #convert linear xfm to IRK format for ANTs
    cmd="/ifshome/jfaskow/programs/c3d-1.0.0-Linux-x86_64/bin/c3d_affine_tool -ref ${mni} -src ${FS_T1_orig_nu_std} ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI.mat -fsl2ras -oitk ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt" 
    echo $cmd
    eval $cmd

fi

### Cerebellum Segmentation to MNI
cmd="${ANTSPATH}/antsApplyTransforms -d 3 --float -n NearestNeighbor -i ${CEREBNET_DIR}/mri/cerebellum.CerebNet_std.nii.gz -r ${mni} -o ${OUTPUT_DIR}/cerebellum.CerebNet_std_2MNI.nii.gz -t ${OUTPUT_DIR}/${SUBJECT}_FS_T1_orig_nu_std_2MNI_ITK.txt "
echo $cmd
eval $cmd
echo "Done moving ${OUTPUT_DIR}/cerebellum.CerebNet_std.nii.gz to MNI"




