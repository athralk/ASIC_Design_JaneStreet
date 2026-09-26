GEN   := ../../gen
BUILD := build
SRC   := top.v $(GEN)/eth10t_demo.v
NEXTPNR_FLAGS ?= --seed 8 --placer sa

all: $(BUILD)/eth10t.bin

$(BUILD)/eth10t.json: $(SRC) Makefile
	mkdir -p $(BUILD)
	yosys -q -l $(BUILD)/yosys.log \
	  -p "synth_ice40 -device u -abc9 -dff -top upduino_top; delete t:\$$scopeinfo; write_json $@" $(SRC)

$(BUILD)/eth10t.asc: $(BUILD)/eth10t.json upduino.pcf
	nextpnr-ice40 -q -l $(BUILD)/nextpnr.log --up5k --package sg48 --freq 60 \
	  --pcf upduino.pcf --json $< --asc $@ --report $(BUILD)/timing.json $(NEXTPNR_FLAGS)

$(BUILD)/eth10t.bin: $(BUILD)/eth10t.asc
	icepack $< $@

prog: $(BUILD)/eth10t.bin
	iceprog $<

clean:
	rm -rf $(BUILD)

.PHONY: all prog clean
