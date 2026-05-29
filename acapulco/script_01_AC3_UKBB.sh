#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/logs/UKBB_T1w_NIFTI_20252_2_0 -j y
#$ -N AP3_UKBB
#$ -V
#$ -l h_vmem=24G,hostslots=2
#$ -q compute9.q
#$ -t 1:7034

printf "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+\n"
printf "qsub wrapper for ACUPULCO 3.0 Cerebellum Segmentation\n"
printf "Written by Sunanda \n"
printf "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+\n"
SUBJECTS=(`cat /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/UKBB_T1w_NIFTI_20252_2_0_paths.txt`)
SUBJECT_PATH=${SUBJECTS[${SGE_TASK_ID}-1]}
echo $SUBJECT_PATH
SUBJECT=$(basename "$(dirname "$(dirname "$SUBJECT_PATH")")")
echo "Running ACUPULCO 3 for ${SUBJECT}"

# Output Directory
JOBBASEDIR=/scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/${SUBJECT}
rm -rf $JOBBASEDIR
mkdir -p $JOBBASEDIR

CMD="singularity run --cleanenv -B /ifs/loni/faculty:/ifs/loni/faculty -B /scratch/faculty:/scratch/faculty /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/scripts/source/acapulco_030.sif -i ${SUBJECT_PATH} -o ${JOBBASEDIR}"
echo "Running: ${CMD}" 
eval $CMD

chmod -R 755 $JOBBASEDIR
echo "ACUPULCO outputs available for ${SUBJECT}"
