(* Transmit framer and Manchester encoder.

   Frame: 7 x 0x55 preamble, 0xD5 SFD, host payload, zero pad to 60 bytes, FCS, then
   TP_IDL. Everything is serial, one bit per [Config.bit] cycles. The host raises
   [tx_valid] with the first byte on [tx_data] and holds it high while it has bytes.
   Each byte is consumed at a byte boundary, and [tx_ready] goes high for the first half
   of the byte that was just taken. Dropping [tx_valid] ends the payload. *)

open! Base
open Hardcaml
open Signal

module State = struct
  type t =
    | Idle
    | Nlp
    | Preamble
    | Data
    | Pad
    | Fcs
    | Jam
    | Eof
  [@@deriving sexp_of, compare, enumerate]
end

type t =
  { td_p : Signal.t
  ; td_n : Signal.t
  ; tx_ready : Signal.t
  ; busy : Signal.t
  ; collision : Signal.t
  ; jabber : Signal.t
  ; crc_init : Signal.t
  ; crc_enable : Signal.t
  ; crc_data : Signal.t
  ; invariant : Signal.t
  }

let create
  (cfg : Config.t)
  ~spec
  ~tx_valid
  ~tx_data
  ~carrier
  ~rx_active
  ~slow_tick
  ~crc
  =
  let open Always in
  let bit_cycles = Config.bit cfg in
  (* Registers derived from other registers need no reset: they settle while reset
     is held (hold rst_n low for at least 4 cycles). *)
  let nr = Reg_spec.create ~clock:(Reg_spec.clock spec) () in
  let sm = State_machine.create (module State) spec in
  let carrier = reg nr carrier in
  let phase = Variable.reg spec ~width:(num_bits_to_represent (bit_cycles - 1)) in
  let bitcnt = Variable.reg spec ~width:6 in
  let bytecnt = Variable.reg spec ~width:6 in
  let timer = Variable.reg spec ~width:5 in
  let ipg = Variable.reg spec ~width:(num_bits_to_represent (Config.ipg_cycles cfg)) in
  let collision = Variable.reg spec ~width:1 in
  let jabber = Variable.reg spec ~width:1 in
  let armed = Variable.reg spec ~width:1 in
  let shreg = Variable.reg nr ~width:8 in
  List.iter
    [ sm.current, "tx_state"; phase.value, "tx_phase"; bitcnt.value, "tx_bitcnt"
    ; bytecnt.value, "tx_bytecnt"; timer.value, "tx_timer" ]
    ~f:(fun (s, n) -> ignore (s -- n : Signal.t));
  (* Every non-idle state counts bits the same way, so [bit_end] can be registered
     from the cycle before. *)
  let pre_end = phase.value ==:. bit_cycles - 2 in
  let bit_end = reg nr (pre_end &: ~:(sm.is Idle)) in
  (* Slow-changing conditions are registered to keep them off the critical path. *)
  let ipg_done = reg nr (ipg.value ==:. Config.ipg_cycles cfg) in
  let nlp_due = reg nr (timer.value ==:. Config.nlp_ticks) in
  let jabber_due = reg nr (timer.value ==:. Config.jabber_ticks) in
  let rx_active = reg nr rx_active in
  (* A frame only starts after tx_valid has been low, so a host that never lets go
     (jabber, collision) can't retransmit endlessly. *)
  let start = tx_valid &: armed.value &: ipg_done &: ~:rx_active in
  let pad_needed = reg nr (bytecnt.value <:. Config.min_frame_bytes) in
  (* Saturates at 60: only "is the frame long enough yet" matters. *)
  let count_byte =
    bytecnt
    <-- mux2
          (bytecnt.value ==:. Config.min_frame_bytes)
          bytecnt.value
          (bytecnt.value +:. 1)
  in
  (* TP_IDL is [idl_bits] whole bits plus [idl_rest] cycles. *)
  let idl_bits = Config.tp_idl_cycles cfg / bit_cycles in
  let idl_rest = Config.tp_idl_cycles cfg % bit_cycles in
  let in_frame = sm.is Preamble |: sm.is Data |: sm.is Pad |: sm.is Fcs in
  let serial = in_frame |: sm.is Jam in
  let bit_out =
    mux2
      (sm.is Preamble)
      (~:(lsb bitcnt.value) |: (bitcnt.value ==:. 63))
      (mux2
         (sm.is Data)
         (lsb shreg.value)
         (mux2 (sm.is Fcs) ~:(lsb crc) (sm.is Jam &: ~:(lsb bitcnt.value))))
  in
  (* Manchester: first half carries the complement, second half the bit. *)
  let first_half = phase.value <:. cfg.half_bit in
  let line = mux2 first_half ~:bit_out bit_out in
  let td_p = reg nr (mux2 serial line (sm.is Nlp |: sm.is Eof)) in
  let td_n = reg nr (serial &: ~:line) in
  (* Bit-boundary transitions are planned a cycle ahead (at [pre_end]) into
     registered flags. [bit_end] then only applies them, which keeps the FSM shallow.
     Nothing the plan depends on changes in between, except the synchronised
     tx_valid, which is simply sampled a cycle earlier. *)
  let plan cond = reg nr ~enable:pre_end cond in
  let low3_is_7 = sel_bottom bitcnt.value 3 ==:. 7 in
  let byte_boundary =
    (sm.is Preamble &: (bitcnt.value ==:. 63)) |: ((sm.is Data |: sm.is Pad) &: low3_is_7)
  in
  let can_load = byte_boundary &: (sm.is Preamble |: sm.is Data) &: tx_valid in
  let p_load = plan can_load in
  let p_pad = plan (byte_boundary &: ~:can_load &: pad_needed) in
  let p_fcs = plan (byte_boundary &: ~:can_load &: ~:pad_needed) in
  let p_eof = plan ((sm.is Fcs |: sm.is Jam) &: (bitcnt.value ==:. 31)) in
  let p_jam = plan (in_frame &: carrier) in
  let p_jabber = plan (serial &: jabber_due) in
  let p_idle = plan (sm.is Nlp) in
  let p_clear = p_fcs |: p_eof |: p_jam |: p_jabber in
  compile
    [ ipg
      <-- mux2
            (~:(sm.is Idle) |: rx_active)
            (zero (width ipg.value))
            (mux2 ipg_done ipg.value (ipg.value +:. 1))
    ; when_ slow_tick [ timer <-- timer.value +:. 1 ]
    ; when_ ~:tx_valid [ armed <--. 1 ]
    ; phase <-- mux2 bit_end (zero (width phase.value)) (phase.value +:. 1)
    ; when_ bit_end
        [ bitcnt <-- mux2 p_clear (zero 6) (bitcnt.value +:. 1)
        ; when_ (sm.is Data) [ shreg <-- srl shreg.value 1 ]
        ; when_ p_load [ shreg <-- tx_data; count_byte; sm.set_next Data ]
        ; when_ p_pad [ count_byte; sm.set_next Pad ]
        ; when_ p_fcs [ sm.set_next Fcs ]
        ; when_ p_eof [ sm.set_next Eof ]
        ; when_ p_idle [ sm.set_next Idle ]
          (* Collision: jam from the next bit. *)
        ; when_ p_jam [ collision <--. 1; sm.set_next Jam ]
          (* Jabber: the host kept the transmitter on too long. *)
        ; when_ p_jabber [ jabber <--. 1; timer <--. 0; sm.set_next Eof ]
        ]
    ; when_
        (sm.is Idle)
        [ phase <--. 0
        ; bitcnt <--. 0
        ; bytecnt <--. 0
        ; if_
            start
            [ timer <--. 0
            ; armed <--. 0
            ; collision <--. 0
            ; jabber <--. 0
            ; sm.set_next Preamble
            ]
            (elif nlp_due [ timer <--. 0; sm.set_next Nlp ] [])
        ]
    ; when_
        (sm.is Eof)
        [ when_
            ((bitcnt.value ==:. idl_bits) &: (phase.value ==:. idl_rest - 1))
            [ phase <--. 0; timer <--. 0; sm.set_next Idle ]
        ; (* Jabber can also fire during TP_IDL; it just restarts it. *)
          when_ jabber_due [ jabber <--. 1; timer <--. 0; bitcnt <--. 0 ]
        ]
    ];
  { td_p
  ; td_n
  ; tx_ready = sm.is Data &: ~:(bit bitcnt.value 2)
  ; busy = ~:(sm.is Idle) &: ~:(sm.is Nlp)
  ; collision = collision.value
  ; jabber = jabber.value
  ; crc_init = sm.is Idle &: start
    (* Issued a cycle early: the shared CRC registers its controls. *)
  ; crc_enable = pre_end &: (sm.is Data |: sm.is Pad |: sm.is Fcs)
  ; crc_data = mux2 (sm.is Fcs) (lsb crc) bit_out
  ; invariant =
      (phase.value <:. bit_cycles)
      &: (bit_end ==: (phase.value ==:. bit_cycles - 1))
      &: (~:(sm.is Idle) |: (phase.value ==:. 0))
      &: (~:(sm.is Eof)
          |: (bitcnt.value <:. idl_bits)
          |: ((bitcnt.value ==:. idl_bits) &: (phase.value <:. idl_rest)))
  }
;;
