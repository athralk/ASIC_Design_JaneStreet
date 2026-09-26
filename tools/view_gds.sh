#!/usr/bin/env bash
# Open the hardened GDS in KLayout (from the OpenLane image) as a window via WSLg.
#   tools/view_gds.sh [file.gds]
set -euo pipefail
cd "$(dirname "$0")/.."
gds=${1:-runs/wokwi/final/gds/tt_um_eth10t.gds}
pdk=$(ls -d "$HOME"/.volare/volare/sky130/versions/* | head -1)

docker run --rm -u "$(id -u):$(id -g)" \
  -e DISPLAY="$DISPLAY" -e WAYLAND_DISPLAY -e XDG_RUNTIME_DIR=/tmp \
  -v /tmp/.X11-unix:/tmp/.X11-unix -v /mnt/wslg:/mnt/wslg \
  -v "$PWD":/work -v "$pdk":/pdk -w /work \
  ghcr.io/efabless/openlane2:2.3.10 \
  klayout -nn /pdk/sky130A/libs.tech/klayout/tech/sky130A.lyt \
          -l /pdk/sky130A/libs.tech/klayout/tech/sky130A.lyp "$gds"
