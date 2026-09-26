(* Bit-serial IEEE 802.3 CRC-32, LSB first, reflected polynomial. The transmitter sends
   the complement of the register, LSB first. Running the receiver over data and FCS
   leaves [residue] in the register. *)

open! Base
open Hardcaml
open Signal

let polynomial = 0xEDB88320
let residue = 0xDEBB20E3

module I = struct
  type 'a t =
    { clock : 'a
    ; init : 'a
    ; enable : 'a
    ; data : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { crc : 'a [@bits 32] } [@@deriving hardcaml]
end

let step crc d =
  let feedback = lsb crc ^: d in
  srl crc 1 ^: (of_int ~width:32 polynomial &: repeat feedback 32)
;;

(* Shifting out the FCS is a step with [d = lsb crc]: the feedback is zero, so the
   register just shifts right. *)
let create (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock () in
  let crc =
    reg_fb spec ~enable:(i.init |: i.enable) ~width:32 ~f:(fun crc ->
      mux2 i.init (ones 32) (step crc i.data))
  in
  { O.crc }
;;
