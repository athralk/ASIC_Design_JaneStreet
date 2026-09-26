# 10BASE-T in Hardcaml: one entry point for every stage.
#
#   make test      Hardcaml simulation suite (compliance, random, jitter, errors)
#   make verilog   generate src/tt_um_eth10t.v and gen/*.v
#   make lint      verilator lint of the tile
#   make formal    k-induction proof of the safety properties (yosys SAT)
#   make stat      cell/LUT counts for iCE40 and sky130
#   make fpga      UPduino bitstream (make prog to flash)
#   make arty      copy the Arty A7 Vivado build to D:\JaneStreet_Chip\eth10t (then run build.tcl)
#   make cocotb    TinyTapeout cocotb test on the RTL (needs cocotb + iverilog)
#   make harden    TinyTapeout GDS via OpenLane 2 (Docker)
#   make gl        cocotb test on the hardened gate-level netlist (hardens if needed)
#   make view      open the GDS in KLayout (window via WSLg); make gds-png renders an image

PDK_ROOT ?= $(HOME)/.volare
TOP      := tt_um_eth10t

.PHONY: all test verilog lint formal stat fpga prog arty cocotb harden gl view gds-png clean

all: test verilog lint formal stat

test:
	dune test

verilog:
	dune build
	dune exec hardcaml/bin/gen.exe -- gen src

lint: verilog
	verilator --lint-only -Wall -Wno-UNUSEDSIGNAL -Wno-DECLFILENAME src/$(TOP).v

formal: verilog
	yosys -q -l gen/formal.log formal/run.ys
	@grep -q "Induction step proven: SUCCESS" gen/formal.log && echo "formal: all properties proven"

stat: verilog
	@echo "== iCE40 (UP5K)"
	@yosys -q -p "synth_ice40 -device u -abc9 -dff -top $(TOP); tee -o /dev/stdout stat" src/$(TOP).v \
	  | grep -E "SB_LUT4|SB_CARRY|SB_DFF|cells$$"
	@echo "== sky130_fd_sc_hd (pre-layout)"
	@yosys -q -p "synth -top $(TOP) -flatten; dfflibmap -liberty $(LIB); abc -liberty $(LIB); \
	  opt_clean; tee -o /dev/stdout stat -liberty $(LIB)" src/$(TOP).v \
	  | grep -E "cells$$|Chip area"

LIB := $(firstword $(wildcard $(PDK_ROOT)/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib))

fpga: verilog
	$(MAKE) -C fpga/upduino

prog: fpga
	$(MAKE) -C fpga/upduino prog

# Vivado on Windows is unreliable on \\wsl.localhost paths, so copy to a D: folder.
ARTY_DIR ?= /mnt/d/JaneStreet_Chip/eth10t

arty: verilog
	mkdir -p $(ARTY_DIR)
	rm -f $(ARTY_DIR)/eth10t_demo.v
	cp fpga/arty/top.v fpga/arty/arty.xdc fpga/arty/build.tcl fpga/arty/program.tcl fpga/arty/README.md \
	  gen/eth10t_arty.v $(ARTY_DIR)/
	@echo "In Vivado's Tcl console:  cd D:/JaneStreet_Chip/eth10t ; source build.tcl"

cocotb: verilog
	cd test && $(MAKE) -B

harden: verilog
	tools/harden.sh

NETLIST := runs/wokwi/final/pnl/$(TOP).pnl.v

$(NETLIST):
	$(MAKE) harden

gl: $(NETLIST)
	cp $(NETLIST) test/gate_level_netlist.v
	cd test && $(MAKE) -B GATES=yes PDK_ROOT=$(firstword $(wildcard $(PDK_ROOT)/volare/sky130/versions/*))

GDS := runs/wokwi/final/gds/$(TOP).gds

view: $(NETLIST)
	tools/view_gds.sh $(GDS)

gds-png: $(NETLIST)
	docker run --rm -u $$(id -u):$$(id -g) -v $$PWD:/work -w /work \
	  -v $(firstword $(wildcard $(PDK_ROOT)/volare/sky130/versions/*)):/pdk \
	  ghcr.io/efabless/openlane2:2.3.10 klayout -zz -r tools/render_gds.py \
	  -rd gds=$(GDS) -rd lyp=/pdk/sky130A/libs.tech/klayout/tech/sky130A.lyp -rd out=gen/$(TOP).png
	@echo "wrote gen/$(TOP).png"

clean:
	dune clean
	rm -rf gen runs test/sim_build test/results.xml test/*.fst test/gate_level_netlist.v
	$(MAKE) -C fpga/upduino clean
