#!/usr/bin/env bash
set -euo pipefail

video_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$video_dir/composition"

npx --yes hyperframes@0.8.91 check
npx --yes hyperframes@0.8.91 render --quality looks --output ../brag.render.mp4

ffmpeg -y -ss 1.8 -i ../brag.render.mp4 -frames:v 1 -q:v 2 ../brag.jpg
ffmpeg -y -i ../brag.render.mp4 -i ../brag.jpg \
  -filter_complex "[0:v][1:v]overlay=0:0:enable='eq(n,0)'[v]" \
  -map '[v]' -map '0:a?' -c:v libx264 -crf 18 -preset medium \
  -pix_fmt yuv420p -c:a copy -movflags +faststart ../brag.mp4
rm ../brag.render.mp4
