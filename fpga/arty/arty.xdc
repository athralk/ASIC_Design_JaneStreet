## Arty A7: on-board Ethernet (TI DP83848, MII), clock, reset button, SW0, LEDs.
## Pin locations from Digilent's Arty-A7 master XDC.

set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -name sys_clk -period 10.000 [get_ports CLK100MHZ]

set_property -dict { PACKAGE_PIN C2  IOSTANDARD LVCMOS33 } [get_ports ck_rst]
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports sw]

## Ethernet PHY
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports eth_ref_clk]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports eth_rstn]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports eth_mdc]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports eth_mdio]
set_property -dict { PACKAGE_PIN G14 IOSTANDARD LVCMOS33 } [get_ports eth_crs]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports eth_tx_clk]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports eth_tx_en]
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[0]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[2]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[3]}]
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports eth_rx_clk]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports eth_rx_dv]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[0]}]
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[1]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[2]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[3]}]

## LD4..LD7
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## MII clocks from the PHY: 25 MHz at 100 Mb/s (worst case), 2.5 MHz at 10 Mb/s.
create_clock -name eth_tx_clk -period 40.000 [get_ports eth_tx_clk]
create_clock -name eth_rx_clk -period 40.000 [get_ports eth_rx_clk]
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks sys_clk] \
    -group [get_clocks eth_tx_clk] \
    -group [get_clocks eth_rx_clk]

## MII timing at 100 Mb/s. The PHY samples TXD/TX_EN on TX_CLK's rising edge (10 ns
## setup, 0 ns hold) and drives RXD/RX_DV 10..30 ns after RX_CLK's rising edge.
## The MII flops sit in the I/O blocks, so the timing is the same on every build.
set_output_delay -clock eth_tx_clk -max 10.000 [get_ports {eth_tx_en eth_txd[*]}]
set_output_delay -clock eth_tx_clk -min 0.000  [get_ports {eth_tx_en eth_txd[*]}]
set_input_delay  -clock eth_rx_clk -max 30.000 [get_ports {eth_rx_dv eth_rxd[*]}]
set_input_delay  -clock eth_rx_clk -min 10.000 [get_ports {eth_rx_dv eth_rxd[*]}]
set_property IOB TRUE [get_ports {eth_tx_en eth_txd[*] eth_rx_dv eth_rxd[*]}]

## Slow or asynchronous pins (synchronised inside, or far slower than the clock).
set_false_path -from [get_ports {ck_rst sw eth_crs eth_mdio}]
set_false_path -to [get_ports {eth_rstn eth_mdc eth_mdio eth_ref_clk led[*]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
