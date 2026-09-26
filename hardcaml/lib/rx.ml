(* Manchester decoder and receive MAC.

   RD is sampled on both clock edges: [rd_fall] (captured half a cycle earlier by a
   negedge flop) and [rd]. That gives a timeline of half-cycle slots, 12 per bit at
   60 MHz. [ph] is the slot position relative to the expected mid-bit transition, held
   one-hot so every phase test is a single bit. A digital PLL keeps it there:

   - The first edge on an idle line starts a session and sets [ph] directly.
   - An edge within [w] slots of mid-bit votes early or late. The votes go through a
     loop filter: once they reach a threshold (1 while locking in the first preamble
     bits, 16 after that), [ph] moves one slot at the next bit boundary. The reference
     averages out edge jitter instead of following it.
   - The bit is the level just after the mid-bit edge (its direction is the data). If
     no mid-bit edge was classified, it's the line a quarter bit after mid-bit.
   - A bit with no mid-bit edge is still decoded. A second miss in a row ends the
     session and drops that trailing sample (TP_IDL), so bits are emitted one bit late.

   A session with at least 4 bits is carrier. Link pulses give at most 2 bits. *)

open! Base
open Hardcaml
open Signal

type t =
  { active : Signal.t
  ; carrier : Signal.t
  ; session_end : Signal.t
  ; in_frame : Signal.t
  ; rx_valid : Signal.t
  ; rx_byte : Signal.t
  ; crc_ok : Signal.t
  ; align_err : Signal.t
  ; frame_toggle : Signal.t
  ; crc_init : Signal.t
  ; crc_enable : Signal.t
  ; crc_data : Signal.t
  ; invariant : Signal.t
  }

let create (cfg : Config.t) ~spec ~rd ~rd_fall ~crc =
  let open Always in
  let h = cfg.half_bit in
  let slots = 4 * h in
  let w = h - 1 in
  (* Registers derived from other registers need no reset: they settle while reset
     is held (hold rst_n low for at least 4 cycles). *)
  let nr = Reg_spec.create ~clock:(Reg_spec.clock spec) () in
  let s0 = pipeline nr ~n:2 rd_fall in
  let s1 = pipeline nr ~n:2 rd in
  let prev = reg nr s1 in
  let e0 = prev ^: s0 in
  let e1 = s0 ^: s1 in
  let ph = Variable.reg spec ~width:slots in
  let active = Variable.reg spec ~width:1 in
  let seen = Variable.reg spec ~width:1 in
  let miss = Variable.reg spec ~width:1 in
  let pending = Variable.reg spec ~width:1 in
  let mid_level = Variable.reg spec ~width:1 in
  let pending_valid = Variable.reg spec ~width:1 in
  let vote = Variable.reg spec ~width:6 in
  let nbits = Variable.reg spec ~width:3 in
  List.iter
    [ ph.value, "rx_ph"; active.value, "rx_active"; seen.value, "rx_seen"
    ; miss.value, "rx_miss"; vote.value, "rx_vote"; nbits.value, "rx_nbits" ]
    ~f:(fun (s, n) -> ignore (s -- n : Signal.t));
  let is x values = List.map values ~f:(fun v -> bit x v) |> reduce ~f:( |: ) in
  let early = List.init w ~f:(fun k -> slots - 1 - k) in
  let late = List.init w ~f:(fun k -> k + 1) in
  (* Slot 1 of this cycle is at ph + 1, so compare ph against shifted constants. *)
  let at0 values = is ph.value values in
  let at1 values = is ph.value (List.map values ~f:(fun v -> (v - 1 + slots) % slots)) in
  let mid0 = e0 &: at0 ((0 :: early) @ late) in
  let mid1 = e1 &: at1 ((0 :: early) @ late) in
  (* Votes are registered; one landing after the boundary decision just counts
     toward the next bit. *)
  let early_vote = reg nr (active.value &: ((e0 &: at0 early) |: (e1 &: at1 early))) in
  let late_vote = reg nr (active.value &: ((e0 &: at0 late) |: (e1 &: at1 late))) in
  (* Sample in one cycle, decide in the next from registered state only. *)
  let sample_now = active.value &: is ph.value [ h - 1; h ] in
  let sample =
    reg nr (mux2 mid0 s0 (mux2 seen.value mid_level.value (mux2 (bit ph.value h) s0 s1)))
  in
  let decide = reg nr sample_now in
  let keep = seen.value |: ~:(miss.value) in
  let bit_valid_now = decide &: keep &: pending_valid.value in
  let session_end_now = decide &: ~:keep in
  (* Corrections land in the boundary slots [2h, 2h+1]. They are decided a cycle
     earlier, when ph is in [2h-2, 2h-1] and the votes have settled, and arrive as
     registered one-cycle pulses. *)
  let locking = nbits.value <>:. 7 in
  let threshold = mux2 locking (of_int ~width:6 1) (of_int ~width:6 16) in
  let before_boundary = active.value &: is ph.value [ (2 * h) - 2; (2 * h) - 1 ] in
  let advance = reg nr (before_boundary &: (vote.value >=+ threshold)) in
  let retard = reg nr (before_boundary &: (vote.value <=+ negate threshold)) in
  (* ph + 2 (+-1) mod slots is a rotation of the one-hot ring. *)
  let step = mux2 advance (rotl ph.value 3) (mux2 retard (rotl ph.value 1) (rotl ph.value 2)) in
  compile
    [ if_
        active.value
        [ ph <-- step
        ; when_ (mid0 |: mid1) [ seen <--. 1; mid_level <-- mux2 mid1 s1 s0 ]
        ; vote
          <-- (let base = mux2 (advance |: retard) (zero (width vote.value)) vote.value in
               mux2 early_vote (base +:. 1) (mux2 late_vote (base -:. 1) base))
        ; when_
            decide
            [ seen <--. 0
            ; if_
                keep
                [ miss <-- ~:(seen.value)
                ; pending <-- sample
                ; pending_valid <--. 1
                ; when_ (bit_valid_now &: (nbits.value <>:. 7)) [ nbits <-- nbits.value +:. 1 ]
                ]
                [ active <--. 0 ]
            ]
        ]
        [ when_
            (e0 |: e1)
            [ active <--. 1
            ; seen <--. 1
            ; miss <--. 0
            ; pending_valid <--. 0
            ; nbits <--. 0
            ; vote <--. 0
            ; ph <-- mux2 e0 (of_int ~width:slots 0b100) (of_int ~width:slots 0b10)
            ]
        ]
    ];
  (* The bit stream is registered between decoder and MAC for timing. *)
  let bit_valid = reg nr bit_valid_now in
  let session_end = reg nr session_end_now in
  let bit = reg nr pending.value in
  (* Receive MAC: find the SFD (first "11" after the alternating preamble), then
     assemble bytes LSB first. The CRC is checked after every byte, so dribble bits
     don't matter. *)
  let in_frame = Variable.reg spec ~width:1 in
  let last_bit = Variable.reg spec ~width:1 in
  let bitidx = Variable.reg spec ~width:3 in
  let have_byte = Variable.reg spec ~width:1 in
  let check = Variable.reg spec ~width:2 in
  let crc_ok = Variable.reg spec ~width:1 in
  let align_err = Variable.reg spec ~width:1 in
  let frame_toggle = Variable.reg spec ~width:1 in
  let shreg = Variable.reg nr ~width:8 in
  let rx_byte = Variable.reg nr ~width:8 in
  List.iter
    [ in_frame.value, "rx_in_frame"; bitidx.value, "rx_bitidx"; check.value, "rx_check" ]
    ~f:(fun (s, n) -> ignore (s -- n : Signal.t));
  let sfd =
    bit_valid &: ~:(in_frame.value) &: (nbits.value >=:. 4) &: last_bit.value &: bit
  in
  let shifted = bit @: select shreg.value 7 1 in
  compile
    [ (* The shared CRC registers its controls, so it is two cycles behind. *)
      check <-- sll check.value 1
    ; when_ (msb check.value) [ crc_ok <-- (crc ==:. Crc32.residue) ]
    ; when_ bit_valid
        [ last_bit <-- bit
        ; when_ in_frame.value
            [ shreg <-- shifted
            ; bitidx <-- bitidx.value +:. 1
            ; when_ (bitidx.value ==:. 7)
                [ rx_byte <-- shifted; have_byte <--. 1; check <--. 1 ]
            ]
        ]
    ; when_ sfd
        [ in_frame <--. 1; bitidx <--. 0; have_byte <--. 0; crc_ok <--. 0 ]
    ; when_ (session_end &: in_frame.value)
        [ in_frame <--. 0
        ; align_err <-- (bitidx.value <>:. 0)
        ; frame_toggle <-- ~:(frame_toggle.value)
        ]
    ];
  { active = active.value
  ; carrier = active.value &: msb nbits.value
  ; session_end
  ; in_frame = in_frame.value
  ; rx_valid = in_frame.value &: have_byte.value &: ~:(msb bitidx.value)
  ; rx_byte = rx_byte.value
  ; crc_ok = crc_ok.value
  ; align_err = align_err.value
  ; frame_toggle = frame_toggle.value
  ; crc_init = sfd
  ; crc_enable = bit_valid &: in_frame.value
  ; crc_data = bit
  ; invariant = ~:(active.value) |: (popcount ph.value ==:. 1)
  }
;;
