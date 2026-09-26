(* FPGA demo host: stands in for the TinyTapeout RP2040 by driving the exact TT pin
   interface. It broadcasts a small frame about once a second and shows link and
   activity on an RGB LED. *)

open! Base
open Hardcaml
open Signal

let name = "eth10t_demo"

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; rd : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { td_p : 'a
    ; td_n : 'a
    ; led_r : 'a
    ; led_g : 'a
    ; led_b : 'a
    ; led_tx : 'a
    ; led_rx : 'a
    }
  [@@deriving hardcaml]
end

(* Broadcast, locally administered source, local experimental EtherType 0x88B5. *)
let header =
  [ 0xff; 0xff; 0xff; 0xff; 0xff; 0xff; 0x02; 0x48; 0x43; 0x31; 0x30; 0x54; 0x88; 0xb5 ]
;;

let message = "Hello from Hardcaml 10BASE-T #"
let frame_bytes = header @ List.map (String.to_list message) ~f:Char.to_int

let create ?(cfg = Config.default) ?(period_bits = 26) ?(led_bits = 22) (i : _ I.t) =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:~:(i.rst_n) () in
  let len = List.length frame_bytes + 1 in
  let idx = Variable.reg spec ~width:(num_bits_to_represent len) in
  let tx_valid = Variable.reg spec ~width:1 in
  let seq = Variable.reg spec ~width:8 in
  let timer = Variable.reg spec ~width:period_bits in
  (* Two-stage ROM: the byte is only needed ~48 cycles after idx moves. *)
  let rom =
    let bytes = List.map frame_bytes ~f:(of_int ~width:8) @ [ seq.value ] in
    List.chunks_of bytes ~length:8
    |> List.map ~f:(fun bank -> reg spec (mux (sel_bottom idx.value 3) bank))
    |> mux (drop_bottom idx.value 3)
    |> reg spec
  in
  let uio_in = wire 8 in
  let uio_out = wire 8 in
  let o =
    Tt_top.create ~cfg { Tt_top.I.clk = i.clock; rst_n = i.rst_n; ena = vdd; ui_in = rom; uio_in }
  in
  uio_out <== o.uio_out;
  uio_in <== concat_lsb [ gnd; gnd; i.rd; tx_valid.value; zero 4 ];
  let tx_ready = bit uio_out 4 in
  let rx_frame = bit uio_out 6 in
  let link_up = bit uio_out 7 in
  let taken = tx_ready &: ~:(reg spec tx_ready) in
  (* Status is only on uo_out between frames. *)
  let status = reg spec ~enable:~:rx_frame o.uo_out in
  let good_rx =
    let toggle = bit status Eth_core.Status.frame_toggle in
    toggle ^: reg spec toggle &: bit status Eth_core.Status.crc_ok
  in
  (* Pulse stretcher: load all ones, count down while the MSB is set. The MSB is the
     LED, so there is no wide compare. *)
  let stretch trigger =
    let trigger = reg spec trigger in
    let c = Variable.reg spec ~width:led_bits in
    compile
      [ if_ trigger [ c <-- ones led_bits ] [ when_ (msb c.value) [ c <-- c.value -:. 1 ] ] ];
    msb c.value
  in
  let period_done = reg spec (timer.value ==: ones period_bits) in
  compile
    [ timer <-- timer.value +:. 1
    ; when_ (period_done &: ~:(tx_valid.value))
        [ idx <--. 0; tx_valid <--. 1 ]
    ; when_ taken
        [ idx <-- idx.value +:. 1
        ; when_ (reg spec (idx.value ==:. len - 1)) [ tx_valid <--. 0; seq <-- seq.value +:. 1 ]
        ]
    ];
  { O.td_p = bit uio_out 0
  ; td_n = bit uio_out 1
  ; led_r = ~:link_up
  ; led_g = link_up
  ; led_b = stretch (taken |: good_rx)
  ; led_tx = stretch taken
  ; led_rx = stretch good_rx
  }
;;

let circuit ?cfg ?period_bits ?led_bits () =
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name (create ?cfg ?period_bits ?led_bits)
;;
