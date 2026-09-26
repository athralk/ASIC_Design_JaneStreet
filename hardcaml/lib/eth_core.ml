(* 10BASE-T PHY + MAC-lite core. Half duplex, so TX and RX share one CRC engine. TX
   owns it while a frame is going out. *)

open! Base
open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; rd : 'a
    ; rd_fall : 'a
    ; tx_valid : 'a
    ; tx_data : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { td_p : 'a
    ; td_n : 'a
    ; tx_ready : 'a
    ; rx_valid : 'a
    ; rx_frame : 'a
    ; rx_data : 'a [@bits 8]
    ; status : 'a [@bits 8]
    ; link_up : 'a
    ; invariant : 'a (* for formal and simulation only *)
    }
  [@@deriving hardcaml]
end

module Status = struct
  let tx_busy = 0
  let carrier = 1
  let collision = 2
  let jabber = 3
  let crc_ok = 4
  let align_err = 5
  let frame_toggle = 6
  let link_up = 7
end

let create ?(cfg = Config.default) (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let slow_tick =
    reg_fb spec ~width:cfg.prescale_bits ~f:(fun c -> c +:. 1)
    |> fun c -> c ==: ones cfg.prescale_bits
  in
  let nr = Reg_spec.create ~clock:i.clock () in
  let tx_valid = pipeline nr ~n:2 i.tx_valid in
  let crc = wire 32 in
  let rx = Rx.create cfg ~spec ~rd:i.rd ~rd_fall:i.rd_fall ~crc in
  let tx =
    Tx.create
      cfg
      ~spec
      ~tx_valid
      ~tx_data:i.tx_data
      ~carrier:rx.carrier
      ~rx_active:rx.active
      ~slow_tick
      ~crc
  in
  (* Registered controls keep the CRC off the decoder's critical path. *)
  let crc_out =
    Crc32.create
      { Crc32.I.clock = i.clock
      ; init = reg nr (tx.crc_init |: (rx.crc_init &: ~:(tx.busy)))
      ; enable = reg nr (mux2 tx.busy tx.crc_enable rx.crc_enable)
      ; data = reg nr (mux2 tx.busy tx.crc_data rx.crc_data)
      }
  in
  crc <== crc_out.crc;
  let link_up =
    let open Always in
    let up = Variable.reg spec ~width:1 in
    let count = Variable.reg spec ~width:6 in
    compile
      [ if_
          rx.session_end
          [ up <--. 1; count <--. 0 ]
          [ when_
              slow_tick
              [ if_
                  (count.value ==:. Config.link_loss_ticks)
                  [ up <--. 0 ]
                  [ count <-- count.value +:. 1 ]
              ]
          ]
      ];
    up.value
  in
  let status =
    concat_lsb
      [ tx.busy
      ; rx.carrier
      ; tx.collision
      ; tx.jabber
      ; rx.crc_ok
      ; rx.align_err
      ; rx.frame_toggle
      ; link_up
      ]
  in
  { O.td_p = tx.td_p
  ; td_n = tx.td_n
  ; tx_ready = tx.tx_ready
  ; rx_valid = rx.rx_valid
  ; rx_frame = rx.in_frame
  ; rx_data = rx.rx_byte
  ; status
  ; link_up
  ; invariant = tx.invariant &: rx.invariant
  }
;;
