#!/usr/bin/env bash
# Harden the tile to GDS exactly as TinyTapeout's `tt_tool.py --harden` does:
# src/config.json + TT's die area and pin/power DEF template -> OpenLane 2 (Docker).
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d tt ] || git clone --depth 1 -b ttsky25a https://github.com/TinyTapeout/tt-support-tools tt

python3 - <<'PY'
import json, re, yaml
info = yaml.safe_load(open("info.yaml"))["project"]
tiles = info["tiles"]
die = yaml.safe_load(open("tt/tile_sizes.yaml"))[tiles]
# config.json allows repeated "//" comment keys; json.load keeps the last, which is fine.
config = json.load(open("src/config.json"))
config.update({
    "DESIGN_NAME": info["top_module"],
    "VERILOG_FILES": [f"dir::{f}" for f in info["source_files"]],
    "DIE_AREA": die,
    "FP_DEF_TEMPLATE": f"dir::../tt/def/tt_block_{tiles}_pg.def",
})
json.dump(config, open("src/config_merged.json", "w"), indent=2)
PY

rm -rf runs/wokwi
mkdir -p runs/wokwi
python3 -m openlane --docker-no-tty --dockerized --run-tag wokwi --force-run-dir runs/wokwi \
  src/config_merged.json
