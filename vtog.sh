#!/bin/bash

VTOG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${VTOG_ROOT}/bash-logger/bash_logger.sh"
CSBL_SEVERITY_LEVEL=$CSBL_DEBUG
CSBL_LOG_TO_FILE='false'
source "${VTOG_ROOT}/help.sh"

if [[ $# -le 0 ]]; then
  print_help
  exit 1
fi

start=$SECONDS

function cleanup() {
  csbl_log_warn "Cleaning up..."
  pkill -P $$
  wait
  exit 1
}

trap cleanup SIGINT SIGTERM

for c in ffmpeg magick rm mkdir wc ls sed sort find echo; do
  if [[ -z "$(which $c)" ]]; then
    csbl_log_crit "Command=[$c] not installed, impossible to use script."
    exit 1
  fi
done

i=test.mov
ws=frames
o=res.gif
fps=4
w=
h=
quality=
maxthreads=32
help=
autocleanup='true'

for a in "$@"; do
  charset="[A-Za-z0-9./'\"_-]*"
  if [[ -n "$(echo "$a" | grep -E "^\-{1,2}($charset)(=$charset)?$")" ]]; then
    eval "$(echo "$a" | sed -E 's#^\-{1,2}##' | sed -E 's#^([^=]+)$#\1=1#')"
  fi
done

input=${input:-$i}
output=${output:-$o}
width=${width:-$w}
height=${height:-$h}

if [[ $help -eq 1 ]] || [[ -z "$input" ]]; then
  print_help
  exit 0
fi

if [[ ! -f "$input" ]]; then
  csbl_log_crit "Input file=[$input] does not exist, nothing to do, exiting."
  exit 1
fi

for v in ws output fps maxthreads; do
  if [[ -z "${!v}" ]]; then
    csbl_log_crit "Variable=[$v] cannot have empty value, did you override it's value?"
    exit 1
  fi
done

csbl_log_info "Process started. Preparing frames from video."

rm -rf "$ws"
mkdir "$ws"
csbl_log_success "Workspace directory=[${ws}] cleaned."

ffmpeg -i "$input" -vf "fps=$fps" "$ws/%06d.png" >/dev/null 2>&1

ordered_frames=($(ls $ws | sort -t'.' -k 1 -n | sed -E "s/(.*)/$ws\/\1/"))
frames_count="${#ordered_frames[@]}"
first_frame_filename="${ordered_frames[0]}"

if [[ $frames_count -lt 1 ]]; then
  csbl_log_crit "No frames found. Nothing extracted from file input=[$input], nothing to do, exiting."
  exit 1
fi

csbl_log_success "Frames ready. ${frames_count} frames prepared."

if [[ -n "$width" ]] || [[ -n "$height" ]]; then
  csbl_log_info "Resize requested to resolution=[${width:-auto}x${height:-auto}]."
  magick "$first_frame_filename" -resize ${width}x${height} "$first_frame_filename.r.png"
  mv "$first_frame_filename.r.png" "$first_frame_filename"
else
  csbl_log_info "No resize requested, both width and heighr nore provided."
fi
frame_width=$(identify -format "%w" "$first_frame_filename")
frame_height=$(identify -format "%h" "$first_frame_filename")

function process_frame {
  local frame_filepath="$1"

  local frame_no="$(echo "$frame_filepath" | sed "s#$ws/##" | cut -d'.' -f1 | bc)"
  local progbar_width="$((frame_width * frame_no / frames_count))"
  if [[ -n "$width" ]] || [[ -n "$height" ]]; then
    magick "$frame_filepath" -resize ${width}x${height} "$frame_filepath.r.png"
    mv "$frame_filepath.r.png" "$frame_filepath"
  fi
  magick "$frame_filepath" -alpha set "$frame_filepath"
  magick -size "${frame_width}x10" xc:none -alpha set -fill red -draw "rectangle 0,0 $progbar_width,10" "$frame_filepath.bar.png"
  magick "$frame_filepath" "$frame_filepath.bar.png" -append "$frame_filepath"
  if [[ -n "$quality" ]]; then
    pngquant --quality=$quality --output "$frame_filepath.q.png" "$frame_filepath"
    mv "$frame_filepath.q.png" "$frame_filepath"
  fi
  rm "$frame_filepath.bar.png"
}

thread_no=0
for frame_filepath in "${ordered_frames[@]}"; do
  csbl_log_debug "Frames with filepath=[$frame_filepath] is being processed within thread_no=[$thread_no]."
  process_frame "$frame_filepath" &
  thread_no=$((thread_no + 1))
  if [[ $thread_no -eq $maxthreads ]]; then thread_no=0; wait; fi
done
wait

frames_per_gif=32
subgifs_amount=$((frames_count / frames_per_gif))
if [[ $((frames_count % frames_per_gif)) -eq 0 ]]; then
  subgifs_amount=$((subgifs_amount - 1))
fi

for j in $(seq 0 $subgifs_amount)
do
  magick -delay 25 -loop 0 $(echo "${ordered_frames[@]:$(($frames_per_gif * j)):$(($frames_per_gif))}") "$ws/$(printf "%06d\n" "$j").gif" &
  csbl_log_debug "SubGIF with path=[$ws/$j.gif] created from [$frames_per_gif] frames."
  thread_no=$((thread_no + 1))
  if [[ $thread_no -eq $maxthreads ]]; then thread_no=0; wait; fi
done
wait
csbl_log_success "SubGIFs ready."

csbl_log_info "Joining them info final one."
magick $ws/*.gif "$output"
csbl_log_info "Joined into [$output]."

csbl_log_success "Workspace directory=[${ws}] cleaned again after job done."
if [[ "$autocleanup" == 'true' ]]; then
  rm -rf $ws
fi

csbl_log_info "Script took [$((SECONDS - s))] seconds."
