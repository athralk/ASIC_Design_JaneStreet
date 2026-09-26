`default_nettype none
`timescale 1ns / 1ps

// Two tiles joined by a "cable": each one's TD+/TD- drives the other's RD through a
// comparator (TD+ high and TD- low reads as 1). The cocotb test drives node A's host
// pins and watches node B's, and the other way round.
module tb ();

  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] a_ui_in, b_ui_in;
  reg a_tx_valid, b_tx_valid;
  wire [7:0] a_uo_out, a_uio_out, a_uio_oe;
  wire [7:0] b_uo_out, b_uio_out, b_uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  wire a_line = a_uio_out[0] & ~a_uio_out[1];
  wire b_line = b_uio_out[0] & ~b_uio_out[1];

  tt_um_eth10t node_a (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (a_ui_in),
      .uo_out (a_uo_out),
      .uio_in ({4'b0, a_tx_valid, b_line, 2'b0}),
      .uio_out(a_uio_out),
      .uio_oe (a_uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  tt_um_eth10t node_b (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (b_ui_in),
      .uo_out (b_uo_out),
      .uio_in ({4'b0, b_tx_valid, a_line, 2'b0}),
      .uio_out(b_uio_out),
      .uio_oe (b_uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

endmodule
