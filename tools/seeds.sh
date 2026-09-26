#!/usr/bin/env bash
# Place-and-route the UPduino build over several seeds and report Fmax for each.
cd "$(dirname "$0")/../fpga/upduino" || exit 1
tmp=$(mktemp -d)
for seed in ${SEEDS:-1 2 3 4 5 6 7 8}; do
  for placer in heap sa; do
    f=$(nextpnr-ice40 -q --up5k --package sg48 --freq 60 --pcf upduino.pcf \
          --json build/eth10t.json --asc "$tmp/x.asc" --seed "$seed" --placer "$placer" \
          --timing-allow-fail 2>&1 | grep -oE "Max frequency for clock 'clk': [0-9.]+" | tail -1 | grep -oE "[0-9.]+$")
    echo "$f seed=$seed placer=$placer"
  done
done | sort -rn
rm -rf "$tmp"
