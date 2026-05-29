# Cerebellum Segmentation and QC Pipeline

Quality-control pipeline for cerebellar segmentation of UK Biobank T1w scans (N = 7034), run with two segmentation tools — **ACAPULCO 3.0** and **CerebNet** (FastSurfer). Both pipelines share the same three-stage structure: segment → merge volumes & flag outliers → generate slice PNGs → review in an interactive HTML viewer.

A full write-up of each step, the bounding boxes, slice numbers, and QC logic is in `Cerebellum_Segmentation_QC.pdf`.

> All scripts are written to run on the USC Grid (SGE array jobs / Apptainer–Singularity containers) and use absolute paths. Adapt scripts before running elsewhere.

## Pipeline

Both pipelines operate in **MNI space** — ACAPULCO natively, CerebNet after registration to the ICBM 2009c template — so they share bounding boxes, slice numbers and QC logic.

### ACAPULCO

| Step | Script | What it does |
|------|--------|--------------|
| 1  | `script_01_AC3_UKBB.sh` | Runs ACAPULCO 3.0 (Singularity): N4 bias correction, MNI registration, deep-learning cerebellar parcellation. |
| 1b | `script_01b_fslreorient.sh` | `fslreorient2std` on the MNI T1 and parcellation for consistent orientation. |
| 2a | `script_02a_acapulco_merge_csv_stats.sh` | Merges per-subject volume CSVs, detects IQR outliers (per-ROI + per-subject), builds the volume-QC HTML. |
| 2b | `script_02b_acapulco_png_generator.sh` | Renders axial/coronal/sagittal PNGs (T1 + parcellation overlay), dynamic cerebellum FOV crop, bounding-box failure log. Github also includes the colomap.txt used to generate pngs. |
| 3  | `script_03_acapulco_make_html.sh` | Batched interactive HTML review pages (3 coronal + 3 sagittal per subject) with Pass/Fail/Flag, failure classification, notes, pre-computed flags, CSV export. |

### CerebNet

| Step | Script | What it does |
|------|--------|--------------|
| 1  | `script_01_Run_Cerebnet.sh` | Runs FastSurfer v2.4.2 (Apptainer), segmentation-only, to produce the CerebNet parcellation and volume stats. |
| 1b | `script_01b_Convert2nii.sh` | Converts FreeSurfer MGZ outputs to NIfTI (`mri_convert`) and applies `fslreorient2std`. |
| 1c | `script_01c_Register2MNI.sh` | Registers T1 to ICBM 2009c (FSL `flirt`, 6 DOF, trilinear interpolation) and warps the segmentation into MNI space (ANTs, nearest-neighbor). GitHub upload includes the ICBM nonlin symmetric template used for bringing cerebNet outputs to MNI space|
| 2a | `script_02a_cerebnet_merge_csv_stats.sh` | Parses `cerebellum.CerebNet.stats`, merges volumes, detects IQR outliers, builds the volume-QC HTML. |
| 2b | `script_02b_cerebnet_png_generator.sh` | Same as ACAPULCO PNG step, reading the MNI-registered ICBM files and rendering with the FreeSurfer LUT (uploaded to GitHub). |
| 3  | `script_03_cerebnet_make_html.sh` | Same batched HTML review builder as ACAPULCO, run on the CerebNet PNGs. |

## Outputs

- **Combined volume CSV** — one row per subject, all cerebellar ROIs.
- **Outlier CSVs** — `*_Outliers_ByROI.csv` and `*_Outliers_BySubject.csv` (IQR × 1.5 rule).
- **Volume-QC HTML** — per-ROI histogram + KDE + boxplot with outlier markers.
- **Slice PNGs** — per subject, per view, for visual QC.
- **Review HTML** — batched (600 subjects/batch), one subject per row, with Pass/Fail/Flag controls and a downloadable notes CSV.

## Requirements

ACAPULCO 3.0 (Singularity image), FastSurfer v2.4.2 (Apptainer image), FreeSurfer 8.1.0, FSL, ANTs, and Python with `pandas`, `numpy`, `scipy`, and `plotly`.

## Author

Sunanda Somu
