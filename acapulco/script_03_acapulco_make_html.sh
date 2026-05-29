#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/logs/UKBB_HTML_GEN -j y
#$ -N ACAPULCO_HTMLGEN
#$ -V
#$ -q compute9.q,iniadm9.q,runnow9.q

# Cerebellum Segmentation QC: HTML
# Author: Sunanda Somu

#==============================================================================
# CONFIGURATION — edit slice numbers here
#==============================================================================

CORONAL_SLICES=(68 75 85)   
SAGITTAL_SLICES=(70 84 91)      

BATCH_SIZE=600

#==============================================================================
# USAGE
#==============================================================================
# ./script_03_acapulco_make_html.sh /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/QC/pngs/ 
# /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/QC/ 
# UKBB 
# /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/QC/UKBB_acapulco_Cerebellum_Outliers_BySubject.csv 
# /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/QC/bounding_box_failures.txt


function Usage(){
    cat << USAGE

Cerebellum Segmentation QC: HTML

Generates one HTML per batch. Each subject row shows 3 coronal + 3 sagittal
slices in a single grid. Requires an outlier-by-subject CSV from script_02a
and a bounding-box fail list; both shown as badges per subject and written
as columns in the downloaded CSV.

Usage:
    bash $(basename "$0") <png_dir> <output_dir> <dataset> <outlier_subject_csv> <bbox_fail_txt>

Arguments:
    png_dir              : Directory containing PNG slice images (expects pngs/<SubjectID>/ layout)
    output_dir           : Directory where HTML files will be saved
    dataset              : Dataset name prefix (e.g. UKBB, HCP, ADNI)
    outlier_subject_csv  : Path to *_Outliers_BySubject.csv from script_02a.
                           Columns expected: SubjectID, N_Outlier_ROIs, Outlier_ROIs
    bbox_fail_txt        : Plain-text file, one SubjectID per line, for subjects that failed bounding box QC

Output:
    If subjects <= BATCH_SIZE:
      - <output_dir>/<dataset>_acapulco_Cerebellum_QC_brainslice.html
      - (downloadable) <dataset>_acapulco_Cerebellum_QC_notes.csv
    If subjects > BATCH_SIZE:
      - <output_dir>/<dataset>_acapulco_Cerebellum_QC_brainslice_batch{N}.html
      - (downloadable) <dataset>_acapulco_Cerebellum_QC_notes_batch{N}.csv

USAGE
    exit 1
}

if [[ "$1" == "--help" || "$1" == "-h" || $# -lt 5 ]]; then
    Usage
fi

#==============================================================================
# PARSE ARGUMENTS
#==============================================================================

PNG_DIR="$1"
OUTPUT_DIR="$2"
DATASET="$3"
OUTLIER_CSV="$4"
BBOX_TXT="$5"

PNG_DIR=$(realpath "$PNG_DIR")
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")
OUTLIER_CSV=$(realpath "$OUTLIER_CSV")
BBOX_TXT=$(realpath "$BBOX_TXT")

#==============================================================================
# VALIDATE
#==============================================================================

if [[ ! -d "$PNG_DIR" ]]; then
    echo "Error: PNG directory not found: $PNG_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

SUBJECT_DIRS=($(ls -d "${PNG_DIR}"/*/ 2>/dev/null | sort))
if [[ ${#SUBJECT_DIRS[@]} -eq 0 ]]; then
    echo "Error: No subject directories found in: $PNG_DIR"
    exit 1
fi

# ------------------ Parse outlier CSV ------------------
if [[ ! -f "$OUTLIER_CSV" ]]; then
    echo "Error: Outlier CSV not found: $OUTLIER_CSV"
    exit 1
fi

declare -A outlier_map

echo "Loading outlier data from: $OUTLIER_CSV"
while IFS=',' read -r subj n_rois roi_list; do
    subj=$(echo "$subj"         | tr -d '"')
    n_rois=$(echo "$n_rois"     | tr -d '"')
    roi_list=$(echo "$roi_list" | tr -d '"' | tr -d '\r')
    outlier_map["$subj"]="${n_rois}|${roi_list}"
done < <(tail -n +2 "$OUTLIER_CSV")
echo "  Loaded outlier data for ${#outlier_map[@]} subjects."

# ------------------ Parse bounding box fail list ------------------
if [[ ! -f "$BBOX_TXT" ]]; then
    echo "Error: Bounding box fail list not found: $BBOX_TXT"
    exit 1
fi

declare -A bbox_fail_set

echo "Loading bounding box fail list from: $BBOX_TXT"
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\r' | xargs)   # strip CR and whitespace
    [[ -z "$line" ]] && continue
    bbox_fail_set["$line"]=1
done < "$BBOX_TXT"
echo "  Loaded ${#bbox_fail_set[@]} bounding box failures."

TOTAL_SUBJECTS=${#SUBJECT_DIRS[@]}
TOTAL_BATCHES=$(( (TOTAL_SUBJECTS + BATCH_SIZE - 1) / BATCH_SIZE ))

echo "============================================================"
echo "CEREBELLUM QC HTML GENERATOR"
echo "============================================================"
echo "PNG Directory    : $PNG_DIR"
echo "Output Dir       : $OUTPUT_DIR"
echo "Dataset          : $DATASET"
echo "Subjects         : $TOTAL_SUBJECTS"
echo "Batch Size       : $BATCH_SIZE"
echo "Total Batches    : $TOTAL_BATCHES"
echo "Coronal slices   : ${CORONAL_SLICES[*]}"
echo "Sagittal slices  : ${SAGITTAL_SLICES[*]}"
echo "Outlier CSV      : $OUTLIER_CSV"
echo "BBox fail list   : $BBOX_TXT"
echo "============================================================"
echo ""

#==============================================================================
# Helper: build a JSON array from a bash array of integers
#==============================================================================
build_int_json_array() {
    local -n _arr=$1
    local json="["
    local first=true
    for v in "${_arr[@]}"; do
        [[ "$first" == true ]] && first=false || json+=","
        json+="$v"
    done
    json+="]"
    echo "$json"
}

#==============================================================================
# BATCH LOOP — one HTML per batch
#==============================================================================

for (( BATCH_NUM=1; BATCH_NUM<=TOTAL_BATCHES; BATCH_NUM++ )); do

    START_IDX=$(( (BATCH_NUM - 1) * BATCH_SIZE ))
    END_IDX=$(( BATCH_NUM * BATCH_SIZE ))
    [[ $END_IDX -gt $TOTAL_SUBJECTS ]] && END_IDX=$TOTAL_SUBJECTS

    BATCH_SUBJECTS=("${SUBJECT_DIRS[@]:$START_IDX:$((END_IDX - START_IDX))}")
    BATCH_COUNT=${#BATCH_SUBJECTS[@]}

    if [ $TOTAL_BATCHES -eq 1 ]; then
        OUTPUT_HTML="${OUTPUT_DIR}/${DATASET}_acapulco_Cerebellum_QC_brainslice.html"
        CSV_FILENAME="${DATASET}_acapulco_Cerebellum_QC_notes.csv"
        BATCH_LABEL=""
    else
        OUTPUT_HTML="${OUTPUT_DIR}/${DATASET}_acapulco_Cerebellum_QC_brainslice_batch${BATCH_NUM}.html"
        CSV_FILENAME="${DATASET}_acapulco_Cerebellum_QC_notes_batch${BATCH_NUM}.csv"
        BATCH_LABEL=" — Batch ${BATCH_NUM}/${TOTAL_BATCHES}"
    fi

    echo "Batch ${BATCH_NUM}/${TOTAL_BATCHES}: subjects ${START_IDX}–$((END_IDX-1))  (${BATCH_COUNT} subjects)"
    echo "  → $(basename "$OUTPUT_HTML")"

    # --------------------------------------------------------------------------
    # Write HTML template
    # --------------------------------------------------------------------------
    cat > "$OUTPUT_HTML" << 'HTML_TEMPLATE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cerebellum QC — DATASET_PLACEHOLDER BATCH_LABEL_PLACEHOLDER</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #000;
            padding: 10px;
        }

        /* ---- Sticky header ---- */
        .header {
            position: sticky; top: 0; z-index: 100;
            background: #000; border: 1px solid #333; color: #fff;
            padding: 10px 15px; border-radius: 5px; margin-bottom: 10px;
            display: flex; justify-content: space-between; align-items: center; gap: 15px;
        }
        .header-left { display: flex; align-items: center; gap: 15px; }
        .header-left h1 { font-size: 1.2em; white-space: nowrap; }
        .header-left .subtitle { font-size: 0.85em; opacity: 0.8; }
        .header-right { display: flex; gap: 10px; align-items: center; }

        .btn { padding: 8px 16px; border: none; border-radius: 5px; font-size: 0.9em;
               cursor: pointer; font-weight: 600; transition: all 0.2s; white-space: nowrap; }
        .btn-success { background: #28a745; color: #fff; }
        .btn-success:hover { background: #218838; }
        .save-indicator { padding: 5px 12px; border-radius: 4px; font-size: 0.85em;
                           font-weight: 600; background: #d4edda; color: #155724; }

        /* ---- Subject rows ---- */
        .subject-row {
            background: #000; border: 1px solid #333;
            margin-bottom: 10px; padding: 15px; border-radius: 5px;
            border-left: 4px solid transparent;
        }

        /* Pre-computed flags — set via data-flags attribute */
        .subject-row[data-flags~="bbox"]    { border-left: 4px solid #cc44ff; background: #0d0018; }
        .subject-row[data-flags~="outlier"] { border-left: 4px solid #ff8c00; background: #110800; }

        /* Both flags: gradient border trick */
        .subject-row[data-flags~="bbox"][data-flags~="outlier"] {
            border-left: 4px solid transparent;
            background:
                linear-gradient(#0d0010, #0d0010) padding-box,
                linear-gradient(to bottom, #cc44ff 50%, #ff8c00 50%) border-box;
        }

        /* Rater decisions always override flag colors */
        .subject-row.failed  { background: #1a0000 !important; border-left: 4px solid #dc3545 !important; }
        .subject-row.flagged { background: #1a1a00 !important; border-left: 4px solid #ffc107 !important; }

        .subject-header {
            display: grid;
            grid-template-columns: 200px 260px 240px 1fr;
            gap: 10px; align-items: start;
            margin-bottom: 12px; padding-bottom: 10px; border-bottom: 1px solid #333;
        }
        .subject-info { font-weight: 600; color: #fff; font-size: 1em; }

        /* ---- Outlier badge ---- */
        .outlier-badge-container { margin-top: 6px; }
        .outlier-summary-badge {
            display: inline-flex; align-items: center; gap: 5px;
            background: #2a1500; border: 1px solid #ff8c00;
            color: #ff8c00; border-radius: 4px;
            padding: 3px 8px; font-size: 0.75em; font-weight: 600;
            cursor: pointer; user-select: none; transition: background 0.15s;
        }
        .outlier-summary-badge:hover { background: #3a2000; }
        .outlier-roi-list {
            display: none; margin-top: 5px;
            background: #111; border: 1px solid #444;
            border-radius: 4px; padding: 6px 10px; max-width: 560px;
        }
        .outlier-roi-list.open { display: block; }
        .roi-chip {
            display: inline-block; margin: 2px 3px;
            background: #2a1500; border: 1px solid #ff8c00;
            color: #ffaa44; border-radius: 12px;
            padding: 2px 8px; font-size: 0.72em;
        }

        /* ---- Bounding box badge ---- */
        .bbox-badge {
            display: inline-flex; align-items: center; gap: 5px;
            background: #1a0030; border: 1px solid #cc44ff;
            color: #cc44ff; border-radius: 4px;
            padding: 3px 8px; font-size: 0.75em; font-weight: 600;
            margin-top: 4px;
        }

        /* ---- Action buttons ---- */
        .actions-cell { display: flex; gap: 5px; }
        .btn-small { padding: 8px 12px; border: none; border-radius: 4px;
                     font-size: 0.85em; cursor: pointer; font-weight: 600;
                     transition: all 0.2s; flex: 1; }
        .btn-fail  { background: #dc3545; color: #fff; }
        .btn-fail:hover  { background: #c82333; }
        .btn-fail.active { background: #bd2130; box-shadow: inset 0 2px 4px rgba(0,0,0,0.2); }
        .btn-flag  { background: #ffc107; color: #333; }
        .btn-flag:hover  { background: #e0a800; }
        .btn-flag.active { background: #d39e00; box-shadow: inset 0 2px 4px rgba(0,0,0,0.2); }

        /* ---- Classification / Notes ---- */
        .classification-cell select {
            width: 100%; padding: 8px; border: 1px solid #444;
            background: #1a1a1a; color: #fff; border-radius: 4px; font-size: 0.9em;
        }
        .classification-cell select:focus { outline: none; border-color: #667eea; }
        .classification-cell select:disabled { background: #0a0a0a; color: #666; cursor: not-allowed; }
        .notes-cell textarea {
            width: 100%; height: 40px; padding: 6px 8px;
            border: 1px solid #444; background: #1a1a1a; color: #fff;
            border-radius: 4px; font-size: 0.85em; font-family: inherit; resize: vertical;
        }
        .notes-cell textarea:focus { outline: none; border-color: #667eea; }
        .notes-cell textarea::placeholder { color: #666; }

        /* ---- Slice grid: 4 coronal | divider | 2 sagittal ---- */
        .slices-grid {
            display: grid;
            /* 4 coronal cols, a thin divider, 2 sagittal cols */
            grid-template-columns: repeat(3, 1fr) 3px repeat(3, 1fr);
            gap: 0 8px;
            padding: 10px;
            border-radius: 4px;
        }

        /* view label row — must sit above their column spans */
        .view-group-label {
            font-size: 0.72em; font-weight: 700; letter-spacing: 0.08em;
            text-transform: uppercase; text-align: center; padding-bottom: 6px;
        }
        .view-group-label.coronal  { grid-column: span 3; color: #7eb8f7; }
        .view-group-label.divider-header { grid-column: span 1; } /* invisible spacer */
        .view-group-label.sagittal { grid-column: span 3; color: #f7c87e; }

        /* the vertical divider */
        .view-divider {
            background: #333; border-radius: 2px;
            align-self: stretch; margin: 0 4px;
        }

        .slice-wrapper { text-align: center; }
        .slice-image {
            width: 100%; height: auto; object-fit: contain;
            border: 2px solid #333; border-radius: 4px;
            cursor: pointer; transition: all 0.2s; display: block;
            background: #000; max-height: 350px;
        }
        .slice-image:hover {
            transform: scale(1.02); border-color: #667eea;
            box-shadow: 0 4px 12px rgba(102,126,234,0.5); z-index: 10;
        }
        .missing-slice {
            width: 100%; min-height: 180px; background: #1a1a1a;
            border: 2px dashed #444; border-radius: 4px;
            display: flex; align-items: center; justify-content: center;
            font-size: 0.8em; color: #999;
        }
        .slice-label { font-size: 0.78em; color: #888; margin-top: 5px; }

        /* ---- Modal ---- */
        .modal { display: none; position: fixed; z-index: 1000;
                  left: 0; top: 0; width: 100%; height: 100%;
                  background: rgba(0,0,0,0.92); align-items: center; justify-content: center; }
        .modal.active { display: flex; }
        .modal-content { max-width: 90%; max-height: 90%; border-radius: 8px; }
        .modal-close { position: absolute; top: 20px; right: 40px;
                        font-size: 40px; color: #fff; cursor: pointer; }
        .modal-close:hover { transform: scale(1.2); }

        @media (max-width: 1200px) {
            /* collapse to 2 coronal columns; sagittal stays 2 */
            .slices-grid { grid-template-columns: repeat(3, 1fr) 3px repeat(3, 1fr); }
            .view-group-label.coronal { grid-column: span 3; }
        }
        @media (max-width: 768px) {
            .slices-grid { grid-template-columns: 1fr 1fr; }
            .view-divider, .view-group-label { display: none; }
            .subject-header { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>

    <div class="header">
        <div class="header-left">
            <h1>Cerebellum Segmentation QC</h1>
            <div class="subtitle">
                DATASET_PLACEHOLDER BATCH_LABEL_PLACEHOLDER |
                TOTAL_SUBJECTS_PLACEHOLDER SubjectsOUTLIER_SUMMARY_PLACEHOLDERBBOX_SUMMARY_PLACEHOLDER |
                3 Coronal + 3 Sagittal
            </div>
        </div>
        <div class="header-right">
            <button class="btn btn-success" onclick="downloadCSV()">Save to CSV</button>
            <span id="save-status"></span>
        </div>
    </div>

    <div id="subjects-container"></div>

    <div id="imageModal" class="modal" onclick="closeModal()">
        <span class="modal-close">&times;</span>
        <img class="modal-content" id="modal-image">
    </div>

    <script>
        const subjects       = SUBJECTS_DATA_PLACEHOLDER;
        const datasetName    = 'DATASET_PLACEHOLDER';
        const batchLabel     = 'BATCH_LABEL_PLACEHOLDER';
        const coronalSlices  = CORONAL_SLICES_PLACEHOLDER;
        const sagittalSlices = SAGITTAL_SLICES_PLACEHOLDER;
        const outlierData    = OUTLIER_DATA_PLACEHOLDER;
        const bboxData       = BBOX_DATA_PLACEHOLDER;   // Set<SubjectID> as plain object {id: true}

        let reviews = {};

        function storageKey() {
            const b = batchLabel ? batchLabel.replace(/\s+/g, '_') : '';
            return `qc_reviews_${datasetName}${b}`;
        }
        function loadReviews() {
            const saved = localStorage.getItem(storageKey());
            if (saved) reviews = JSON.parse(saved);
        }
        function saveReviews() {
            localStorage.setItem(storageKey(), JSON.stringify(reviews));
        }

        function autoSave(subjectId) {
            const classification = document.getElementById(`class-${subjectId}`).value;
            const notes          = document.getElementById(`notes-${subjectId}`).value;
            const isFailed       = document.getElementById(`fail-${subjectId}`).classList.contains('active');
            const isFlagged      = document.getElementById(`flag-${subjectId}`).classList.contains('active');

            let status = 'pass';
            if (isFailed)       status = 'fail';
            else if (isFlagged) status = 'flagged for later QC';

            reviews[subjectId] = { status, classification, notes, timestamp: new Date().toISOString() };
            saveReviews();
            showSaveIndicator();
            updateRowAppearance(subjectId);
        }

        function toggleFail(subjectId) {
            const failBtn     = document.getElementById(`fail-${subjectId}`);
            const flagBtn     = document.getElementById(`flag-${subjectId}`);
            const classSelect = document.getElementById(`class-${subjectId}`);
            const wasFailed   = failBtn.classList.contains('active');
            if (wasFailed) {
                failBtn.classList.remove('active');
                failBtn.textContent  = 'Mark as Fail';
                classSelect.disabled = true;
                classSelect.value    = '';
            } else {
                failBtn.classList.add('active');
                failBtn.textContent  = 'Failed';
                classSelect.disabled = false;
                flagBtn.classList.remove('active');
                flagBtn.textContent  = 'Flag for Later QC';
            }
            autoSave(subjectId);
        }

        function toggleFlag(subjectId) {
            const failBtn     = document.getElementById(`fail-${subjectId}`);
            const flagBtn     = document.getElementById(`flag-${subjectId}`);
            const classSelect = document.getElementById(`class-${subjectId}`);
            const wasFlagged  = flagBtn.classList.contains('active');
            if (wasFlagged) {
                flagBtn.classList.remove('active');
                flagBtn.textContent  = 'Flag for Later QC';
            } else {
                flagBtn.classList.add('active');
                flagBtn.textContent  = 'Flagged for Later QC';
                failBtn.classList.remove('active');
                failBtn.textContent  = 'Mark as Fail';
                classSelect.disabled = true;
                classSelect.value    = '';
            }
            autoSave(subjectId);
        }

        function updateRowAppearance(subjectId) {
            const row     = document.getElementById(`row-${subjectId}`);
            const failBtn = document.getElementById(`fail-${subjectId}`);
            const flagBtn = document.getElementById(`flag-${subjectId}`);
            row.classList.remove('failed', 'flagged');
            if (failBtn.classList.contains('active'))      row.classList.add('failed');
            else if (flagBtn.classList.contains('active')) row.classList.add('flagged');
            // Re-apply pre-computed flags (CSS only shows them when rater classes are absent)
            const flags = [];
            if (bboxData[subjectId])              flags.push('bbox');
            if (outlierData[subjectId]?.n > 0)    flags.push('outlier');
            row.dataset.flags = flags.join(' ');
        }

        function validateAndSave(subjectId) {
            const failBtn     = document.getElementById(`fail-${subjectId}`);
            const classSelect = document.getElementById(`class-${subjectId}`);
            if (failBtn.classList.contains('active') && !classSelect.value) {
                alert('Please select a failure reason for failed subjects.');
                return false;
            }
            autoSave(subjectId);
            return true;
        }

        function showSaveIndicator() {
            const el = document.getElementById('save-status');
            el.innerHTML = '<span class="save-indicator">Auto-saved</span>';
            setTimeout(() => { el.innerHTML = ''; }, 2000);
        }

        function buildOutlierBadge(subjectId) {
            const info = outlierData[subjectId];
            if (!info || info.n === 0) return '';
            const chips = info.rois.map(r => `<span class="roi-chip">${r}</span>`).join('');
            return `
                <div class="outlier-badge-container">
                    <span class="outlier-summary-badge"
                          onclick="toggleROIList('${subjectId}')"
                          title="Click to expand/collapse ROI list">
                        ⚠ ${info.n} outlier ROI${info.n > 1 ? 's' : ''}
                    </span>
                    <div id="roi-list-${subjectId}" class="outlier-roi-list">${chips}</div>
                </div>`;
        }

        function toggleROIList(subjectId) {
            document.getElementById(`roi-list-${subjectId}`).classList.toggle('open');
        }

        function buildBboxBadge(subjectId) {
            if (!bboxData[subjectId]) return '';
            return `<div class="bbox-badge">⬛ Bounding Box Fail</div>`;
        }

        function sliceCell(basePath, view, slice) {
            const img = `${basePath}/${view}_${slice}.png`;
            const cap = view.charAt(0).toUpperCase() + view.slice(1);
            return `
                <div class="slice-wrapper">
                    <img src="${img}" alt="${cap} ${slice}" class="slice-image"
                         onclick="openModal('${img}')"
                         onerror="this.outerHTML='<div class=\\'missing-slice\\'>Not found</div>'">
                    <div class="slice-label">${cap} ${slice}</div>
                </div>`;
        }

        function generateSubjectRows() {
            const container = document.getElementById('subjects-container');
            container.innerHTML = '';

            subjects.forEach(subject => {
                const row = document.createElement('div');
                row.className = 'subject-row';
                row.id = `row-${subject.id}`;

                const coronalCells  = coronalSlices.map(s  => sliceCell(subject.path, 'coronal',  s)).join('');
                const sagittalCells = sagittalSlices.map(s => sliceCell(subject.path, 'sagittal', s)).join('');

                const slicesHTML = `
                    <div class="slices-grid">
                        <div class="view-group-label coronal">Coronal</div>
                        <div class="view-group-label divider-header"></div>
                        <div class="view-group-label sagittal">Sagittal</div>
                        ${coronalCells}
                        <div class="view-divider"></div>
                        ${sagittalCells}
                    </div>`;

                const saved     = reviews[subject.id] || { status: 'pass', classification: '', notes: '' };
                const isFailed  = saved.status === 'fail';
                const isFlagged = saved.status === 'flagged for later QC';

                // Pre-computed flags drive the border color until the rater overrides
                const flags = [];
                if (bboxData[subject.id])                          flags.push('bbox');
                if (outlierData[subject.id]?.n > 0)                flags.push('outlier');
                row.dataset.flags = flags.join(' ');

                row.innerHTML = `
                    <div class="subject-header">
                        <div class="subject-info">
                            ${subject.id}
                            ${buildOutlierBadge(subject.id)}
                            ${buildBboxBadge(subject.id)}
                        </div>
                        <div class="actions-cell">
                            <button id="fail-${subject.id}"
                                    class="btn-small btn-fail ${isFailed ? 'active' : ''}"
                                    onclick="toggleFail('${subject.id}')">
                                ${isFailed ? 'Failed' : 'Mark as Fail'}
                            </button>
                            <button id="flag-${subject.id}"
                                    class="btn-small btn-flag ${isFlagged ? 'active' : ''}"
                                    onclick="toggleFlag('${subject.id}')">
                                ${isFlagged ? 'Flagged for Later QC' : 'Flag for Later QC'}
                            </button>
                        </div>
                        <div class="classification-cell">
                            <select id="class-${subject.id}"
                                    onchange="validateAndSave('${subject.id}')"
                                    ${!isFailed ? 'disabled' : ''}>
                                <option value="">-- Select Failure Reason --</option>
                                <option value="over"  ${saved.classification === 'over'  ? 'selected' : ''}>Over-segmentation</option>
                                <option value="under" ${saved.classification === 'under' ? 'selected' : ''}>Under-segmentation</option>
                                <option value="mis"   ${saved.classification === 'mis'   ? 'selected' : ''}>Mis-segmentation</option>
                                <option value="other" ${saved.classification === 'other' ? 'selected' : ''}>Other</option>
                            </select>
                        </div>
                        <div class="notes-cell">
                            <textarea id="notes-${subject.id}"
                                      placeholder="Notes..."
                                      onchange="autoSave('${subject.id}')">${saved.notes}</textarea>
                        </div>
                    </div>
                    ${slicesHTML}`;

                container.appendChild(row);
                if (isFailed)       row.classList.add('failed');
                else if (isFlagged) row.classList.add('flagged');
            });
        }

        function openModal(imgPath) {
            document.getElementById('imageModal').classList.add('active');
            document.getElementById('modal-image').src = imgPath;
        }
        function closeModal() {
            document.getElementById('imageModal').classList.remove('active');
        }

        function downloadCSV() {
            let passCount = 0, failCount = 0, flagCount = 0;
            subjects.forEach(s => {
                const r = reviews[s.id] || { status: 'pass' };
                if      (r.status === 'pass')                   passCount++;
                else if (r.status === 'fail')                   failCount++;
                else if (r.status === 'flagged for later QC')   flagCount++;
            });

            const msg =
                `QC results summary:\n\n` +
                `  PASS:    ${passCount}\n` +
                `  FAIL:    ${failCount}\n` +
                `  FLAGGED: ${flagCount}\n\n` +
                `Subjects not explicitly marked will be recorded as PASS.\nContinue?`;
            if (!confirm(msg)) return;

            let csv = 'Subject_ID,Status,Failure_Reason,Notes,Bounding_Box,N_Outlier_ROIs,Outlier_ROIs\n';
            subjects.forEach(s => {
                const r    = reviews[s.id] || { status: 'pass', classification: '', notes: '' };
                const note = r.notes.replace(/"/g, '""');
                const bbox = bboxData[s.id] ? 'fail' : '';
                const info = outlierData[s.id];
                csv += `"${s.id}","${r.status}","${r.classification}","${note}",` +
                       `"${bbox}","${info ? info.n : ''}","${info ? info.rois.join('|') : ''}"\n`;
            });

            const blob = new Blob([csv], { type: 'text/csv' });
            const url  = URL.createObjectURL(blob);
            const a    = document.createElement('a');
            a.href = url; a.download = 'CSV_FILENAME_PLACEHOLDER';
            document.body.appendChild(a); a.click();
            document.body.removeChild(a); URL.revokeObjectURL(url);
        }

        document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });

        loadReviews();
        generateSubjectRows();
    </script>
</body>
</html>
HTML_TEMPLATE

    # --------------------------------------------------------------------------
    # Build JSON blobs
    # --------------------------------------------------------------------------

    # subjects
    SUBJECTS_JSON="["
    FIRST_SUBJ=true
    for SUBJECT_DIR in "${BATCH_SUBJECTS[@]}"; do
        SUBJECT_DIR=${SUBJECT_DIR%/}
        SUBJECT_ID=$(basename "$SUBJECT_DIR")
        [[ "$FIRST_SUBJ" == true ]] && FIRST_SUBJ=false || SUBJECTS_JSON+=","
        SUBJECTS_JSON+="{\"id\":\"${SUBJECT_ID}\",\"path\":\"./pngs/${SUBJECT_ID}\"}"
    done
    SUBJECTS_JSON+="]"

    # coronal + sagittal slice arrays
    CORONAL_JSON=$(build_int_json_array CORONAL_SLICES)
    SAGITTAL_JSON=$(build_int_json_array SAGITTAL_SLICES)

    # outlier data
    OUTLIER_JSON="{"
    FIRST_ENTRY=true
    for SUBJECT_DIR in "${BATCH_SUBJECTS[@]}"; do
            SUBJECT_ID=$(basename "${SUBJECT_DIR%/}")
            ENTRY="${outlier_map[$SUBJECT_ID]:-}"
            [[ -z "$ENTRY" ]] && continue

            N_ROIS=$(echo "$ENTRY"  | cut -d'|' -f1)
            ROI_STR=$(echo "$ENTRY" | cut -d'|' -f2-)

            ROI_JSON="["
            FIRST_ROI=true
            if [[ -n "$ROI_STR" ]]; then
                IFS='|' read -ra ROI_ARR <<< "$ROI_STR"
                for ROI in "${ROI_ARR[@]}"; do
                    [[ "$FIRST_ROI" == true ]] && FIRST_ROI=false || ROI_JSON+=","
                    ROI_JSON+="\"${ROI}\""
                done
            fi
            ROI_JSON+="]"

            [[ "$FIRST_ENTRY" == true ]] && FIRST_ENTRY=false || OUTLIER_JSON+=","
            OUTLIER_JSON+="\"${SUBJECT_ID}\":{\"n\":${N_ROIS},\"rois\":${ROI_JSON}}"
        done
    OUTLIER_JSON+="}"

    # header summary: how many subjects in this batch have >= 1 outlier ROI
    N_OUTLIER_SUBJECTS=0
    for SUBJECT_DIR in "${BATCH_SUBJECTS[@]}"; do
        SUBJECT_ID=$(basename "${SUBJECT_DIR%/}")
        ENTRY="${outlier_map[$SUBJECT_ID]:-}"
        if [[ -n "$ENTRY" ]]; then
            N=$(echo "$ENTRY" | cut -d'|' -f1)
            [[ "$N" -gt 0 ]] && (( N_OUTLIER_SUBJECTS++ ))
        fi
    done
    OUTLIER_SUMMARY=" | ${N_OUTLIER_SUBJECTS} with outlier ROIs"

    # bbox fail set for this batch — { "SubjectID": true, ... }
    BBOX_JSON="{"
    FIRST_BBOX=true
    for SUBJECT_DIR in "${BATCH_SUBJECTS[@]}"; do
        SUBJECT_ID=$(basename "${SUBJECT_DIR%/}")
        if [[ -n "${bbox_fail_set[$SUBJECT_ID]:-}" ]]; then
            [[ "$FIRST_BBOX" == true ]] && FIRST_BBOX=false || BBOX_JSON+=","
            BBOX_JSON+="\"${SUBJECT_ID}\":true"
        fi
    done
    BBOX_JSON+="}"

    # header summary: how many in this batch failed bbox
    N_BBOX_SUBJECTS=0
    for SUBJECT_DIR in "${BATCH_SUBJECTS[@]}"; do
        SUBJECT_ID=$(basename "${SUBJECT_DIR%/}")
        [[ -n "${bbox_fail_set[$SUBJECT_ID]:-}" ]] && (( N_BBOX_SUBJECTS++ ))
    done
    BBOX_SUMMARY=" | ${N_BBOX_SUBJECTS} bbox fails"

    # --------------------------------------------------------------------------
    # Inject placeholders
    # --------------------------------------------------------------------------
    BATCH_LABEL_ESC=$(printf '%s\n'       "$BATCH_LABEL"       | sed 's/[[\.*^$()+?{|]/\\&/g')
    OUTLIER_SUMMARY_ESC=$(printf '%s\n'   "$OUTLIER_SUMMARY"   | sed 's/[[\.*^$()+?{|]/\\&/g')
    BBOX_SUMMARY_ESC=$(printf '%s\n'      "$BBOX_SUMMARY"      | sed 's/[[\.*^$()+?{|]/\\&/g')

    sed -i "s@DATASET_PLACEHOLDER@${DATASET}@g"                     "$OUTPUT_HTML"
    sed -i "s@TOTAL_SUBJECTS_PLACEHOLDER@${BATCH_COUNT}@g"           "$OUTPUT_HTML"
    sed -i "s@CSV_FILENAME_PLACEHOLDER@${CSV_FILENAME}@g"            "$OUTPUT_HTML"
    sed -i "s@BATCH_LABEL_PLACEHOLDER@${BATCH_LABEL_ESC}@g"          "$OUTPUT_HTML"
    sed -i "s@OUTLIER_SUMMARY_PLACEHOLDER@${OUTLIER_SUMMARY_ESC}@g"  "$OUTPUT_HTML"
    sed -i "s@BBOX_SUMMARY_PLACEHOLDER@${BBOX_SUMMARY_ESC}@g"        "$OUTPUT_HTML"

    SUBJECTS_JSON_ESC=$(printf '%s'  "$SUBJECTS_JSON"  | tr -d '\n' | sed 's/[\/&]/\\&/g')
    CORONAL_JSON_ESC=$(printf '%s'   "$CORONAL_JSON"   | tr -d '\n' | sed 's/[\/&]/\\&/g')
    SAGITTAL_JSON_ESC=$(printf '%s'  "$SAGITTAL_JSON"  | tr -d '\n' | sed 's/[\/&]/\\&/g')
    OUTLIER_JSON_ESC=$(printf '%s'   "$OUTLIER_JSON"   | tr -d '\n' | sed 's/[\/&]/\\&/g')
    BBOX_JSON_ESC=$(printf '%s'      "$BBOX_JSON"      | tr -d '\n' | sed 's/[\/&]/\\&/g')

    sed -i "s@SUBJECTS_DATA_PLACEHOLDER@${SUBJECTS_JSON_ESC}@g"    "$OUTPUT_HTML"
    sed -i "s@CORONAL_SLICES_PLACEHOLDER@${CORONAL_JSON_ESC}@g"    "$OUTPUT_HTML"
    sed -i "s@SAGITTAL_SLICES_PLACEHOLDER@${SAGITTAL_JSON_ESC}@g"  "$OUTPUT_HTML"
    sed -i "s@OUTLIER_DATA_PLACEHOLDER@${OUTLIER_JSON_ESC}@g"      "$OUTPUT_HTML"
    sed -i "s@BBOX_DATA_PLACEHOLDER@${BBOX_JSON_ESC}@g"            "$OUTPUT_HTML"

    echo "  Done"
    echo ""

done  # batch loop

echo "============================================================"
echo "HTML GENERATION COMPLETE"
echo "============================================================"
echo "Output directory : $OUTPUT_DIR"
echo "Dataset          : $DATASET"
echo "Total subjects   : $TOTAL_SUBJECTS"
echo "HTML files       : $TOTAL_BATCHES"
if [ $TOTAL_BATCHES -eq 1 ]; then
    echo "  ${DATASET}_acapulco_Cerebellum_QC_brainslice.html"
else
    for (( B=1; B<=TOTAL_BATCHES; B++ )); do
        echo "  ${DATASET}_acapulco_Cerebellum_QC_brainslice_batch${B}.html"
    done
fi
echo "============================================================"
exit 0