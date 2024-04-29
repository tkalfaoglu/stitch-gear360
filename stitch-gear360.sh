#!/bin/bash
#===============================================================================
# Stitching tool for 360° videos captured by the Samsung Gear 360 (SM-C200)    #
# Bash script by https://github.com/bilde2910 and licensed under MIT License   #
# Requires fisheyeStitcher: https://github.com/drNoob13/fisheyeStitcher        #
#==============================================================================#

# Constants
MLS_MAP_PATH="/usr/share/fisheye-stitcher/grid_xd_yd_3840x1920.yml.gz"

# general purpose - edit as you wish:  maybe adding -hwaccel if your setup permits?
FFMPEG_OPTS= "-hide_banner -loglevel error -stats"

# just for sound extraction - don't put hwaccel here.
FFMPEG_OPTS2="-hide_banner -loglevel error -stats"

help() {
    cat << EOF
${FMT_BOLD}Stitching tool for 360° videos captured by the Samsung Gear 360 (SM-R210)${FMT_STD}
Copyright (c) 2020 Marius Lindvall under the MIT License
Much modification by Turgut Kalfaoglu turgut@kalfaoglu.com to add Samsung Gear 360 2017 (R210) and Sound support

${FMT_ULINE}Usage:${FMT_STD}
    $0 ${FMT_H_BRACKET}[${FMT_H_PARAM}options${FMT_H_BRACKET}]${FMT_STD} ${FMT_H_PARAM}input1 input2 ${FMT_H_ELLIP}...${FMT_H_PARAM} output${FMT_STD}
${FMT_ULINE}Options:${FMT_STD}
    ${FMT_H_ARG}-a${FMT_STD}, ${FMT_H_ARG}--refine-alignment${FMT_STD}  Enable alignment refinement.
    ${FMT_H_ARG}-f${FMT_STD}, ${FMT_H_ARG}--force${FMT_STD}             Bypass input filename validation.
    ${FMT_H_ARG}-h${FMT_STD}, ${FMT_H_ARG}--help${FMT_STD}              Print this help page and exit.
    ${FMT_H_ARG}-l${FMT_STD}, ${FMT_H_ARG}--compensate-light${FMT_STD}  Enable light compensation.

Valid input files are one or more .mp4 videos of approx. 3840x1920 resolution from the
SM-R210. This program will first resize all input files to the above resolution, and then process them.

If multiple input videos are specified, they will be joined together to one long output file.

The output file must be an .mp4 file.
EOF
    exit 0
}

# Helper functions
echo_err() {
    echo "${FMT_BOLD}${FMT_ERR}$1${FMT_STD}" > /dev/stderr
}

echo_warn() {
    echo "${FMT_BOLD}${FMT_WARN}$1${FMT_STD}" > /dev/stderr
}

echo_head() {
    for ((echo_head_i = 0; echo_head_i < "$1"; echo_head_i++)); do echo ""; done
    echo "${FMT_BOLD}${FMT_HEAD}>> $3${FMT_STD}"
    for ((echo_head_i = 0; echo_head_i < "$2"; echo_head_i++)); do echo ""; done
}

echo_ok() {
    echo "${FMT_OK}ok${FMT_STD}"
}

echo_fail() {
    echo "${FMT_ERR}fail${FMT_STD}"
}

cleanup() {
    rm -rf "${CACHE_DIR}"
}

# Check if we're in a terminal and support colors.
if test -t 1; then
    ncolors=$(tput colors)
    if test -n "$ncolors" && test $ncolors -ge 8; then
        FMT_BOLD="$(tput bold)"
        FMT_ULINE="$(tput smul)"
        FMT_ERR="$(tput setaf 1)"
        FMT_WARN="$(tput setaf 3)"
        FMT_OK="$(tput setaf 2)"
        FMT_HEAD="$(tput setaf 6)"
        FMT_STD="$(tput sgr0)"

        # Help screen coloring.
        FMT_H_ARG="$(tput setaf 6)"
        FMT_H_BRACKET="$(tput setaf 6)"
        FMT_H_PARAM="$(tput setaf 5)"
        FMT_H_ELLIP="$(tput setaf 6)"
    fi
fi

# Parse arguments; print help menu if no arguments are given.
if [[ $# -eq 0 ]] ; then
    help
fi

USE_LC=false
USE_RA=false
JOIN=false
BYPASS_FNV=false

while test $# -gt 0; do
    case "$1" in
        -a|--refine-alignment)
            shift
            USE_RA=true
            ;;
        -f|--force)
            shift
            BYPASS_FNV=true
            ;;
        -h|--help)
            help
            ;;
        -j|--join)
            shift
            JOIN=true
            ;;
        -l|--compensate-light)
            shift
            USE_LC=true
            ;;
        *)
            break
            ;;
    esac
done

# Check for dependencies.
deps=("fisheyeStitcher" "ffmpeg" "ffprobe" "spatialmedia")
filedeps=("${MLS_MAP_PATH}")
for dep in "${deps[@]}"; do
    echo -n "Checking dependency ${dep}... "
    if ! command -v "${dep}" &> /dev/null; then
        echo_fail
        echo_err "Missing dependency ${dep}! Cannot continue."
        exit 1
    fi
    echo_ok
done
for file in "${filedeps[@]}"; do
    echo -n "Checking file ${file}... "
    if ! [ -f "$file" ]; then
        echo_fail
        echo_err "Missing file ${file}! Cannot continue."
        exit 1
    fi
    echo_ok
done

# Ensure that we have at least one input and output file.
case "$#" in
    0)
        echo_err "No input or output file(s) specified."
        echo "Check syntax using $0 --help." > /dev/stderr
        exit 1;
        ;;
    1)
        echo_err "No input file(s) specified."
        echo "Check syntax using $0 --help." > /dev/stderr
        exit 1;
        ;;
esac

# Validate input files and put them in an array.

echo_head 1 1 "Rescaling videos into resized/ directory..."

mkdir resized
rm tmpsounds 2>/dev/null

INPUTS=()
SOUNDS=()
while test $# -gt 1; do
    echo -n "Validating '$1'... "
    if ! [ -f "$1" ]; then
        echo_fail
        echo_err "Error: File not found: '$1'"
        exit 1
    fi

    echo_ok
    INPUTS+=("resized/$1")
    echo "file resized/$1" >> tmpsounds
    echo  ffmpeg ${FFMPEG_OPTS}  -i $1 -vf scale=3840:1920  -c:a copy -vcodec libx264 -crf 22 -preset ultrafast resized/$1
          ffmpeg ${FFMPEG_OPTS}  -i $1 -vf scale=3840:1920  -c:a copy -vcodec libx264 -crf 22 -preset ultrafast resized/$1
    shift
done

# extract audio

echo_head 1 1 "Extracting audio into tmpsound.aac"

rm tmpsound.mp3 2>/dev/null
echo ffmpeg ${FFMPEG_OPTS2} -f concat -safe 0 -i tmpsounds -c copy tmpsound.aac
     ffmpeg ${FFMPEG_OPTS2} -f concat -safe 0 -i tmpsounds -c copy tmpsound.aac
if ! [ $? -eq 0 ]; then
   echo_err "Error: Extracting audio failed"
   rm tmpsounds
   cleanup
   exit 1
fi
rm tmpsounds

# Validate output filename.
echo -n "Validating output filename... "
OUTPUT="$1"
if [[ ! "$OUTPUT" =~ .(MP4|mp4)$ ]]; then
    echo_fail
    echo_err "Error: Output filename is invalid, must be .mp4 file."
    exit 1
fi
echo_ok

# fisheye-stitcher cannot output to pipe, so we'll find the proper cache
# directory, see https://wiki.archlinux.org/index.php/XDG_Base_Directory
if [[ -z "${XDG_CACHE_HOME}" ]]; then
    CACHE_DIR="${HOME}/.cache/stitch-gear360"
else
    CACHE_DIR="${XDG_CACHE_HOME}/stitch-gear360"
fi

# Generate a random subdirectory to avoid file conflicts.
CACHE_DIR="${CACHE_DIR}/$(tr -dc 0-9a-f </dev/urandom | head -c 8)"
echo -n "Creating cache directory... "
mkdir -p "${CACHE_DIR}"
if ! [ $? -eq 0 ]; then
    echo_fail
    echo_err "Error: Failed to create cache directory."
fi
echo_ok

# Stitch each video using fisheyeStitcher. Store outputs in cache directory.
for ((i = 0; i < ${#INPUTS[@]}; i++)); do
    current="${INPUTS[$i]}"
    base="$(basename "$current")"
    echo_head 1 0 "Stitching input $(($i+1)) of ${#INPUTS[@]}..."
    fisheyeStitcher \
        --out_dir "${CACHE_DIR}" \
        --img_nm "${i}" \
        --video_path "${current}" \
        --mls_map_path "${MLS_MAP_PATH}" \
        --enb_lc "${USE_LC}" \
        --enb_ra "${USE_RA}" \
        --mode video
    if ! [ $? -eq 0 ]; then
        echo_err "Error: Stitching failed for input '$current'."
        cleanup
        exit 1
    fi
    echo "file '${CACHE_DIR}/${i}_blend_video.avi'" >> "${CACHE_DIR}/ffmpeg-queue.txt"
done

# Remux the video to mp4 and join them together.
echo_head 1 1 "Joining videos with ffmpeg..."
#    -fflags +genpts \ # appears to be buggy
echo ffmpeg  -f concat ${FFMPEG_OPTS} -safe 0 -vcodec libx264 -crf 22 -preset ultrafast -i "${CACHE_DIR}/ffmpeg-queue.txt" "${CACHE_DIR}/ffmpeg-output.mp4"
     ffmpeg  -f concat ${FFMPEG_OPTS} -safe 0 -vcodec libx264 -crf 22 -preset ultrafast -i "${CACHE_DIR}/ffmpeg-queue.txt" "${CACHE_DIR}/ffmpeg-output.mp4"
if ! [ $? -eq 0 ]; then
    echo_err "Error: Failed to join videos."
    cleanup
    exit 1
fi

echo
echo_head 1 1 "Adding Sound back to resulting file.."
rm tmpahami.mp4  2> /dev/null
echo ffmpeg ${FFMPEG_OPTS} -i "${CACHE_DIR}/ffmpeg-output.mp4" -i tmpsound.aac -c copy -map 0:v:0 -map 1:a:0 tmpahami.mp4
     ffmpeg ${FFMPEG_OPTS} -i "${CACHE_DIR}/ffmpeg-output.mp4" -i tmpsound.aac -c copy -map 0:v:0 -map 1:a:0 tmpahami.mp4
rm "${CACHE_DIR}/ffmpeg-output.mp4"
mv tmpahami.mp4 "${CACHE_DIR}/ffmpeg-output.mp4"
rm tmpsound.mp3

# Add 360° video metadata.
echo_head 1 1 "Injecting spatial metadata..."
echo spatialmedia  -i "${CACHE_DIR}/ffmpeg-output.mp4" "${OUTPUT}"
     spatialmedia  -i "${CACHE_DIR}/ffmpeg-output.mp4" "${OUTPUT}"
if ! [ $? -eq 0 ]; then
    echo_err "Error: Failed to inject spatial metadata."
    cleanup
    exit 1
fi

# Done!
echo_head 1 1 "Video stitching completed."

echo -n "Deleting cached data... "
cleanup
if ! [ $? -eq 0 ]; then
    echo_fail
    echo_warn "Warning: Failed to clean cached data."
else
    echo_ok
fi

echo "Success: Stitched video file written to '${OUTPUT}'."
rm -Rf resized
