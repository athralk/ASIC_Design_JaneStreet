(* Minimal MII MAC for the Arty's on-board PHY (TI DP83848). The transmitter runs on
   the PHY's TX_CLK and the receiver on its RX_CLK, as MII intends, so the same logic
   works at 10 Mb/s (2.5 MHz clocks) and 100 Mb/s (25 MHz). One nibble per clock,
   bit 0 first on the wire. No registers here have a reset: they start at zero, and
   every state machine returns to Idle by itself. *)

open! Base
open Hardcaml
open Signal

let min_data_bytes = 60 (* before the FCS *)
let preamble_nibbles = 16 (* fifteen 0x5, then the SFD's 0xD *)
let gap_nibbles = 32 (* >= 96 bit times *)

(* One CRC step per bit of the nibble, bit 0 first. *)
let crc_nibble crc d = List.fold (bits_lsb d) ~init:crc ~f:Crc32.step

(* A pulse in [spec]'s domain for every change of [toggle], which may come from
   another clock domain. *)
let toggle_event spec toggle =
  let s = pipeline spec ~n:2 toggle in
  s ^: reg spec s
;;

let nibbles_of_bytes bytes = List.concat_map bytes ~f:(fun b -> [ b land 0xf; b lsr 4 ])

module Tx = struct
  type t =
    { txd : Signal.t
    ; tx_en : Signal.t
    ; sent : Signal.t (* toggles after each frame *)
    }

  module S = struct
    type t =
      | Idle
      | Preamble
      | Data
      | Fcs
      | Gap
    [@@deriving sexp_of, compare, enumerate]
  end

  (* Sends [payload] followed by a sequence byte, zero padded, on each [start]
     (a pulse in this domain). Waits while [crs] (asynchronous) is high. *)
  let create ~clock ~start ~crs ~payload =
    let open Always in
    let spec = Reg_spec.create ~clock () in
    let data_nibbles = 2 * Int.max min_data_bytes (List.length payload + 1) in
    let sm = State_machine.create (module S) spec in
    let n = Variable.reg spec ~width:(num_bits_to_represent data_nibbles) in
    let crc = Variable.reg spec ~width:32 in
    let seq = Variable.reg spec ~width:8 in
    let pending = Variable.reg spec ~width:1 in
    let sent = Variable.reg spec ~width:1 in
    let txd = Variable.reg spec ~width:4 in
    let tx_en = Variable.reg spec ~width:1 in
    let carrier = pipeline spec ~n:2 crs in
    (* Past the end of the list, [mux] repeats the last entry: zero padding. *)
    let byte =
      mux (srl n.value 1) (List.map payload ~f:(of_int ~width:8) @ [ seq.value; zero 8 ])
    in
    let nibble = mux2 (lsb n.value) (sel_top byte 4) (sel_bottom byte 4) in
    let last k = n.value ==:. k - 1 in
    compile
      [ tx_en <--. 0
      ; n <-- n.value +:. 1
      ; sm.switch
          [ ( Idle
            , [ n <--. 0
              ; when_ (pending.value &: ~:carrier) [ pending <--. 0; sm.set_next Preamble ]
              ] )
          ; ( Preamble
            , [ tx_en <--. 1
              ; txd <-- mux2 (last preamble_nibbles) (of_int ~width:4 0xd) (of_int ~width:4 0x5)
              ; crc <-- ones 32
              ; when_ (last preamble_nibbles) [ n <--. 0; sm.set_next Data ]
              ] )
          ; ( Data
            , [ tx_en <--. 1
              ; txd <-- nibble
              ; crc <-- crc_nibble crc.value nibble
              ; when_ (last data_nibbles) [ n <--. 0; sm.set_next Fcs ]
              ] )
          ; ( Fcs
            , [ tx_en <--. 1
              ; txd <-- ~:(sel_bottom crc.value 4)
              ; crc <-- srl crc.value 4
              ; when_ (last 8) [ n <--. 0; sm.set_next Gap ]
              ] )
          ; ( Gap
            , [ when_
                  (last gap_nibbles)
                  [ sent <-- ~:(sent.value); seq <-- seq.value +:. 1; sm.set_next Idle ]
              ] )
          ]
      ; when_ start [ pending <--. 1 ]
      ];
    { txd = txd.value; tx_en = tx_en.value; sent = sent.value }
  ;;
end

module Rx = struct
  type t =
    { good : Signal.t (* toggles on each good frame from another station *)
    ; echo : Signal.t (* toggles on each good frame from [our_mac] *)
    ; rx_dv : Signal.t
    }

  module S = struct
    type t =
      | Idle
      | Preamble
      | Data
    [@@deriving sexp_of, compare, enumerate]
  end

  let create ~clock ~rx_dv ~rxd ~our_mac =
    let open Always in
    let spec = Reg_spec.create ~clock () in
    (* Input flops, placed in the I/O blocks by the XDC. *)
    let dv = reg spec rx_dv in
    let d = reg spec rxd in
    let sm = State_machine.create (module S) spec in
    let n = Variable.reg spec ~width:12 in
    let crc = Variable.reg spec ~width:32 in
    let mine = Variable.reg spec ~width:1 in
    let good = Variable.reg spec ~width:1 in
    let echo = Variable.reg spec ~width:1 in
    (* The source address is data nibbles 12..23. *)
    let src = List.map (nibbles_of_bytes our_mac) ~f:(of_int ~width:4) in
    let src_pos = n.value -:. 12 in
    let in_src = n.value >=:. 12 &: (n.value <:. 24) in
    let src_differs = in_src &: (d <>: mux (sel_bottom src_pos 4) src) in
    let sfd = d ==:. 0xd in
    let start_data = [ n <--. 0; crc <-- ones 32; mine <--. 1; sm.set_next Data ] in
    let frame_ok =
      crc.value ==:. Crc32.residue
      &: ~:(lsb n.value)
      &: (n.value >=:. 2 * (min_data_bytes + 4))
    in
    compile
      [ sm.switch
          [ Idle, [ when_ dv [ if_ sfd start_data [ sm.set_next Preamble ] ] ]
          ; Preamble, [ if_ ~:dv [ sm.set_next Idle ] [ when_ sfd start_data ] ]
          ; ( Data
            , [ if_
                  dv
                  [ crc <-- crc_nibble crc.value d
                  ; when_ (n.value <>:. 0xfff) [ n <-- n.value +:. 1 ]
                  ; when_ src_differs [ mine <--. 0 ]
                  ]
                  [ when_
                      frame_ok
                      [ if_ mine.value [ echo <-- ~:(echo.value) ] [ good <-- ~:(good.value) ] ]
                  ; sm.set_next Idle
                  ]
              ] )
          ]
      ];
    { good = good.value; echo = echo.value; rx_dv = dv }
  ;;
end
