#!/bin/bash

video_filename="$1"
workspace="frames"
result_filename="result.gif"

rm -rf "$workspace"
mkdir "$workspace"

ffmpeg -i "$video_filename" -vf "fps=4" "$workspace/%06d.png"

ordered_frames=($(ls $workspace | sort -t'.' -k 1 -n | sed -E "s/(.*)/$workspace\/\1/"))
frames_count="${#ordered_frames[@]}"
first_frame_filename="${ordered_frames[0]}"
magick "$first_frame_filename" -resize 700x "$first_frame_filename.r.png"
mv "$first_frame_filename.r.png" "$first_frame_filename"
frame_width=$(identify -format "%w" "$first_frame_filename")
frame_height=$(identify -format "%h" "$first_frame_filename")

function process_frame {
    local frame_filepath="$1"

    local frame_no="$(echo "$frame_filepath" | sed "s#$workspace/##" | cut -d'.' -f1 | bc)"
    local progbar_width="$((frame_width * frame_no / frames_count))"
    magick "$frame_filepath" -resize 700x "$frame_filepath.r.png"
    mv "$frame_filepath.r.png" "$frame_filepath"
    magick -size "${frame_width}x10" xc:none -fill red -draw "rectangle 0,0 $progbar_width,10" "$frame_filepath.bar.png"
    magick "$frame_filepath" -gravity north -background none -extent "${frame_width}x$((frame_height+10))" "$frame_filepath.tmp.png"
    composite -geometry +0+$frame_height "$frame_filepath.bar.png" "$frame_filepath.tmp.png" "$frame_filepath"
    pngquant --quality=65-80 --output "$frame_filepath.q.png" "$frame_filepath"
    mv "$frame_filepath.q.png" "$frame_filepath"
    rm "$frame_filepath.bar.png" "$frame_filepath.tmp.png"
}

max_threads=32
thread_no=0
for frame_filepath in "${ordered_frames[@]}"; do
    process_frame "$frame_filepath" &
    thread_no=$((thread_no + 1))
    if [[ $thread_no -eq $max_threads ]]; then thread_no=0; wait; fi
done
wait

frames_per_gif=32
subgifs_amount=$((frames_count / frames_per_gif))

for i in $(seq 0 $subgifs_amount)
do
    magick -delay 25 -loop 0 $(echo "${ordered_frames[@]:$(($frames_per_gif * i)):$(($frames_per_gif))}") "$workspace/$i.gif" &
    thread_no=$((thread_no + 1))
    if [[ $thread_no -eq $max_threads ]]; then thread_no=0; wait; fi
done
wait

magick $workspace/*.gif "$result_filename"
rm $workspace/*.gif
 
cleanup() {
  echo "Cleaning up..."
  pkill -P $$
}
 
trap cleanup SIGINT SIGTERM
