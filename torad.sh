#!/bin/bash

# Look for nii.gz files, unzip them, use nii_to_radio
# to change the orientation, zip them again, pray it went fine.


function show_help() {
    cat > /dev/stdout << END
USAGE: ${0##*/} [-h]

ARGUMENTS:
-h: show help

DESCRIPTION:
A convenient wrapper around nii_to_radio.

This program takes no inputs, simply run it in a directory
containing nifti files and they will be converted to
radio format using nii_to_radio.

DEPENDENCIES:
- jacacb's nii_to_radio (not in this repo)
- gzip, gunzip

END
}

f_choose_compression() {
    # try to use pigz if installed, if not gzip
    if command -v pigz >/dev/null; then
        local COMPRESS_COMMAND="pigz -v"
    elif command -v gzip >/dev/null; then
        local COMPRESS_COMMAND="gzip -vf"
    else
        echo "!!! Neither gzip nor pigz found in path. Please, install one."
        echo "!!! Exiting"
        exit 1
    fi
    # debug :)
    echo "$COMPRESS_COMMAND"
}

f_choose_decompression() {
    if command -v pigz >/dev/null; then
        local DECOMPRESS_COMMAND="pigz -d"
        # check for gzip
    elif command -v gzip >/dev/null; then
        local DECOMPRESS_COMMAND="gunzip"
        # could not find any, exiting
    else
        echo "!!! Neither gzip nor pigz found in path. Please, install one."
        echo "!!! Exiting"
        exit 1
    fi
    # debug :)
    echo "$DECOMPRESS_COMMAND"
}

while getopts ":h" option; do
    case $option in
        h) # show help
           show_help
           exit 0;;
        ?) # invalid option -- show also help
           printf "!!! Invalid option: -%s\n" "$OPTARG" >&2
           show_help
           exit 1;;
    esac
done

NTR_EXE=$(command -v nii_to_radio)
if [[ -z ${NTR_EXE} ]]; then
    echo "!!! nifti_to_radio not found (maybe not in PATH)"
    echo "!!! Exiting"
    exit 1
fi

ZIP=$(f_choose_compression)
UNZIP=$(f_choose_decompression)

for f in $(find . -mindepth 1 -maxdepth 1 -type f -name "*.nii*"); do
    filename=${f##*/}
    ext=${filename#*.}
    if [[ ${ext} = "nii.gz" ]]; then
        echo "+++ Uncompressing"
        $UNZIP $f
    fi
    echo "+++ Changing orientation of ${f%*.gz}"
    nii_to_radio ${f%*.gz} radio
    # $COMPRESS_COMMAND ${f%.*}
    echo "+++ Compressing ${f%*.gz}"
    $ZIP ${f%*.gz}
    echo "+++ $filename converted to radio"
done
exit 0
