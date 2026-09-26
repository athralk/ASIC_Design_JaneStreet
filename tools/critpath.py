#!/usr/bin/env python3
"""Print nextpnr's worst clk->clk path from a --report JSON, one net per hop."""
import json
import sys

report = json.load(open(sys.argv[1]))
print("fmax:", {k: round(v["achieved"], 2) for k, v in report["fmax"].items()})
for cp in report["critical_paths"]:
    if cp["from"] != "posedge clk" or cp["to"] != "posedge clk":
        continue
    t = 0.0
    for hop in cp["path"]:
        t += hop["delay"]
        print(f"{t:6.2f}  {hop['type']:7} {hop.get('net', '')}")
