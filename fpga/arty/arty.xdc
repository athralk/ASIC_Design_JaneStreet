## Arty A7: on-board Ethernet (TI DP83848, MII), clock, reset button, LEDs.
## Pin locations from Digilent's Arty-A7 master XDC.

set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports CLK100MHZ]
create_clock -name sys_clk -period 10.000 [get_ports CLK100MHZ]

set_property -dict { PACKAGE_PIN C2  IOSTANDARD LVCMOS33 } [get_ports ck_rst]

## Ethernet PHY
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports eth_ref_clk]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports eth_rstn]
set_property -dict { PACKAGE_PIN F16 IOSTANDARD LVCMOS33 } [get_ports eth_mdc]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports eth_mdio]
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

## SW0, SW1 (choose the LED view)
set_property -dict { PACKAGE_PIN A8  IOSTANDARD LVCMOS33 } [get_ports {sw[0]}]
set_property -dict { PACKAGE_PIN C11 IOSTANDARD LVCMOS33 } [get_ports {sw[1]}]

## LD4..LD7
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## The 2.5 MHz MII clocks are sampled as data (2-flop synchronisers at 60 MHz), and
## TXD/TX_EN change a few cycles after TX_CLK rises, ~400 ns before the PHY samples
## them. So the MII and other slow pins need no I/O timing constraints.
set_false_path -from [get_ports {ck_rst sw[*] eth_tx_clk eth_rx_clk eth_rx_dv eth_rxd[*] eth_mdio}]
set_false_path -to [get_ports {eth_tx_en eth_txd[*] eth_rstn eth_mdc eth_mdio eth_ref_clk led[*]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
