#!/bin/zsh
# Builds seamless, web-sized, silent loops + poster frames from TouchDesigner renders.
# Usage: ./make-loops.sh <src_dir> <clip-number>...    e.g. ./make-loops.sh ~/Desktop/touchdesigner/assets/website 1 2 3
# The loop is made by crossfading the clip's tail into its head so the last frame
# flows into the first. Output: assets/video/NN.mp4, assets/poster/NN.jpg
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"; FF="$ROOT/.tools/ffmpeg"
SRC="$1"; shift
START=1.0     # skip the first second (TD warm-up)
LEN=13.0      # seconds of source used (before crossfade)
X=2.0         # crossfade length
for n in "$@"; do
  in="$SRC/website$n.mp4"; id=$(printf "%02d" "$n")
  read w h <<<"$("$FF" -hide_banner -i "$in" 2>&1 | grep -oE ', [0-9]{3,4}x[0-9]{3,4}' | head -1 | tr -d ', ' | tr 'x' ' ')"
  if (( h > w )); then SCALE="scale=540:960"; else SCALE="scale=960:540"; fi
  t_main=$(printf "%.2f" $(( START + X ))); t_end=$(printf "%.2f" $(( START + LEN ))); t_head=$(printf "%.2f" $(( START + X )))
  off=$(printf "%.2f" $(( LEN - X - X )))
  "$FF" -hide_banner -loglevel error -y -i "$in" -filter_complex \
   "[0:v]trim=start=${t_main}:end=${t_end},setpts=PTS-STARTPTS,fps=30[main]; \
    [0:v]trim=start=${START}:end=${t_head},setpts=PTS-STARTPTS,fps=30[head]; \
    [main][head]xfade=transition=fade:duration=${X}:offset=${off},${SCALE},format=yuv420p[v]" \
   -map "[v]" -an -c:v libx264 -preset slow -crf 27 -movflags +faststart "$ROOT/assets/video/$id.mp4"
  # poster = brightest sampled frame, so dark clips don't get a black thumbnail
  best=$("$FF" -hide_banner -i "$ROOT/assets/video/$id.mp4" -vf "fps=2,signalstats,metadata=print:key=lavfi.signal_stats.YAVG:file=-" -f null - 2>/dev/null \
    | awk -F'[: =]' '/pts_time/{for(i=1;i<=NF;i++) if($i=="pts_time") t=$(i+1)} /YAVG/{v=$NF+0; if(v>m){m=v;bt=t}} END{print bt+0}')
  "$FF" -hide_banner -loglevel error -y -ss "$best" -i "$ROOT/assets/video/$id.mp4" -frames:v 1 -q:v 4 "$ROOT/assets/poster/$id.jpg"
  echo "$id: $(du -h "$ROOT/assets/video/$id.mp4" | cut -f1) video, $(du -h "$ROOT/assets/poster/$id.jpg" | cut -f1) poster"
done
