#!/bin/bash

# AUTHOR: José P Valdés-Herrera

# description and help
function show_help() {
    cat > /dev/stdout << END
USAGE: ${0##*/} [-h] -s id -d subjects/dir -o output

DESCRIPTION:
${0##*/} wraps all commands needed to extract cortical ROIs after running
FreeSurfer's recon-all.

REQUIRED ARGS:
-s: subject id
-d: subjects directory (SUBJECTS_DIR)
-o: output dir

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

END
show_help
}

# note: SUBJECTS_DIR is necessary because using only the --sd flag does
# not work for all commands
SUBJECTS_DIR=""
OUTPUT_DIR=""
SUBJ=""

# Parse args
while getopts "h?:s:o:d:" opt; do
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
    esac
done

if [[ ${SUBJ} = "" || ${SUBJECTS_DIR} = "" || ${OUTPUT_DIR} = "" ]]; then
    show_error_required
    exit 1
fi

SINK_DIR=${SUBJECTS_DIR}/${SUBJ}/${OUTPUT_DIR}
mkdir -p ${SINK_DIR}

echo +++ Generate labels

# generate labels with mri_annotation2label
for hemi in lh rh; do
    mri_annotation2label --subject ${SUBJ} --hemi ${hemi}\
        --outdir ${SINK_DIR} --annotation aparc.a2009s
done

echo +++ Transform to native space

# transform from FS space to native space with tkregister2
tkregister2 --mov ${SUBJECTS_DIR}/${SUBJ}/mri/rawavg.mgz --noedit \
    --s ${SUBJ} --regheader --reg ${SINK_DIR}/${SUBJ}_register.dat

echo +++ Extract ROI volumes

# extract ROI volumes from labels with  mri_label2vol 
for hemi in rh lh; do
    for label in $(ls ${SINK_DIR}/${hemi}.*.label); do
        # like using basename
        labelname=${label##*/}
        # like using dirname
        cleanlabel=${labelname%.*}
        mri_label2vol --label ${label} \
            --temp ${SUBJECTS_DIR}/${SUBJ}/mri/rawavg.mgz --subject ${SUBJ} \
            --hemi ${hemi} --proj frac 0 1 .1 \
            --fillthresh .5 --reg ${SINK_DIR}/${SUBJ}_register.dat \
            --o ${SINK_DIR}/${SUBJ}_${cleanlabel}.nii.gz
    done
done

echo +++ Done
echo +++ Files should be found in ${SINK_DIR}
echo +++ Bye
exit 0
