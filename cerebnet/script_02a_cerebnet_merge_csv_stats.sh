#!/bin/bash
# CEREBNET: Cerebellum Segmentation combine csvs and generate histograms/boxplots/density
# Author: Sunanda Somu
# Modified: added outlier CSV exports (ROI-level + subject-level)

# ----------- Usage ----------------------------------------------------------------------------------------------------------------------------------
# bash script_02a_cerebnet_merge_csv_stats.sh /path/to/cerebnet_outputs /path/to/QC_dir DatasetName /path/to/python
# ----------------------------------------------------------------------------------------------------------------------------------------------------

if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <INPUT_SUBJECT_DIR> <OUT_DIR> <DATASET_NAME> <PYTHON_PATH>"
    exit 1
fi

INPUT_DIR=$1
OUT_DIR=$2
DATASET_NAME=$3
PYTHON=$4

# ------------------ Output filenames with dataset prefix ------------------
CSV_NAME="${DATASET_NAME}_cerebnet_Cerebellum_Volumes_Combined.csv"
HTML_NAME="${DATASET_NAME}_cerebnet_Cerebellum_QC_Volumes.html"
OUTLIER_ROI_CSV="${DATASET_NAME}_cerebnet_Cerebellum_Outliers_ByROI.csv"
OUTLIER_SUBJECT_CSV="${DATASET_NAME}_cerebnet_Cerebellum_Outliers_BySubject.csv"

OUT_CSV="${OUT_DIR}/${CSV_NAME}"
HTML_QC="${OUT_DIR}/${HTML_NAME}"
OUT_OUTLIER_ROI="${OUT_DIR}/${OUTLIER_ROI_CSV}"
OUT_OUTLIER_SUBJECT="${OUT_DIR}/${OUTLIER_SUBJECT_CSV}"

mkdir -p "${OUT_DIR}"

echo "========================================"
echo "Input directory    : ${INPUT_DIR}"
echo "Combined CSV       : ${OUT_CSV}"
echo "HTML QC report     : ${HTML_QC}"
echo "Outliers by ROI    : ${OUT_OUTLIER_ROI}"
echo "Outliers by Subject: ${OUT_OUTLIER_SUBJECT}"
echo "Python             : ${PYTHON}"
echo "Dataset name       : ${DATASET_NAME}"
echo "========================================"

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory '$INPUT_DIR' does not exist!"
    exit 1
fi

if [ ! -d "$OUT_DIR" ]; then
    echo "Output directory '$OUT_DIR' does not exist. Creating it..."
    mkdir -p "$OUT_DIR"
fi

if ! command -v "$PYTHON" &> /dev/null; then
    echo "Error: Python binary '$PYTHON' not found!"
    exit 1
fi

# ------------------ Run Python ------------------
"${PYTHON}" << EOF
import os
import pandas as pd
import numpy as np
from scipy.stats import gaussian_kde
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.io as pio

PARENT_DIR = "$INPUT_DIR"
DATASET_NAME = "$DATASET_NAME"
OUT_DIR = "$OUT_DIR"
OUT_CSV = "$OUT_CSV"
HTML_QC = "$HTML_QC"
OUT_OUTLIER_ROI = "$OUT_OUTLIER_ROI"
OUT_OUTLIER_SUBJECT = "$OUT_OUTLIER_SUBJECT"

structures = [
    "Left-Cerebellum-White-Matter", "Right-Cerebellum-White-Matter", "Left-Cerebellum-Cortex",
    "Right-Cerebellum-Cortex", "Cbm_Left_I_IV", "Cbm_Right_I_IV", "Cbm_Left_V", "Cbm_Right_V",
    "Cbm_Left_VI", "Cbm_Vermis_VI", "Cbm_Right_VI", "Cbm_Left_CrusI", "Cbm_Right_CrusI",
    "Cbm_Left_CrusII", "Cbm_Right_CrusII", "Cbm_Left_VIIb", "Cbm_Right_VIIb", "Cbm_Left_VIIIa",
    "Cbm_Right_VIIIa", "Cbm_Left_VIIIb", "Cbm_Right_VIIIb", "Cbm_Left_IX", "Cbm_Vermis_IX",
    "Cbm_Right_IX", "Cbm_Left_X", "Cbm_Vermis_X", "Cbm_Right_X", "Cbm_Vermis_VII", "Cbm_Vermis_VIII",
    "Cbm_Vermis"
]

# ------------------ Parse subject stats ------------------
all_data = []
print("Scanning subject folders...")
for subject_dir in sorted(os.listdir(PARENT_DIR)):
    subject_path = os.path.join(PARENT_DIR, subject_dir)
    if not os.path.isdir(subject_path):
        continue

    stats_file = os.path.join(subject_path, 'stats', 'cerebellum.CerebNet.stats')
    if os.path.isfile(stats_file):
        subject_data = {'SubjectID': subject_dir, 'StatsFilePath': stats_file}

        with open(stats_file, 'r') as f:
            lines = f.readlines()

        for line in lines:
            columns = line.split()
            if len(columns) == 10 and columns[0].isdigit():
                struct_name = columns[4]
                if struct_name in structures:
                    subject_data[f"{struct_name}_NVoxels"]    = columns[2]
                    subject_data[f"{struct_name}_Volume_mm3"] = columns[3]
                    subject_data[f"{struct_name}_normMean"]   = columns[5]
                    subject_data[f"{struct_name}_normStdDev"] = columns[6]
                    subject_data[f"{struct_name}_normMin"]    = columns[7]
                    subject_data[f"{struct_name}_normMax"]    = columns[8]
                    subject_data[f"{struct_name}_normRange"]  = columns[9]

        all_data.append(subject_data)
    else:
        print(f"Stats file not found for {subject_dir}, skipping...")

# ------------------ Combined CSV ------------------
df = pd.DataFrame(all_data)
df.to_csv(OUT_CSV, index=False)
print(f"\nCombined CSV written to: {OUT_CSV}")

# ------------------ Outlier detection (shared logic) ------------------
# Returns dict: { struct: { 'lower': float, 'upper': float, 'outlier_mask': Series } }
def compute_iqr_bounds(vals):
    Q1 = np.percentile(vals, 25)
    Q3 = np.percentile(vals, 75)
    IQR = Q3 - Q1
    return Q1 - 1.5 * IQR, Q3 + 1.5 * IQR

roi_outlier_records = []    # one row per ROI
subject_outlier_map = {}    # SubjectID -> list of ROIs where they're an outlier

for struct in structures:
    col = struct + "_Volume_mm3"
    if col not in df.columns:
        continue
    vals = pd.to_numeric(df[col], errors='coerce').dropna()
    if len(vals) == 0:
        continue

    Q1 = np.percentile(vals, 25)
    Q3 = np.percentile(vals, 75)
    IQR = Q3 - Q1
    median = float(np.median(vals))
    lower, upper = Q1 - 1.5 * IQR, Q3 + 1.5 * IQR

    outlier_mask = (vals < lower) | (vals > upper)
    outlier_indices = vals[outlier_mask].index
    outlier_subjects = df.loc[outlier_indices, "SubjectID"].tolist()
    outlier_values   = vals[outlier_mask].tolist()

    # ROI-level record
    roi_outlier_records.append({
        "ROI":              struct,
        "N_Total":          len(vals),
        "N_Outliers":       len(outlier_subjects),
        "Pct_Outliers":     round(100 * len(outlier_subjects) / len(vals), 2),
        "Median_mm3":       round(median, 4),
        "Q1_mm3":           round(float(Q1), 4),
        "Q3_mm3":           round(float(Q3), 4),
        "IQR_mm3":          round(float(IQR), 4),
        "Lower_Fence_mm3":  round(float(lower), 4),
        "Upper_Fence_mm3":  round(float(upper), 4),
        "Outlier_SubjectIDs": "|".join(outlier_subjects),
        "Outlier_Volumes_mm3": "|".join([str(round(v, 4)) for v in outlier_values]),
    })

    # Subject-level accumulation
    for subj in outlier_subjects:
        subject_outlier_map.setdefault(subj, []).append(struct)

# ------------------ Outlier by ROI CSV ------------------
df_roi_outliers = pd.DataFrame(roi_outlier_records)
df_roi_outliers.to_csv(OUT_OUTLIER_ROI, index=False)
print(f"Outlier-by-ROI CSV written to: {OUT_OUTLIER_ROI}")

# ------------------ Outlier by Subject CSV ------------------
# Every subject in df gets a row; subjects with zero outlier ROIs get empty fields.
subject_rows = []
for _, row in df.iterrows():
    subj = row["SubjectID"]
    flagged_rois = subject_outlier_map.get(subj, [])
    subject_rows.append({
        "SubjectID":        subj,
        "N_Outlier_ROIs":   len(flagged_rois),
        "Outlier_ROIs":     "|".join(flagged_rois),   # pipe-delimited so CSV stays clean
    })

df_subject_outliers = pd.DataFrame(subject_rows)
df_subject_outliers.to_csv(OUT_OUTLIER_SUBJECT, index=False)
print(f"Outlier-by-Subject CSV written to: {OUT_OUTLIER_SUBJECT}")

# ------------------ HTML QC (unchanged logic, uses same bounds) ------------------
print("\nGenerating QC Volumes HTML...")
html_strings = []
for struct in structures:
    col = struct + "_Volume_mm3"
    if col not in df.columns:
        continue
    vals = pd.to_numeric(df[col], errors='coerce').dropna()
    n = len(vals)
    if n == 0:
        continue

    Q1 = np.percentile(vals, 25)
    Q3 = np.percentile(vals, 75)
    IQR = Q3 - Q1
    median = np.median(vals)
    lower_bound = Q1 - 1.5 * IQR
    upper_bound = Q3 + 1.5 * IQR
    outliers = vals[(vals < lower_bound) | (vals > upper_bound)]

    fig = make_subplots(
        rows=1, cols=2,
        subplot_titles=("Histogram + Density + Outliers", "Boxplot"),
        horizontal_spacing=0.15
    )

    fig.add_trace(
        go.Histogram(x=vals, nbinsx=40, marker_color='cyan',
                     name='Histogram', opacity=0.6, histnorm='probability density'),
        row=1, col=1
    )

    density = gaussian_kde(vals)
    x_vals = np.linspace(vals.min(), vals.max(), 200)
    y_vals = density(x_vals)
    fig.add_trace(
        go.Scatter(x=x_vals, y=y_vals, mode='lines',
                   line=dict(color='magenta', width=4), name='Density'),
        row=1, col=1
    )

    if len(outliers) > 0:
        outlier_indices = vals[(vals < lower_bound) | (vals > upper_bound)].index
        outlier_subjects = df.loc[outlier_indices, "SubjectID"]
        fig.add_trace(
            go.Scatter(
                x=outliers, y=[0]*len(outliers), mode='markers',
                marker=dict(color='red', size=8, symbol='x'),
                name='Outliers', customdata=outlier_subjects,
                hovertemplate="Volume: %{x}<br>Subject: %{customdata}<extra></extra>"
            ),
            row=1, col=1
        )

    fig.add_trace(
        go.Box(
            y=vals, boxpoints='outliers', marker_color='orange',
            customdata=df.loc[vals.index, ["SubjectID", "StatsFilePath"]],
            hovertemplate="Volume: %{y}<br>Subject: %{customdata[0]}<br>",
            name='Boxplot'
        ),
        row=1, col=2
    )

    fig.add_annotation(
        x=0.5, y=1.05, xref='paper', yref='paper',
        text=f"IQR: {IQR:.2f}, Median: {median:.2f}",
        showarrow=False, font=dict(size=12, color='white')
    )

    fig.update_xaxes(title_text="Volume (mm³)", row=1, col=1)
    fig.update_yaxes(title_text="Probability Density", row=1, col=1)
    fig.update_yaxes(title_text="Volume (mm³)", row=1, col=2)
    fig.update_xaxes(title_text="", row=1, col=2)
    fig.update_layout(
        title_text=f"{DATASET_NAME} — {struct} (N={n})",
        template='plotly_dark', width=1400, height=600,
        showlegend=False, margin=dict(l=100, r=100, t=120, b=80)
    )

    html_strings.append(pio.to_html(fig, full_html=False, include_plotlyjs='cdn'))

full_html = f"""
<html>
<head>
    <title>{DATASET_NAME} — Cerebellum QC Report</title>
</head>
<body style="background-color:#1e1e1e; color:white;">
    <h1>{DATASET_NAME} — Cerebellum Volume QC Report</h1>
    {"<hr style='border-color:white;'>".join(html_strings)}
</body>
</html>
"""

with open(HTML_QC, 'w') as f:
    f.write(full_html)

print(f"HTML QC report written to: {HTML_QC}")
print("\nDone.")
EOF