open! Base

(* Everything is expressed in clock cycles of a single clock. A 10BASE-T bit is 100 ns,
   so [half_bit] cycles per 50 ns gives a clock of [half_bit * 20 MHz]. *)
type t =
  { half_bit : int
  ; prescale_bits : int
  }
[@@deriving sexp_of]

let default = { half_bit = 3; prescale_bits = 16 }
let clock_hz t = t.half_bit * 20_000_000
let bit t = 2 * t.half_bit

(* Inter-packet gap: 96 bit times. *)
let ipg_cycles t = 96 * bit t

(* TP_IDL: hold the line high for 250 ns after the last bit. *)
let tp_idl_cycles t = 5 * t.half_bit

(* Receive edge window around the expected mid-bit transition. *)
let rx_window t = max 1 ((t.half_bit - 1) / 2)

(* Slow-tick counts, where one slow tick is [2 ** prescale_bits] cycles (~1.09 ms at
   60 MHz). *)
let nlp_ticks = 15 (* 16 ms +- 8 *)
let jabber_ticks = 31 (* 20..150 ms *)
let link_loss_ticks = 63 (* 50..150 ms *)
let min_frame_bytes = 60 (* excluding FCS *)
