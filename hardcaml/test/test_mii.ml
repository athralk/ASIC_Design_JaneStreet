(* Arty MII MAC and MDIO tests. Cyclesim steps every clock together, so one cycle is
   one nibble on TX_CLK and RX_CLK alike. The PHY is modelled at its pins. *)

open! Core
open Hardcaml
open Eth10t

let nibbles_of_bits bits =
  List.chunks_of bits ~length:4
  |> List.map ~f:(fun b -> List.foldi b ~init:0 ~f:(fun k acc x -> if x then acc lor (1 lsl k) else acc))
;;

(* The PHY's side of MDIO: decodes frames on MDC rising edges, stores writes, and
   answers reads (driving MDIO for the turnaround's second bit and the 16 data bits,
   changing just after MDC rises, as a real PHY does). *)
module Phy_mdio = struct
  type t =
    { regs : int array
    ; mutable ones : int
    ; mutable header : bool list (* bits after the preamble *)
    ; mutable answer : bool list (* bits still to drive for a read *)
    ; mutable drive : bool option
    ; mutable writes : (int * int * int) list
    }

  let create () =
    let regs = Array.create ~len:32 0 in
    regs.(2) <- 0x2000; (* PHY identifier 1 of the DP83848 *)
    regs.(0x10) <- 0x0007; (* PHYSTS: link up, 10 Mb/s, full duplex *)
    { regs; ones = 0; header = []; answer = []; drive = None; writes = [] }
  ;;

  let value bits = List.fold bits ~init:0 ~f:(fun acc b -> (acc * 2) + Bool.to_int b)

  (* Called on each MDC rising edge with what the MAC drives (None = released). *)
  let rising t driven =
    match t.answer with
    | b :: rest ->
      t.drive <- Some b;
      t.answer <- rest
    | [] ->
      t.drive <- None;
      (match driven with
       | None -> ()
       | Some bit ->
         if List.is_empty t.header && bit && t.ones < 32
         then t.ones <- t.ones + 1
         else if t.ones >= 32
         then (
           t.header <- t.header @ [ bit ];
           let h = t.header in
           if List.length h = 14
           then (
             let op = value (List.sub h ~pos:2 ~len:2) in
             let reg = value (List.sub h ~pos:9 ~len:5) in
             if op = 0b10
             then (
               (* Turnaround: released, then 0; then the data, MSB first. *)
               t.answer <- false :: List.init 16 ~f:(fun k -> (t.regs.(reg) lsr (15 - k)) land 1 = 1);
               t.drive <- None;
               t.ones <- 0;
               t.header <- []));
           if List.length h = 32
           then (
             let phy = value (List.sub h ~pos:4 ~len:5) in
             let reg = value (List.sub h ~pos:9 ~len:5) in
             let data = value (List.sub h ~pos:16 ~len:16) in
             t.regs.(reg) <- data;
             t.writes <- t.writes @ [ phy, reg, data ];
             t.ones <- 0;
             t.header <- [])))
  ;;

  (* MDIO is open-drain with a pull-up: released reads as 1. *)
  let line t ~mac_oe ~mac_o =
    if mac_oe then mac_o else Option.value t.drive ~default:true
  ;;
end

module Mdio_sim = Cyclesim.With_interface (Mdio.I) (Mdio.O)

let run_mdio_phy phy ~mac_oe ~mac_o ~mdc ~prev_mdc =
  if mdc && not !prev_mdc then Phy_mdio.rising phy (if mac_oe then Some mac_o else None);
  prev_mdc := mdc
;;

let%expect_test "MDIO: writes land in the PHY, and the status reads back" =
  let sim = Mdio_sim.create Mdio.create in
  let i = Cyclesim.inputs sim and o = Cyclesim.outputs sim in
  let phy = Phy_mdio.create () in
  i.start := Bits.vdd;
  let prev_mdc = ref false in
  for _ = 1 to 20_000 do
    let mac_oe = Bits.to_bool !(o.mdio_oe) and mac_o = Bits.to_bool !(o.mdio_o) in
    i.mdio_i := Bits.of_bool (Phy_mdio.line phy ~mac_oe ~mac_o);
    Cyclesim.cycle sim;
    run_mdio_phy phy ~mac_oe ~mac_o ~mdc:(Bits.to_bool !(o.mdc)) ~prev_mdc
  done;
  List.iter phy.writes ~f:(fun (p, r, d) -> printf "PHY got write: phy=%d reg=%d data=0x%04x\n" p r d);
  printf "done=%b id_ok=%b link=%b speed_10=%b full_duplex=%b\n"
    (Bits.to_bool !(o.done_)) (Bits.to_bool !(o.id_ok)) (Bits.to_bool !(o.link))
    (Bits.to_bool !(o.speed_10)) (Bits.to_bool !(o.full_duplex));
  [%expect {|
    PHY got write: phy=1 reg=4 data=0x0061
    PHY got write: phy=1 reg=0 data=0x1200
    done=true id_ok=true link=true speed_10=true full_duplex=true
    |}]
;;

module Arty_sim = Cyclesim.With_interface (Arty_mii.I) (Arty_mii.O)

let%expect_test "Arty MAC: TX matches the reference, RX takes good frames, rejects bad ones" =
  let sim = Arty_sim.create (Arty_mii.create ~phy_reset_bits:6 ~period_bits:13 ~led_bits:6) in
  let i = Cyclesim.inputs sim and o = Cyclesim.outputs sim in
  let phy = Phy_mdio.create () in
  let prev_mdc = ref false in
  let sent = Queue.create () in
  let rx = Queue.create () in
  let led_seen = Array.create ~len:4 false in
  let cycle () =
    (match Queue.dequeue rx with
     | Some n -> i.eth_rx_dv := Bits.vdd; i.eth_rxd := Bits.of_int ~width:4 n
     | None -> i.eth_rx_dv := Bits.gnd);
    let mac_oe = Bits.to_bool !(o.mdio_oe) and mac_o = Bits.to_bool !(o.mdio_o) in
    i.mdio_i := Bits.of_bool (Phy_mdio.line phy ~mac_oe ~mac_o);
    if Bits.to_bool !(o.eth_tx_en) then Queue.enqueue sent (Bits.to_int !(o.eth_txd));
    Cyclesim.cycle sim;
    run_mdio_phy phy ~mac_oe ~mac_o ~mdc:(Bits.to_bool !(o.eth_mdc)) ~prev_mdc;
    Array.iteri led_seen ~f:(fun k s -> led_seen.(k) <- s || Bits.to_int !(o.led) land (1 lsl k) <> 0)
  in
  (* Feed [frame] to RX and report which LEDs lit in view [sw]. *)
  let receive ~sw frame =
    i.sw := Bits.of_bool sw;
    for _ = 1 to 50 do cycle () done;
    Array.fill led_seen ~pos:0 ~len:4 false;
    Queue.enqueue_all rx frame;
    for _ = 1 to List.length frame + 20 do cycle () done;
    String.init 4 ~f:(fun k -> if led_seen.(k) then '1' else '0')
  in
  i.rst_n := Bits.gnd;
  cycle ();
  i.rst_n := Bits.vdd;
  while Queue.is_empty sent do cycle () done;
  for _ = 1 to 6000 do cycle () done; (* MDIO status read back by now *)
  let ours = Queue.to_list sent in
  let expected = nibbles_of_bits (Reference.wire_bits (Arty_mii.payload @ [ 0 ])) in
  printf "TX: %d nibbles, matches reference: %b\n" (List.length ours) ([%equal: int list] ours expected);
  let pc_payload = List.init 6 ~f:(fun _ -> 0xff) @ [ 0x10; 0x20; 0x30; 0x40; 0x50; 0x60; 0x08; 0x06 ] @ List.init 50 ~f:Fn.id in
  let pc = nibbles_of_bits (Reference.wire_bits pc_payload) in
  let corrupt = List.mapi pc ~f:(fun k n -> if k = 60 then n lxor 1 else n) in
  let sfd_only = List.drop pc 15 in
  printf "LEDs LD4..LD7 after each RX frame (SW0 down: sent, good RX, link, 10M | SW0 up: id, RX_DV, echo, FD)\n";
  printf "  PC frame, SW0 down:       %s\n" (receive ~sw:false pc);
  printf "  PC frame, SFD only:       %s\n" (receive ~sw:false sfd_only);
  printf "  corrupted PC frame:       %s\n" (receive ~sw:false corrupt);
  printf "  our frame echoed, SW0 up: %s\n" (receive ~sw:true ours);
  [%expect {|
    TX: 144 nibbles, matches reference: true
    LEDs LD4..LD7 after each RX frame (SW0 down: sent, good RX, link, 10M | SW0 up: id, RX_DV, echo, FD)
      PC frame, SW0 down:       0111
      PC frame, SFD only:       0111
      corrupted PC frame:       0011
      our frame echoed, SW0 up: 1111
    |}]
;;
