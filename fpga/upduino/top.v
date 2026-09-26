// UPduino v3 (iCE40UP5K-SG48): 12 MHz -> 60 MHz PLL, power-on reset, RGB LED.
module upduino_top (
    input  clk_12m,
    input  rd,
    output td_p,
    output td_n,
    output led_red,
    output led_green,
    output led_blue
);
  wire clk, locked;

  SB_PLL40_PAD #(
      .FEEDBACK_PATH("SIMPLE"),
      .DIVR(4'b0000),
      .DIVF(7'b1001111),
      .DIVQ(3'b100),
      .FILTER_RANGE(3'b001)
  ) pll (
      .PACKAGEPIN(clk_12m),
      .PLLOUTGLOBAL(clk),
      .LOCK(locked),
      .RESETB(1'b1),
      .BYPASS(1'b0)
  );

  reg [7:0] por = 0;
  always @(posedge clk) if (!locked) por <= 0; else if (!por[7]) por <= por + 1'b1;

  wire r, g, b;
  eth10t_demo demo (
      .clock(clk), .rst_n(por[7]), .rd(rd),
      .td_p(td_p), .td_n(td_n), .led_r(r), .led_g(g), .led_b(b));

  SB_RGBA_DRV #(
      .CURRENT_MODE("0b1"),
      .RGB0_CURRENT("0b000001"),
      .RGB1_CURRENT("0b000001"),
      .RGB2_CURRENT("0b000001")
  ) rgb (
      .CURREN(1'b1), .RGBLEDEN(1'b1),
      .RGB0PWM(g), .RGB1PWM(b), .RGB2PWM(r),
      .RGB0(led_green), .RGB1(led_blue), .RGB2(led_red));
endmodule
