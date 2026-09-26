open! Core
open Hardcaml
open Eth10t
module Sim = Cyclesim.With_interface (Crc32.I) (Crc32.O)

let run_bytes bytes =
  let sim = Sim.create Crc32.create in
  let i = Cyclesim.inputs sim in
  let o = Cyclesim.outputs sim in
  i.init := Bits.vdd;
  Cyclesim.cycle sim;
  i.init := Bits.gnd;
  i.enable := Bits.vdd;
  List.iter (Reference.bits_of_bytes bytes) ~f:(fun b ->
    i.data := Bits.of_bool b;
    Cyclesim.cycle sim);
  Bits.to_int !(o.crc)
;;

let%expect_test "CRC-32 check value" =
  let msg = String.to_list "123456789" |> List.map ~f:Char.to_int in
  let hw = run_bytes msg lxor 0xFFFF_FFFF in
  printf "hw=%08X ref=%08X\n" hw (Reference.crc32 msg);
  [%expect {| hw=CBF43926 ref=CBF43926 |}]
;;

let%expect_test "residue after data + FCS" =
  let data = List.init 60 ~f:(fun i -> (i * 37) land 0xff) in
  let r = run_bytes (data @ Reference.fcs_bytes data) in
  printf "residue=%08X ok=%b\n" r (r = Crc32.residue);
  [%expect {| residue=DEBB20E3 ok=true |}]
;;

let%expect_test "random vectors match the reference" =
  Quickcheck.test
    ~trials:200
    (Quickcheck.Generator.list_with_length 64 (Int.gen_incl 0 255)
     |> Quickcheck.Generator.bind ~f:(fun l ->
       Quickcheck.Generator.map (Int.gen_incl 1 64) ~f:(fun n -> List.take l n)))
    ~sexp_of:[%sexp_of: int list]
    ~f:(fun msg -> [%test_eq: int] (run_bytes msg lxor 0xFFFF_FFFF) (Reference.crc32 msg))
;;
