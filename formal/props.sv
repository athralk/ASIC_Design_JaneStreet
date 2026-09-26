// Port-level safety properties of the tile, checked with yosys' SAT-based
// k-induction. RD's falling-edge sample is a free input here, so every value it
// could take is covered.
module props (
    input clk,
    input rst_n,
    input [7:0] ui_in,
    input [7:0] uio_in,
    input rd_fall
);
  wire [7:0] uo_out, uio_out, uio_oe;
  wire invariant;

  tt_um_eth10t_rd_fall dut (
      .clk(clk), .rst_n(rst_n), .ena(1'b1), .ui_in(ui_in), .uio_in(uio_in),
      .rd_fall(rd_fall), .uo_out(uo_out), .uio_out(uio_out), .uio_oe(uio_oe),
      .invariant(invariant));

  wire td_p = uio_out[0], td_n = uio_out[1];
  wire tx_ready = uio_out[4], rx_valid = uio_out[5], rx_frame = uio_out[6];

  reg started = 0;
  reg [1:0] line_q = 0;
  reg [3:0] run = 0;
  reg tx_ready_q = 0;
  reg [3:0] tx_valid_q = 0;

  always @(posedge clk) begin
    started <= 1;
    line_q <= {td_n, td_p};
    run <= ({td_n, td_p} != line_q) ? 4'd1 : (run == 4'd15 ? run : run + 4'd1);
    tx_ready_q <= tx_ready;
    tx_valid_q <= {tx_valid_q[2:0], uio_in[3]};
  end

  always @* begin
    // Reset is applied in the first cycle only.
    if (started) assume (rst_n);
    // Internal state stays in its reachable range. Proving it alongside the other
    // properties keeps k-induction from starting in impossible states.
    if (started && rst_n) assert (invariant);
`ifdef P_BASIC
    // The I/O direction never changes.
    assert (uio_oe == 8'hF3);
    // The two line drivers are never on together.
    assert (!(td_p && td_n));
    // A byte strobe only happens inside a frame.
    assert (!rx_valid || rx_frame);
`endif
    if (started && rst_n) begin
`ifdef P_PULSE
      // No pulse shorter than a Manchester half-bit (50 ns) ever reaches the line.
      if ({td_n, td_p} != line_q && line_q != 2'b00) assert (run >= 4'd3);
`endif
`ifdef P_READY
      // A byte is only taken when the host's tx_valid was high as it passed through
      // the synchroniser and the one-cycle-early transition plan.
      if (tx_ready && !tx_ready_q) assert (tx_valid_q[3]);
`endif
    end
  end
endmodule
