#!/bin/sh
# README GIF from the silent render: 960 px wide, 15 fps.
set -e
cd "$(dirname "$0")/.."
in=out/droplime-demo-silent.mp4
out=../images/demo.gif
filters="fps=15,scale=960:-1:flags=lanczos"
ffmpeg -loglevel error -y -i "$in" -vf "$filters,palettegen=max_colors=128:stats_mode=diff" out/palette.png
ffmpeg -loglevel error -y -i "$in" -i out/palette.png \
  -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" "$out"
ls -lh "$out"
