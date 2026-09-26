(* Pure-OCaml golden model of an IEEE 802.3 frame on the wire. *)

open! Core

let crc32 bytes =
  let crc =
    List.fold bytes ~init:0xFFFF_FFFF ~f:(fun crc byte ->
      let crc = ref (crc lxor byte) in
      for _ = 1 to 8 do
        crc := if !crc land 1 = 1 then (!crc lsr 1) lxor 0xEDB8_8320 else !crc lsr 1
      done;
      !crc)
  in
  crc lxor 0xFFFF_FFFF
;;

let padded payload =
  payload @ List.init (Int.max 0 (60 - List.length payload)) ~f:(fun _ -> 0)
;;

let fcs_bytes data =
  let c = crc32 data in
  List.init 4 ~f:(fun i -> (c lsr (8 * i)) land 0xff)
;;

(* Bytes the receiver should hand to its host: data, pad, FCS. *)
let frame payload =
  let data = padded payload in
  data @ fcs_bytes data
;;

let bits_of_bytes bytes =
  List.concat_map bytes ~f:(fun b -> List.init 8 ~f:(fun i -> (b lsr i) land 1 = 1))
;;

let preamble_sfd = List.init 7 ~f:(fun _ -> 0x55) @ [ 0xd5 ]
let wire_bits payload = bits_of_bytes (preamble_sfd @ frame payload)
