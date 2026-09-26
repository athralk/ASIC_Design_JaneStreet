(* Writes the Verilog: the TinyTapeout tile into [src_dir]; the FPGA builds (UPduino
   demo, Arty MII) and the formal/simulation variant into [gen_dir]. *)

open! Core
open Hardcaml

let () =
  let argv = Sys.get_argv () in
  let gen_dir = if Array.length argv > 1 then argv.(1) else "gen" in
  let src_dir = if Array.length argv > 2 then argv.(2) else "src" in
  List.iter [ gen_dir; src_dir ] ~f:Core_unix.mkdir_p;
  let write dir name circuit =
    Rtl.output ~output_mode:(To_file (dir ^/ name ^ ".v")) Verilog circuit
  in
  write src_dir Eth10t.Tt_top.name (Eth10t.Tt_top.circuit ());
  write gen_dir Eth10t.Demo.name (Eth10t.Demo.circuit ());
  write gen_dir Eth10t.Arty_mii.name (Eth10t.Arty_mii.circuit ());
  write gen_dir (Eth10t.Tt_top.name ^ "_rd_fall") (Eth10t.Tt_top.circuit_rd_fall ())
;;
