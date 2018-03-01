#!/bin/bash

# AUTHOR: José P Valdés-Herrera

# description and help
function show_help() {
    cat > /dev/stdout << END
USAGE: ${0##*/} [-h] -s id -d subjects/dir -o output -i analysis_id

DESCRIPTION:
${0##*/} transforms hippocampal and amygdala Freesurfer segmentation to nifti
and extract masks corresponding to segmented labels. More info on FreeSurfer
segmentation of hippocampal subfields and amygdala:
https://surfer.nmr.mgh.harvard.edu/fswiki/HippocampalSubfieldsAndNucleiOfAmygdala

The script assumes segmentHA has been used to segment the image.

REQUIRED ARGS:
-s: subject id
-d: subjects directory (SUBJECTS_DIR)
-o: output dir
-i: analysis id

DEPENDENCIES:
This script depends on write_masks_script.awk. The awk file should be located in
the same directory as ${0##*/} (currently ${0%/*}).

NOTE: 
The output dir will be created within the subject directory in the
subjects directory.

END
}

function show_error_required() {
    cat > /dev/stderr << END
ERROR: missing argument/s. 

Actual values:

-d ${SUBJECTS_DIR}
-s ${SUBJ}
-o ${OUTPUT_DIR}
-i ${HIPPO_ID}

END
show_help
}

# reset vars
# note: SUBJECTS_DIR is necessary because using only the --sd flag does
# not work for all commands
SUBJECTS_DIR=""
OUTPUT_DIR=""
SUBJ=""
HIPPO_ID=""

# it seems the hippocampal segmentation module assigns a version to the output
# for example: v21
# this var controls that field in the segmentation output filename
# so that if the script breaks due to a new version, only this needs to be
# modified
# the script can be run easily with other versions only after this minor modification
# but I'd rather not add another command line arg more
VER="v21"

# Parse args
while getopts "h?:s:o:d:i:" opt; do
    case "${opt}" in
        h|\?)
            show_help
            exit 0;;
        s)
            SUBJ=${OPTARG};;
        o)
            OUTPUT_DIR=${OPTARG};;
        d)
            SUBJECTS_DIR=${OPTARG};;
        i)
            HIPPO_ID=${OPTARG};;
    esac
done

# this script depends on the awk script parsing the sum file output
AWK_SCRIPT=${0%/*}/write_masks_script.awk
if [[ ! -f ${AWK_SCRIPT} ]]; then
    echo !!! Error: ${AWK_SCRIPT} not found
    echo !!! Exiting
    exit 1
fi

if [[ -z ${SUBJ} || -z ${SUBJECTS_DIR} || -z ${OUTPUT_DIR} || -z ${HIPPO_ID} ]]; then
    show_error_required
    exit 1
fi

SINK_DIR=${SUBJECTS_DIR}/${SUBJ}/${OUTPUT_DIR}
if [[ ! -d ${SINK_DIR} ]]; then
    mkdir -p ${SINK_DIR}
fi

pushd ${SINK_DIR}
for hemi in rh lh; do
    this_mgz=${SUBJECTS_DIR}/${SUBJ}/mri/${hemi}.hippoAmygLabels-T1-${HIPPO_ID}.${VER}.mgz
    this_nifti=${SINK_DIR}/${hemi}.hippoAmygLabels-T1-${HIPPO_ID}.${VER}.nii.gz 
    this_sum=${SINK_DIR}/${hemi}.hippoAmygLabels.sum
    this_labid=${SINK_DIR}/${hemi}.label_ids.txt
    this_script=${SINK_DIR}/${hemi}_extract_masks.sh
    echo +++ Transform to native space: ${hemi}
    # Transform to nifti, but in raw space (our original T1 input)
    mri_vol2vol --mov ${this_mgz} \
        --targ ${SUBJECTS_DIR}/${SUBJ}/mri/rawavg.mgz \
        --regheader \
        --o ${this_nifti} \
        --no-save-reg
    # extract labels from mgz
    echo +++ Extract labels: ${hemi}
    mri_segstats --seg ${this_mgz} --excludeid 0 \
        --ctab ${FREESURFER_HOME}/FreeSurferColorLUT.txt \
        --sum ${this_sum}
    # parse sum file and write script extracting all ROI using gawk
    echo +++ Writing script to extract the ${hemi} masks
    gawk -f ${AWK_SCRIPT} -v niftifile=${this_nifti} -v hemi=${hemi} \
        ${this_sum} > ${this_script}
    chmod +x ${this_script}
    echo +++ Extracting all ${hemi} ROI
    ${this_script}
done
popd

echo +++ All done
echo +++ Files can be found in ${SINK_DIR}
echo +++ Bye
exit 0
