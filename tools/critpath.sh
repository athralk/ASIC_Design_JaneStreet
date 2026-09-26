#!/usr/bin/env bash
# Print nextpnr's worst posedge->posedge path, with each hop's Verilog source line.
log=${1:-fpga/upduino/build/nextpnr.log}
src=${2:-gen/eth10t_demo.v}
awk '/Critical path report for clock/{f=1} /Critical path report for cross/{f=0} f' "$log" |
  grep -E "Source|Setup|$(basename "$src")" |
  while IFS= read -r line; do
    echo "$line"
    if [[ $line =~ $(basename "$src"):([0-9]+) ]]; then
      echo "        >> $(sed -n "${BASH_REMATCH[1]}p" "$src" | sed 's/^ *//')"
    fi
  done
