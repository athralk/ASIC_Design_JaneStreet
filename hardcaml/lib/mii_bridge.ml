(* FPGA-only bridge between the chip's Manchester line signals and a 10 Mb/s MII PHY
   (the Arty's DP83848). One clock. The 2.5 MHz MII clocks are synchronised and
   edge-detected like data.

   TX: decode our own TD+/TD- (clean, same clock), pack bits into nibbles (first bit in
   TXD[0]), and send one nibble per TX_CLK rising edge with TX_EN high. Link pulses
   are dropped; the PHY makes its own.

   RX: collect RXD nibbles on RX_CLK rising edges while RX_DV is high. Emit a short
   1010 preamble, then the bits, Manchester-encoded onto RD at one bit per
   [Config.bit] cycles. Frames that start while we transmit are the PHY's echo of our
   own frame and are dropped. *)

open! Base
open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; td_p : 'a
    ; td_n : 'a
    ; tx_clk : 'a
    ; rx_clk : 'a
    ; rx_dv : 'a
    ; rxd : 'a [@bits 4]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { txd : 'a [@bits 4]
    ; tx_en : 'a
    ; rd : 'a
    ; tx_clk_edge : 'a (* for the board's check LEDs *)
    ; rx_clk_edge : 'a
    ; rx_dv_seen : 'a
    }
  [@@deriving hardcaml]
end

let fifo_capacity = 16
let rx_preamble_bits = 16

let fifo ~clock ~clear ~wr ~d ~rd =
  Fifo.create ~showahead:true () ~capacity:fifo_capacity ~clock ~clear ~wr ~d ~rd
;;

(* Rising edge of an asynchronous slow clock, after a 2-flop synchroniser. *)
let rising nr x =
  let s = pipeline nr ~n:2 x in
  s &: ~:(reg nr s)
;;

let create ?(cfg = Config.default) (i : _ I.t) =
  let open Always in
  let bit_cycles = Config.bit cfg in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let nr = Reg_spec.create ~clock:i.clock () in
  let phase_width = num_bits_to_represent (bit_cycles - 1) in
  (* --- TX: line -> nibbles -------------------------------------------------- *)
  let tx_active = Variable.reg spec ~width:1 in
  let tx_phase = Variable.reg spec ~width:phase_width in
  let first_half = Variable.reg spec ~width:1 in
  let tx_shift = Variable.reg nr ~width:4 in
  let tx_count = Variable.reg spec ~width:2 in
  let push = Variable.wire ~default:gnd in
  (* Sample each half in its middle cycle. *)
  let mid_first = tx_phase.value ==:. cfg.half_bit / 2 in
  let mid_second = tx_phase.value ==:. cfg.half_bit + (cfg.half_bit / 2) in
  let is_bit = i.td_p ^: i.td_n &: (i.td_p ^: first_half.value) in
  let packed = i.td_p @: select tx_shift.value 3 1 in
  compile
    [ if_
        tx_active.value
        [ tx_phase
          <-- mux2
                (tx_phase.value ==:. bit_cycles - 1)
                (zero phase_width)
                (tx_phase.value +:. 1)
        ; when_ mid_first [ first_half <-- i.td_p ]
        ; when_
            mid_second
            [ if_
                is_bit
                [ tx_shift <-- packed
                ; tx_count <-- tx_count.value +:. 1
                ; when_ (tx_count.value ==:. 3) [ push <--. 1 ]
                ]
                [ tx_active <--. 0 ]
            ]
        ]
        (* A frame starts with TD- high (first half of the first preamble bit). *)
        [ when_ i.td_n [ tx_active <--. 1; tx_phase <--. 1; tx_count <--. 0 ] ]
    ];
  let tx_edge = rising nr i.tx_clk in
  let sending = Variable.reg spec ~width:1 in
  let tx_pop = wire 1 in
  let tx_fifo =
    fifo ~clock:i.clock ~clear:i.clear ~wr:push.value ~d:packed ~rd:tx_pop
  in
  (* Start once two nibbles are queued (or the frame is already over), so the
     frequency-locked TX_CLK never finds the FIFO empty mid-frame. *)
  let ready =
    (tx_fifo.used >=:. 2) |: (~:(tx_fifo.empty) &: ~:(tx_active.value))
  in
  tx_pop <== (tx_edge &: ~:(tx_fifo.empty) &: (sending.value |: ready));
  let txd = Variable.reg nr ~width:4 in
  let tx_en = Variable.reg spec ~width:1 in
  compile
    [ when_
        tx_edge
        [ if_
            tx_pop
            [ txd <-- tx_fifo.q; tx_en <--. 1; sending <--. 1 ]
            [ tx_en <--. 0; sending <--. 0 ]
        ]
    ];
  (* --- RX: nibbles -> line -------------------------------------------------- *)
  let rx_edge = rising nr i.rx_clk in
  (* RXD/RX_DV go through two more flops than RX_CLK, so they are the values from
     just before the clock edge, where MII guarantees them stable. *)
  let rx_dv = pipeline nr ~n:4 i.rx_dv in
  let rxd = pipeline nr ~n:4 i.rxd in
  (* RX_DV as seen at the previous RX_CLK edge, so a new frame is its rising edge. *)
  let new_frame = rx_edge &: rx_dv &: ~:(reg nr ~enable:rx_edge rx_dv) in
  (* In 10 Mb/s half duplex the PHY echoes our own transmission back on RX
     (802.3 10BASE-T loopback). Drop any frame that starts while we transmit, or the
     chip would see it as a collision. *)
  let echo = Variable.reg spec ~width:1 in
  let dropping = mux2 new_frame tx_en.value echo.value in
  compile
    [ when_ rx_edge [ echo <-- (rx_dv &: dropping) ] ];
  let frame_start = new_frame &: ~:dropping in
  let rx_pop = wire 1 in
  let rx_fifo =
    fifo
      ~clock:i.clock
      ~clear:i.clear
      ~wr:(rx_edge &: rx_dv &: ~:dropping)
      ~d:rxd
      ~rd:rx_pop
  in
  let module S = struct
    type t =
      | Idle
      | Preamble
      | Data
    [@@deriving sexp_of, compare, enumerate]
  end
  in
  let sm = State_machine.create (module S) spec in
  let phase = Variable.reg spec ~width:phase_width in
  let count = Variable.reg spec ~width:(num_bits_to_represent rx_preamble_bits) in
  let rx_shift = Variable.reg nr ~width:4 in
  let bit_now = Variable.reg spec ~width:1 in
  let bit_end = phase.value ==:. bit_cycles - 1 in
  let pop = Variable.wire ~default:gnd in
  let load_nibble =
    [ if_
        rx_fifo.empty
        [ sm.set_next Idle ]
        [ pop <--. 1
        ; rx_shift <-- srl rx_fifo.q 1
        ; bit_now <-- lsb rx_fifo.q
        ; count <--. 0
        ; sm.set_next Data
        ]
    ]
  in
  compile
    [ phase <-- mux2 bit_end (zero phase_width) (phase.value +:. 1)
    ; sm.switch
        [ ( Idle
          , [ phase <--. 0
            ; when_
                frame_start
                [ count <--. 0; bit_now <--. 1; sm.set_next Preamble ]
            ] )
        ; ( Preamble
          , [ when_
                bit_end
                [ count <-- count.value +:. 1
                ; bit_now <-- ~:(bit_now.value)
                ; when_ (count.value ==:. rx_preamble_bits - 1) load_nibble
                ]
            ] )
        ; ( Data
          , [ when_
                bit_end
                [ count <-- count.value +:. 1
                ; rx_shift <-- srl rx_shift.value 1
                ; bit_now <-- lsb rx_shift.value
                ; when_ (sel_bottom count.value 2 ==:. 3) load_nibble
                ]
            ] )
        ]
    ];
  rx_pop <== pop.value;
  (* Manchester: first half the complement, second half the bit. *)
  let first = phase.value <:. cfg.half_bit in
  let rd = reg nr (~:(sm.is Idle) &: mux2 first ~:(bit_now.value) bit_now.value) in
  { O.txd = txd.value
  ; tx_en = tx_en.value
  ; rd
  ; tx_clk_edge = tx_edge
  ; rx_clk_edge = rx_edge
  ; rx_dv_seen = rx_dv
  }
;;
