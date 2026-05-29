#!/bin/bash
#$ -S /bin/bash
#$ -o /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/logs/UKBB_T1w_NIFTI_20252_2_0 -j y
#$ -N AC_PNGGEN
#$ -V
#$ -l h_vmem=24G,hostslots=2
#$ -q compute9.q,iniadm9.q,runnow9.q
#$ -t 1:7034

# Cerebellum Segmentation QC: PNG GENERATOR
# Author: Sunanda Somu

#==============================================================================
# CONFIGURATION
#==============================================================================

# These patterns are appended to each subject path to find the files
IMAGE_SUBPATH="mni/*_n4_mni_std.nii.gz"
LABEL_SUBPATH="parc/*_n4_mni_seg_post_std.nii.gz"

#==============================================================================
# USAGE
#==============================================================================
### qsub /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/scripts/script_02b_acapulco_png_generator.sh /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/Subjects/ /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/dataset/UKBB/T1w_NIFTI_20252_2_0/QC/ /scratch/faculty/njahansh/projects/cerebellum_segmentation/acapulco/scripts/common_script/colormap.txt /ifs/loni/faculty/njahansh/nerds/siddharth/software/anaconda3/bin/python

function Usage(){
    cat << USAGE

Cerebellum Segmentation QC: PNG GENERATOR

Usage:
    # For array job (processes multiple subjects):
    qsub -t 1:N $(basename "$0") <subjects_dir> <output_dir> <colormap_file> <python_path> [skip_level] [padding]
    
    # For single subject test:
    bash $(basename "$0") <subjects_dir> <output_dir> <colormap_file> <python_path> [skip_level] [padding]

Arguments:
    subjects_dir     : Parent directory containing subject subdirectories
    output_dir       : Base output directory for PNG images
    colormap_file    : Path to colormap.txt
    python_path      : Path to Python executable (e.g., /usr/bin/python3 or conda environment)
    skip_level       : (Optional) Slice skip level within segmentation extent
                       0 = all slices where segmentation exists
                       N = every Nth slice where segmentation exists
                       Default: 2 (every other slice)
                       Note: Specific slices are always generated in addition to skip_level slices
    padding          : (Optional) Voxels of padding around segmentation for FOV
                       Default: 10 (no padding)

                       NOTE: In addition to skip_level slices, these predefined
                       slices are ALWAYS generated:
                       Axial:    [10, 40, 80]
                       Coronal:  [68, 75, 85]
                       Sagittal: [70, 84, 91]

File Patterns (configured in script):
    IMAGE_SUBPATH: ${IMAGE_SUBPATH}
    LABEL_SUBPATH: ${LABEL_SUBPATH}

Examples:
    # Submit array job - default (every other slice within segmentation)
    # First, count subjects: ls -d /path/to/subjects/*/ | wc -l
    qsub -t 1:100 script_02b_acapulco_png_generator.sh \\
        /path/to/subjects \\
        /path/to/output \\
        /path/to/colormap.txt \\
        /usr/bin/python3

    # Test single subject with ALL slices in segmentation extent
    SGE_TASK_ID=1 bash script_02b_acapulco_png_generator.sh \\
        /path/to/subjects \\
        /path/to/output \\
        /path/to/colormap.txt \\
        /usr/bin/python3 \\
        0
    
    # Test with every 3rd slice in segmentation extent
    SGE_TASK_ID=1 bash script_02b_acapulco_png_generator.sh \\
        /path/to/subjects \\
        /path/to/output \\
        /path/to/colormap.txt \\
        /usr/bin/python3 \\
        3

USAGE
    exit 1
}

if [[ "$1" == "--help" || "$1" == "-h" || $# -lt 4 ]]; then
    Usage
fi

#==============================================================================
# PARSE ARGUMENTS
#==============================================================================

SUBJECTS_DIR="$1"
BASE_OUTPUT_DIR="$2"
COLORMAP_FILE="$3"
PYTHON_PATH="$4"
SKIP_LEVEL="${5:-2}"  # Default to 2 (alternate slices) if not provided
PADDING="${6:-10}"     # Default to 0 (no padding around segmentation extent)

# Set BB_LOG path based on output directory
BB_LOG="${BASE_OUTPUT_DIR}/bounding_box_failures.txt"

#==============================================================================
# VALIDATE CONFIGURATION
#==============================================================================

if [[ ! -d "$SUBJECTS_DIR" ]]; then
    echo "Error: Subjects directory not found: $SUBJECTS_DIR"
    exit 1
fi

if [[ ! -f "$COLORMAP_FILE" ]]; then
    echo "Error: Colormap file not found: $COLORMAP_FILE"
    exit 1
fi

if [[ ! -x "$PYTHON_PATH" ]]; then
    echo "Error: Python executable not found or not executable: $PYTHON_PATH"
    exit 1
fi

# Get array of subject directories (sorted for consistency)
SUBJECT_DIRS=($(ls -d "${SUBJECTS_DIR}"/*/ 2>/dev/null | sort))

if [[ ${#SUBJECT_DIRS[@]} -eq 0 ]]; then
    echo "Error: No subject directories found in: $SUBJECTS_DIR"
    exit 1
fi

# Check if running as array job or single test
if [[ -z "$SGE_TASK_ID" ]]; then
    echo "Warning: SGE_TASK_ID not set. Using task ID 1 for testing."
    SGE_TASK_ID=1
fi

# Get subject directory for this task
SUBJECT_PATH=${SUBJECT_DIRS[${SGE_TASK_ID}-1]}

if [[ -z "$SUBJECT_PATH" ]]; then
    echo "Error: No subject found for task ID $SGE_TASK_ID"
    echo "Total subjects found: ${#SUBJECT_DIRS[@]}"
    exit 1
fi

# Remove trailing slash and extract subject ID from directory name
SUBJECT_PATH=${SUBJECT_PATH%/}
SUBJECT_ID=$(basename "$SUBJECT_PATH")

# Find matching files
shopt -s nullglob  # Return empty array if no matches instead of literal pattern
IMAGE_FILES=(${SUBJECT_PATH}/${IMAGE_SUBPATH})
LABEL_FILES=(${SUBJECT_PATH}/${LABEL_SUBPATH})
shopt -u nullglob

# Get first match
IMAGE_FILE="${IMAGE_FILES[0]}"
LABEL_FILE="${LABEL_FILES[0]}"

# Check if files were found
if [[ -z "$IMAGE_FILE" || ! -f "$IMAGE_FILE" ]]; then
    echo "FAILED: Image file not found"
    echo "   Pattern: ${SUBJECT_PATH}/${IMAGE_SUBPATH}"
    echo "   No files matched this pattern"
    exit 1
fi

if [[ -z "$LABEL_FILE" || ! -f "$LABEL_FILE" ]]; then
    echo "FAILED: Label file not found"
    echo "   Pattern: ${SUBJECT_PATH}/${LABEL_SUBPATH}"
    echo "   No files matched this pattern"
    exit 1
fi

OUTPUT_DIR="${BASE_OUTPUT_DIR}/pngs/${SUBJECT_ID}"

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$BB_LOG")"

echo "============================================================"
echo "CEREBELLUM QC - Subject: ${SUBJECT_ID} (Task ${SGE_TASK_ID})"
echo "============================================================"
echo "Subject ID:   $SUBJECT_ID"
echo "Subject Path: $SUBJECT_PATH"
echo "Image:        $IMAGE_FILE"
echo "Label:        $LABEL_FILE"
echo "Output:       $OUTPUT_DIR"
echo "Python:       $PYTHON_PATH"
echo "Skip Level:   $SKIP_LEVEL"
echo "Padding:      $PADDING"
echo "BB Log:       $BB_LOG"
echo "============================================================"
echo ""

# Run embedded Python script
"$PYTHON_PATH" - "$SUBJECT_ID" "$IMAGE_FILE" "$LABEL_FILE" "$OUTPUT_DIR" "$COLORMAP_FILE" "$SKIP_LEVEL" "$BB_LOG" "$PADDING" << 'PYTHON_SCRIPT'
import sys
import os
from pathlib import Path
from datetime import datetime
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import nibabel as nib
from scipy.ndimage import binary_erosion
import warnings
warnings.simplefilter('ignore')


class CerebellumQC:
    """Handler for cerebellum segmentation quality control."""
    
    def __init__(self, subject, image_path, label_path, output_path, colormap_path, skip_level, bb_log, padding):
        self.subject = subject
        self.image_path = image_path
        self.label_path = label_path
        self.output_path = Path(output_path)
        self.colormap_path = colormap_path
        self.skip_level = int(skip_level)
        self.bb_log = bb_log if bb_log else None
        self.padding = int(padding)
        
        self.bg_image = None
        self.label = None
        self.affine = None
        self.colors = None
        self.label_image_erosion = None
        self.coloured_labels = None
        self.nifti_real = []
        self.out_of_bounds = False
        self.bb_status = {'axial': True, 'coronal': True, 'sagittal': True}
        self.image_counts = {'axial': 0, 'coronal': 0, 'sagittal': 0}
        self.missing_slices = {'axial': [], 'coronal': [], 'sagittal': []}
        
        # Default bounding boxes for cerebellum
        # Uses 0-based indices: x=0, y=1, z=2
        self.bounding_boxes = {
            'axial':    {'dim': 2, 'min': 4,  'max': 90},
            'coronal':  {'dim': 1, 'min': 36, 'max': 115},
            'sagittal': {'dim': 0, 'min': 38, 'max': 154}
        }
        
        # Dynamic segmentation extent (for PNG FOV)
        self.seg_extent = {
            'x': {'min': 0, 'max': 0},
            'y': {'min': 0, 'max': 0},
            'z': {'min': 0, 'max': 0}
        }
        
    def load_colors(self):
        """Load color mapping from colormap file."""
        try:
            with open(self.colormap_path) as colors_file:
                lines = colors_file.readlines()
            
            lines = [l.strip() for l in lines if l.strip() and not l.strip().startswith('#')]
            
            if not lines:
                raise ValueError("Colormap file is empty or contains only comments")
            
            lines = np.array([list(map(float, l.split()[:5])) for l in lines])
            colors = np.zeros((int(np.max(lines[:, 0])) + 1, 4), dtype=np.uint8)
            indices = lines[:, 0].astype(int)
            colors[indices, :3] = lines[:, 1:4].astype(np.uint8)
            colors[indices, -1] = (lines[:, -1] * 255).astype(np.uint8)
            
            print(f"Loaded {len(indices)} color mappings")
            return colors
            
        except Exception as e:
            raise ValueError(f"Error parsing colormap file: {e}")
    
    def analyze_label_matching(self):
        """Analyze which labels from colormap are present in segmentation."""
        
        # Get unique labels and counts from segmentation
        unique_labels, counts = np.unique(self.label, return_counts=True)
        seg_labels = dict(zip(unique_labels.astype(int), counts.astype(int)))
        
        # Parse colormap to get defined labels
        colormap_labels = {}
        try:
            with open(self.colormap_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    parts = line.split()
                    if len(parts) >= 8:
                        idx = int(parts[0])
                        label_name = ' '.join(parts[7:]).strip('"')
                        colormap_labels[idx] = label_name
        except Exception as e:
            print(f"Error parsing colormap: {e}")
            return None
        
        # Find matches
        matched = [idx for idx in seg_labels.keys() if idx in colormap_labels]
        missing = [idx for idx in colormap_labels.keys() if idx not in seg_labels]
        unexpected = [idx for idx in seg_labels.keys() if idx not in colormap_labels]
        
        # Print analysis
        print("\n" + "="*60)
        print("LABEL MATCHING ANALYSIS")
        print("="*60)
        
        total_voxels = np.prod(self.label.shape)
        
        print(f"\nColormap defines: {len(colormap_labels)} labels")
        print(f"Segmentation has: {len(seg_labels)} unique values")
        print(f"Matched: {len(matched)} labels")
        
        # Show matched labels
        if matched:
            print(f"\n{'Index':<8} {'Voxels':<12} {'%':<8} Label")
            print("-"*60)
            matched_sorted = sorted(matched, key=lambda x: seg_labels[x], reverse=True)
            for idx in matched_sorted:
                count = seg_labels[idx]
                pct = (count / total_voxels) * 100
                name = colormap_labels[idx]
                if idx == 0:
                    name += " (background)"
                print(f"{idx:<8} {count:<12,} {pct:<7.3f}% {name}")
        
        # Warn about missing labels
        if missing:
            print(f"\nWARNING: Labels in colormap but NOT in segmentation: {len(missing)}")
            for idx in sorted(missing):
                print(f"   {idx}: {colormap_labels[idx]}")
        
        # Warn about unexpected labels
        if unexpected:
            print(f"\nWARNING: Labels in segmentation but NOT in colormap: {len(unexpected)}")
            print("   These will not be colored correctly!")
            for idx in sorted(unexpected):
                count = seg_labels[idx]
                pct = (count / total_voxels) * 100
                print(f"   {idx}: {count:,} voxels ({pct:.3f}%)")
        
        print("="*60)
        
        return {
            'matched': matched,
            'missing': missing,
            'unexpected': unexpected,
            'seg_labels': seg_labels,
            'colormap_labels': colormap_labels
        }
    
    def assign_colors(self, label_image, colors):
        """Assign colors to label image and track voxel coordinates."""
        colors[0, 3] = 0  # background alpha
        label_image = np.round(label_image).astype(int)
        
        # Track all non-zero voxel coordinates
        inds = np.where(label_image != 0)
        self.nifti_real = list(zip(inds[0], inds[1], inds[2]))
        
        colorful_label_image = colors[label_image, :]
        return colorful_label_image
    
    def check_bounding_box(self, orientation):
        """Check if segmentation falls within expected bounding box."""
        if not self.nifti_real:
            return True
        
        bb = self.bounding_boxes[orientation]
        coords = [item[bb['dim']] for item in self.nifti_real]
        min_coord, max_coord = min(coords), max(coords)
        
        if min_coord < bb['min'] or max_coord > bb['max']:
            print(f"Warning: {orientation} segmentation outside bounds "
                  f"[{bb['min']}, {bb['max']}]: found [{min_coord}, {max_coord}]")
            self.bb_status[orientation] = False
            return False
        
        self.bb_status[orientation] = True
        return True
    
    def get_padded_range(self, axis, max_dim):
        """Get padded slice range for an axis, clamped to image bounds."""
        min_val = max(0, self.seg_extent[axis]['min'] - self.padding)
        max_val = min(max_dim, self.seg_extent[axis]['max'] + self.padding)
        return slice(min_val, max_val)
    
    def get_slice_indices(self):
        """Generate slice indices based on segmentation extent AND always include predefined slices."""
        
        # Predefined slices that are always included
        predefined_axial = [10,40,80]
        predefined_coronal = [68, 75, 85]
        predefined_sagittal = [70, 84, 91]
        
        if not self.nifti_real:
            # No segmentation found, only use predefined slices
            print("\nWarning: No segmentation found, using only predefined slices")
            return {
                'axial': predefined_axial,
                'coronal': predefined_coronal,
                'sagittal': predefined_sagittal,
            }
        
        # Extract coordinates for each dimension
        x_coords = [item[0] for item in self.nifti_real]
        y_coords = [item[1] for item in self.nifti_real]
        z_coords = [item[2] for item in self.nifti_real]
        
        # Get min and max for each orientation
        sagittal_min, sagittal_max = min(x_coords), max(x_coords)
        coronal_min, coronal_max = min(y_coords), max(y_coords)
        axial_min, axial_max = min(z_coords), max(z_coords)
        
        # Store extent for use in image generation
        self.seg_extent = {
            'x': {'min': sagittal_min, 'max': sagittal_max},
            'y': {'min': coronal_min, 'max': coronal_max},
            'z': {'min': axial_min, 'max': axial_max}
        }
        
        if self.skip_level == 0:
            # Generate ALL slices within the segmentation extent
            axial_skip = list(range(axial_min, axial_max + 1))
            coronal_skip = list(range(coronal_min, coronal_max + 1))
            sagittal_skip = list(range(sagittal_min, sagittal_max + 1))
        else:
            # Apply skip level WITHIN the segmentation extent
            axial_skip = list(range(axial_min, axial_max + 1, self.skip_level))
            coronal_skip = list(range(coronal_min, coronal_max + 1, self.skip_level))
            sagittal_skip = list(range(sagittal_min, sagittal_max + 1, self.skip_level))
        
        # Combine skip-level slices with predefined slices (remove duplicates)
        axial_slices = sorted(set(axial_skip + predefined_axial))
        coronal_slices = sorted(set(coronal_skip + predefined_coronal))
        sagittal_slices = sorted(set(sagittal_skip + predefined_sagittal))
        
        print(f"\nSegmentation extent detected (skip_level={self.skip_level}):")
        print(f"  X (sagittal): {sagittal_min}-{sagittal_max}")
        print(f"  Y (coronal):  {coronal_min}-{coronal_max}")
        print(f"  Z (axial):    {axial_min}-{axial_max}")
        print(f"  Padding:      {self.padding} voxels")
        print(f"  Axial slices:    {len(axial_slices)}")
        print(f"  Coronal slices:  {len(coronal_slices)}")
        print(f"  Sagittal slices: {len(sagittal_slices)}")
        
        return {
            'axial': axial_slices,
            'coronal': coronal_slices,
            'sagittal': sagittal_slices,
        }
    
    def create_image(self, slice_range, orientation, slice_num):
        """Create and save a single slice visualization."""
        try:
            fig = plt.figure(figsize=(10, 10))
            plt.imshow(np.rot90(self.bg_image[slice_range]), cmap='gray', alpha=1)
            plt.imshow(np.rot90(self.label_image_erosion[slice_range]), 
                      cmap='afmhot', alpha=0.15)
            plt.imshow(np.rot90(self.coloured_labels[slice_range]), 
                      cmap='afmhot', alpha=0.15)
            plt.axis('off')
            
            output_path = self.output_path / f"{orientation}_{slice_num}.png"
            plt.savefig(output_path, format='png', dpi=100,
                       transparent=False, bbox_inches='tight', pad_inches=0.0,
                       pil_kwargs={'compress_level': 9, 'optimize': True})
            plt.close(fig)
            
            self.image_counts[orientation] += 1
            return True
            
        except Exception as e:
            print(f"Error creating {orientation} slice {slice_num}: {e}")
            self.missing_slices[orientation].append(slice_num)
            plt.close('all')
            return False
    
    def load_data(self):
        """Load and validate input images."""
        try:
            print(f"\nLoading input image...")
            img_nib = nib.load(self.image_path)
            self.bg_image = img_nib.get_fdata().squeeze()
            self.affine = img_nib.affine
            print(f"Image loaded: shape {self.bg_image.shape}")
            
            print(f"Loading label image...")
            self.label = nib.load(self.label_path).get_fdata().squeeze()
            print(f"Label loaded: shape {self.label.shape}")
            
            if self.bg_image.shape != self.label.shape:
                raise ValueError(f"Image and label shapes don't match: "
                               f"{self.bg_image.shape} vs {self.label.shape}")
            
            unique_labels = np.unique(self.label)
            print(f"Found {len(unique_labels)} unique labels")
            
            return True
            
        except Exception as e:
            print(f"Error loading data: {e}")
            return False
    
    def process_labels(self):
        """Apply erosion and color mapping to labels."""
        try:
            print("\nProcessing labels...")
            
            # Apply erosion to get outlines
            self.label_image_erosion = self.label.copy()
            unique_labels = np.unique(self.label_image_erosion)
            
            for i, l in enumerate(unique_labels):
                if l == 0:
                    continue
                mask = self.label_image_erosion == l
                erosion = binary_erosion(mask, iterations=1)
                self.label_image_erosion[erosion] = 0
                
                if (i + 1) % 10 == 0:
                    print(f"  Processed {i + 1}/{len(unique_labels)} labels")
            
            print(f"Erosion complete for {len(unique_labels)} labels")
            
            # Assign colors
            self.coloured_labels = self.assign_colors(self.label, self.colors)
            print(f"Colors assigned to {len(self.nifti_real)} voxels")
            
            return True
            
        except Exception as e:
            print(f"Error processing labels: {e}")
            return False
    
    def generate_images(self):
        """Generate all visualization images."""
        try:
            self.output_path.mkdir(parents=True, exist_ok=True)
            
            print(f"\nGenerating images...")
            
            slice_indices = self.get_slice_indices()
            
            # Check bounding boxes
            self.check_bounding_box('axial')
            self.check_bounding_box('coronal')
            self.check_bounding_box('sagittal')
            
            self.out_of_bounds = not all(self.bb_status.values())
            
            total_images = sum(len(v) for v in slice_indices.values())
            processed = 0
            
            # Get image dimensions
            dim_x, dim_y, dim_z = self.bg_image.shape
            
            # Get dynamic padded ranges based on segmentation extent
            x_range = self.get_padded_range('x', dim_x)
            y_range = self.get_padded_range('y', dim_y)
            z_range = self.get_padded_range('z', dim_z)
            
            print(f"\nDynamic FOV ranges (with {self.padding} voxel padding):")
            print(f"  X: {x_range.start}-{x_range.stop}")
            print(f"  Y: {y_range.start}-{y_range.stop}")
            print(f"  Z: {z_range.start}-{z_range.stop}")
            
            # Generate axial slices (viewing z, cropping x and y)
            for slice_num in slice_indices['axial']:
                if slice_num >= dim_z:
                    self.missing_slices['axial'].append(slice_num)
                    continue
                slice_range = [x_range, y_range, slice_num]
                if self.create_image(slice_range, 'axial', slice_num):
                    processed += 1
                    if processed % 10 == 0:
                        print(f"  Progress: {processed}/{total_images} images")
            
            # Generate coronal slices (viewing y, cropping x and z)
            for slice_num in slice_indices['coronal']:
                if slice_num >= dim_y:
                    self.missing_slices['coronal'].append(slice_num)
                    continue
                slice_range = [x_range, slice_num, z_range]
                if self.create_image(slice_range, 'coronal', slice_num):
                    processed += 1
                    if processed % 10 == 0:
                        print(f"  Progress: {processed}/{total_images} images")
            
            # Generate sagittal slices (viewing x, cropping y and z)
            for slice_num in slice_indices['sagittal']:
                if slice_num >= dim_x:
                    self.missing_slices['sagittal'].append(slice_num)
                    continue
                slice_range = [slice_num, y_range, z_range]
                if self.create_image(slice_range, 'sagittal', slice_num):
                    processed += 1
                    if processed % 10 == 0:
                        print(f"  Progress: {processed}/{total_images} images")
            
            print(f"Generated {processed} images successfully")
            
            return True
            
        except Exception as e:
            print(f"Error generating images: {e}")
            return False
    
    def write_bounding_box_log(self):
        """Write subject to bounding box failure log if out of bounds."""
        if not self.out_of_bounds or not self.bb_log:
            return
        
        try:
            # Use file locking to prevent race conditions in parallel processing
            import fcntl
            with open(self.bb_log, 'a') as f:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                f.write(f"{self.subject}\n")
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)
            print(f"Subject logged to bounding box failure file: {self.bb_log}")
        except Exception as e:
            print(f"Error writing to bounding box log: {e}")
    
    def print_summary(self):
        """Print final summary to console."""
        print("\n" + "=" * 60)
        print("QC SUMMARY")
        print("=" * 60)
        print(f"Subject: {self.subject}")
        print(f"Output:  {self.output_path}")
        print("")
        
        # Image counts
        print("Images Generated:")
        total = sum(self.image_counts.values())
        print(f"  Total:    {total}")
        print(f"  Axial:    {self.image_counts['axial']}")
        print(f"  Coronal:  {self.image_counts['coronal']}")
        print(f"  Sagittal: {self.image_counts['sagittal']}")
        print("")
        
        # Bounding box checks
        print("Bounding Box Checks:")
        bb_overall = "PASS" if not self.out_of_bounds else "FAIL"
        print(f"  Overall:  {bb_overall}")
        print(f"  Axial:    {'PASS' if self.bb_status['axial'] else 'FAIL'}")
        print(f"  Coronal:  {'PASS' if self.bb_status['coronal'] else 'FAIL'}")
        print(f"  Sagittal: {'PASS' if self.bb_status['sagittal'] else 'FAIL'}")
        print("")
        
        # Missing/failed slices
        has_missing = any(len(v) > 0 for v in self.missing_slices.values())
        if has_missing:
            print("Missing/Failed Slices:")
            for orientation, slices in self.missing_slices.items():
                if slices:
                    print(f"  {orientation.capitalize()}: {slices}")
            print("")
        
        # Overall status
        if total > 0 and not has_missing:
            print("Status: SUCCESS - All images generated")
        elif total > 0 and has_missing:
            print("Status: PARTIAL - Some images missing")
        else:
            print("Status: FAILED - No images generated")
        
        print("=" * 60)
    
    def run(self):
        """Execute the complete QC pipeline."""
        # Load colors
        try:
            self.colors = self.load_colors()
        except Exception as e:
            print(f"Failed to load colors: {e}")
            return False
        
        # Load data
        if not self.load_data():
            return False
        
        # Analyze label matching
        self.analyze_label_matching()
        
        # Process labels
        if not self.process_labels():
            return False
        
        # Generate images
        if not self.generate_images():
            return False
        
        # Log out-of-bounds subjects
        self.write_bounding_box_log()
        
        # Print summary
        self.print_summary()
        
        return True


def main():
    if len(sys.argv) < 7:
        print("Error: Insufficient arguments")
        sys.exit(1)
    
    subject = sys.argv[1]
    image = sys.argv[2]
    label = sys.argv[3]
    output = sys.argv[4]
    colormap = sys.argv[5]
    skip_level = sys.argv[6]
    bb_log = sys.argv[7] if len(sys.argv) > 7 and sys.argv[7] else None
    padding = sys.argv[8] if len(sys.argv) > 8 else 10
    
    qc = CerebellumQC(subject, image, label, output, colormap, skip_level, bb_log, padding)
    success = qc.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
PYTHON_SCRIPT

# Check Python exit status
PYTHON_EXIT=$?

if [[ $PYTHON_EXIT -eq 0 ]]; then
    echo ""
    echo "Subject ${SUBJECT_ID} completed successfully"
    chmod -R 770 "$OUTPUT_DIR"
    exit 0
else
    echo ""
    echo "Subject ${SUBJECT_ID} failed"
    exit 1
fi