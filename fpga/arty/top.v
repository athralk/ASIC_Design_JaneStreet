// Arty A7 board wrapper for the on-board Ethernet port (TI DP83848 PHY over MII).
//   100 MHz -> MMCM -> 60 MHz (design clock) and 25 MHz (PHY reference clock).
// Both come from one 900 MHz VCO, so the PHY's 2.5 MHz TX_CLK is locked to our clock.
module arty_top (
    input        CLK100MHZ,
    input        ck_rst,        // red RESET button, active low
    input  [1:0] sw,            // SW1..SW0: which view the LEDs show

    output       eth_ref_clk,   // 25 MHz to the PHY
    output       eth_rstn,
    input        eth_tx_clk,
    output       eth_tx_en,
    output [3:0] eth_txd,
    input        eth_rx_clk,
    input        eth_rx_dv,
    input  [3:0] eth_rxd,
    output       eth_mdc,
    inout        eth_mdio,

    output [3:0] led            // LD4..LD7
);
  wire clk60_mmcm, clk25_mmcm, clk, clk25, fb, locked;

  MMCME2_BASE #(
      .CLKIN1_PERIOD(10.0),
      .DIVCLK_DIVIDE(1),
      .CLKFBOUT_MULT_F(9.0),     // VCO = 900 MHz
      .CLKOUT0_DIVIDE_F(15.0),   // 60 MHz
      .CLKOUT1_DIVIDE(36)        // 25 MHz
  ) mmcm (
      .CLKIN1(CLK100MHZ),
      .CLKFBIN(fb),
      .CLKFBOUT(fb),
      .CLKOUT0(clk60_mmcm),
      .CLKOUT1(clk25_mmcm),
      .LOCKED(locked),
      .RST(1'b0),
      .PWRDWN(1'b0)
  );

  BUFG bufg60 (.I(clk60_mmcm), .O(clk));
  BUFG bufg25 (.I(clk25_mmcm), .O(clk25));

  // Forward the 25 MHz clock to the pin through an output DDR flop.
  ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) ref_clk_out (
      .Q(eth_ref_clk), .C(clk25), .CE(1'b1), .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0));

  reg [7:0] por = 0;
  always @(posedge clk)
    if (!locked || !ck_rst) por <= 0;
    else if (!por[7]) por <= por + 1'b1;

  wire mdio_o, mdio_oe, mdio_i;

  IOBUF mdio_buf (.IO(eth_mdio), .I(mdio_o), .O(mdio_i), .T(!mdio_oe));

  eth10t_arty eth10t (
      .clock(clk),
      .rst_n(por[7]),
      .sw(sw),
      .mdio_i(mdio_i),
      .eth_tx_clk(eth_tx_clk),
      .eth_rx_clk(eth_rx_clk),
      .eth_rx_dv(eth_rx_dv),
      .eth_rxd(eth_rxd),
      .eth_txd(eth_txd),
      .eth_tx_en(eth_tx_en),
      .eth_rstn(eth_rstn),
      .eth_mdc(eth_mdc),
      .mdio_o(mdio_o),
      .mdio_oe(mdio_oe),
      .led(led));   // LD4..LD7; see README for the three switch-selected views
endmodule
