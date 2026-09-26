(* TinyTapeout wrapper, mapping the core onto the standard 26-pin tile interface.

   ui_in[7:0]   TX byte
   uo_out[7:0]  RX byte while rx_frame is high, otherwise the status byte
   uio[0]  out  TD+
   uio[1]  out  TD-
   uio[2]  in   RD (receive comparator)
   uio[3]  in   tx_valid
   uio[4]  out  tx_ready
   uio[5]  out  rx_valid
   uio[6]  out  rx_frame
   uio[7]  out  link_up *)

open! Base
open Hardcaml
open Signal

let name = "tt_um_eth10t"

module I = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    }
  [@@deriving hardcaml]
end

let uio_oe = 0b1111_0011

(* The only falling-edge flop in the design: it samples RD half a cycle early, which
   doubles receive timing resolution. The simulator can't model falling edges, so
   testbenches pass [rd_fall] in directly. *)
let capture_rd_fall ~clock rd =
  reg (Reg_spec.create ~clock () |> Reg_spec.override ~clock_edge:Falling) rd
;;

let create_with_core ?cfg ?rd_fall (i : _ I.t) =
  let rd = bit i.uio_in 2 in
  let rd_fall =
    match rd_fall with
    | Some s -> s
    | None -> capture_rd_fall ~clock:i.clk rd
  in
  let o =
    Eth_core.create
      ?cfg
      { Eth_core.I.clock = i.clk
      ; clear = ~:(i.rst_n)
      ; rd
      ; rd_fall
      ; tx_valid = bit i.uio_in 3
      ; tx_data = i.ui_in
      }
  in
  ( { O.uo_out = mux2 o.rx_frame o.rx_data o.status
    ; uio_out =
        concat_lsb
          [ o.td_p; o.td_n; gnd; gnd; o.tx_ready; o.rx_valid; o.rx_frame; o.link_up ]
    ; uio_oe = of_int ~width:8 uio_oe
    }
  , o )
;;

let create ?cfg ?rd_fall i = fst (create_with_core ?cfg ?rd_fall i)

let circuit ?cfg () =
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name (create ?cfg)
;;

(* The same tile with the falling-edge RD sample as a free input, plus the internal
   invariant as an output. Used by the testbench and by formal. *)
module I_rd_fall = struct
  type 'a t =
    { clk : 'a
    ; rst_n : 'a
    ; ena : 'a
    ; ui_in : 'a [@bits 8]
    ; uio_in : 'a [@bits 8]
    ; rd_fall : 'a
    }
  [@@deriving hardcaml]
end

module O_rd_fall = struct
  type 'a t =
    { uo_out : 'a [@bits 8]
    ; uio_out : 'a [@bits 8]
    ; uio_oe : 'a [@bits 8]
    ; invariant : 'a
    }
  [@@deriving hardcaml]
end

let create_rd_fall ?cfg (i : _ I_rd_fall.t) =
  let o, core =
    create_with_core
      ?cfg
      ~rd_fall:i.rd_fall
      { I.clk = i.clk; rst_n = i.rst_n; ena = i.ena; ui_in = i.ui_in; uio_in = i.uio_in }
  in
  { O_rd_fall.uo_out = o.uo_out
  ; uio_out = o.uio_out
  ; uio_oe = o.uio_oe
  ; invariant = core.invariant
  }
;;

let circuit_rd_fall ?cfg () =
  let module C = Circuit.With_interface (I_rd_fall) (O_rd_fall) in
  C.create_exn ~name:(name ^ "_rd_fall") (create_rd_fall ?cfg)
;;
