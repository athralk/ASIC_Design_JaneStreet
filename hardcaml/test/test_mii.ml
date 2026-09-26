(* MII bridge and MDIO tests for the Arty build. The DP83848 is modelled at its MII
   pins: 2.5 MHz TX_CLK/RX_CLK (24 of our 60 MHz cycles per period), TXD/TX_EN sampled
   on TX_CLK rising edges, RXD/RX_DV driven on RX_CLK falling edges. *)

open! Core
open Hardcaml
open Eth10t

let cfg = { Config.default with prescale_bits = 10 } (* link pulses every ~15k cycles *)

(* One eth10t tile wired to the bridge, with the host pins exposed. *)
module Tile_mii = struct
  module I = struct
    type 'a t =
      { clk : 'a
      ; rst_n : 'a
      ; ui_in : 'a [@bits 8]
      ; tx_valid : 'a
      ; tx_clk : 'a
      ; rx_clk : 'a
      ; rx_dv : 'a
      ; rxd : 'a [@bits 4]
      }
    [@@deriving hardcaml]
  end

  module O = struct
    type 'a t =
      { uo_out : 'a [@bits 8]
      ; uio_out : 'a [@bits 8]
      ; txd : 'a [@bits 4]
      ; tx_en : 'a
      }
    [@@deriving hardcaml]
  end

  let create (i : _ I.t) =
    let open Signal in
    let rd = wire 1 in
    (* The bridge's RD is a register, so the falling-edge sample equals it. *)
    let tile =
      Tt_top.create_rd_fall
        ~cfg
        { Tt_top.I_rd_fall.clk = i.clk
        ; rst_n = i.rst_n
        ; ena = vdd
        ; ui_in = i.ui_in
        ; uio_in = concat_lsb [ gnd; gnd; rd; i.tx_valid; zero 4 ]
        ; rd_fall = rd
        }
    in
    let bridge =
      Mii_bridge.create
        ~cfg
        { Mii_bridge.I.clock = i.clk
        ; clear = ~:(i.rst_n)
        ; td_p = bit tile.uio_out 0
        ; td_n = bit tile.uio_out 1
        ; tx_clk = i.tx_clk
        ; rx_clk = i.rx_clk
        ; rx_dv = i.rx_dv
        ; rxd = i.rxd
        }
    in
    rd <== bridge.rd;
    { O.uo_out = tile.uo_out; uio_out = tile.uio_out; txd = bridge.txd; tx_en = bridge.tx_en }
  ;;

  module Sim = Cyclesim.With_interface (I) (O)
end

(* A node: simulation, host protocol and the PHY's MII clocks. *)
module Node = struct
  type t =
    { sim : Tile_mii.Sim.t
    ; i : Bits.t ref Tile_mii.I.t
    ; o : Bits.t ref Tile_mii.O.t
    ; mutable cycle : int
    ; mutable tx : int array option * int
    ; mutable prev_uio : int
    ; mutable rx_bytes : int list
    ; frames : (int list * int) Queue.t
    ; mutable rx_phase : float
    ; rx_half : float
    ; rx_queue : int option Queue.t (* nibbles to present; None = RX_DV low *)
    ; tx_nibbles : int Queue.t (* what the PHY sampled on TX_CLK *)
    ; mutable tx_bursts : int
    ; mutable prev_tx_en : bool
    }

  let create ?(ppm = 0) () =
    let sim = Tile_mii.Sim.create (Tile_mii.create) in
    let i = Cyclesim.inputs sim in
    i.rst_n := Bits.gnd;
    for _ = 1 to 4 do
      Cyclesim.cycle sim
    done;
    i.rst_n := Bits.vdd;
    { sim
    ; i
    ; o = Cyclesim.outputs sim
    ; cycle = 0
    ; tx = None, 0
    ; prev_uio = 0
    ; rx_bytes = []
    ; frames = Queue.create ()
    ; rx_phase = 0.
    ; rx_half = 12. *. (1. +. (Float.of_int ppm *. 1e-6))
    ; rx_queue = Queue.create ()
    ; tx_nibbles = Queue.create ()
    ; tx_bursts = 0
    ; prev_tx_en = false
    }
  ;;

  let send t payload = t.tx <- Some (Array.of_list payload), 0
  let set r v w = r := Bits.of_int ~width:w v

  let step t =
    (* Host TX protocol. *)
    (match t.tx with
     | Some p, k when k < Array.length p ->
       set t.i.ui_in p.(k) 8;
       t.i.tx_valid := Bits.vdd
     | _ -> t.i.tx_valid := Bits.gnd);
    (* PHY clocks: TX_CLK exact (locked to our reference), RX_CLK with ppm offset. *)
    let tx_clk = t.cycle % 24 >= 12 in
    let tx_rise = t.cycle % 24 = 12 in
    t.i.tx_clk := Bits.of_bool tx_clk;
    if tx_rise
    then (
      let en = Bits.to_bool !(t.o.tx_en) in
      if en then Queue.enqueue t.tx_nibbles (Bits.to_int !(t.o.txd));
      if en && not t.prev_tx_en then t.tx_bursts <- t.tx_bursts + 1;
      t.prev_tx_en <- en);
    let before = t.rx_phase in
    t.rx_phase <- t.rx_phase +. 1.;
    let crossed x = Float.(before < x && t.rx_phase >= x) in
    let period = 2. *. t.rx_half in
    let base = Float.round_down (before /. period) *. period in
    if crossed (base +. period) || crossed (base +. t.rx_half)
    then (
      let high = Float.(Float.mod_float t.rx_phase period < t.rx_half) in
      t.i.rx_clk := Bits.of_bool high;
      (* PHY drives RXD/RX_DV on the falling edge. *)
      if not high
      then (
        match Queue.dequeue t.rx_queue with
        | Some (Some n) ->
          t.i.rx_dv := Bits.vdd;
          set t.i.rxd n 4
        | Some None | None -> t.i.rx_dv := Bits.gnd));
    Cyclesim.cycle t.sim;
    t.cycle <- t.cycle + 1;
    (* Host side of the pins. *)
    let u = Bits.to_int !(t.o.uio_out) in
    let rose b = u land b <> 0 && t.prev_uio land b = 0 in
    let fell b = u land b = 0 && t.prev_uio land b <> 0 in
    let uo = Bits.to_int !(t.o.uo_out) in
    (match t.tx with
     | Some p, k when rose 0x10 ->
       t.tx <- (if k + 1 >= Array.length p then None, 0 else Some p, k + 1)
     | _ -> ());
    if rose 0x20 then t.rx_bytes <- uo :: t.rx_bytes;
    if fell 0x40
    then (
      Queue.enqueue t.frames (List.rev t.rx_bytes, uo);
      t.rx_bytes <- []);
    t.prev_uio <- u
  ;;

  let run t n =
    for _ = 1 to n do
      step t
    done
  ;;
end

let nibbles_of_bits bits =
  List.chunks_of bits ~length:4
  |> List.map ~f:(fun b ->
    List.foldi b ~init:0 ~f:(fun k acc x -> if x then acc lor (1 lsl k) else acc))
;;

let crc_ok status = status land 0x10 <> 0
let payload = List.init 30 ~f:(fun k -> (k * 29 + 7) land 0xff)

let%expect_test "TX: MII nibbles equal the reference frame; link pulses are not sent" =
  let n = Node.create () in
  Node.send n payload;
  Node.run n 60_000;
  let got = Queue.to_list n.tx_nibbles in
  let expected = nibbles_of_bits (Reference.wire_bits payload) in
  printf "nibbles=%d expected=%d match=%b bursts=%d\n"
    (List.length got) (List.length expected) ([%equal: int list] got expected) n.tx_bursts;
  [%expect {| nibbles=144 expected=144 match=true bursts=1 |}]
;;

let rx_test ~ppm ~drop_preamble_nibbles =
  let n = Node.create ~ppm () in
  let frame = nibbles_of_bits (Reference.wire_bits payload) in
  Queue.enqueue_all n.rx_queue (List.init 4 ~f:(fun _ -> None));
  Queue.enqueue_all n.rx_queue (List.map (List.drop frame drop_preamble_nibbles) ~f:Option.some);
  Queue.enqueue_all n.rx_queue (List.init 4 ~f:(fun _ -> None));
  Node.run n 30_000;
  match Queue.dequeue n.frames with
  | Some (bytes, status) ->
    sprintf "match=%b crc_ok=%b" ([%equal: int list] bytes (Reference.frame payload)) (crc_ok status)
  | None -> "no frame"
;;

(* The DP83848 in 10 Mb/s half duplex echoes TX back on RX (802.3 10BASE-T loopback).
   Model it: every nibble we send reappears on RXD, a few MII clocks later. *)
let%expect_test "TX with the PHY's half-duplex echo: frame is not aborted" =
  let n = Node.create () in
  Node.send n payload;
  let echoed = ref 0 in
  for _ = 1 to 60_000 do
    Node.step n;
    let fresh = Queue.length n.tx_nibbles - !echoed in
    if fresh > 0
    then (
      List.iter (List.drop (Queue.to_list n.tx_nibbles) !echoed) ~f:(fun x ->
        Queue.enqueue n.rx_queue (Some x));
      echoed := Queue.length n.tx_nibbles);
    if Queue.is_empty n.rx_queue && not n.prev_tx_en then Queue.enqueue n.rx_queue None
  done;
  let got = Queue.to_list n.tx_nibbles in
  let expected = nibbles_of_bits (Reference.wire_bits payload) in
  printf "nibbles=%d match=%b status=0x%02x\n"
    (List.length got) ([%equal: int list] got expected) (Bits.to_int !(n.o.uo_out));
  [%expect {| nibbles=144 match=true status=0x00 |}]
;;

let%expect_test "RX: MII nibbles reach the host intact" =
  List.iter [ -100; 0; 100 ] ~f:(fun ppm ->
    printf "ppm %+4d, full preamble : %s\n" ppm (rx_test ~ppm ~drop_preamble_nibbles:0);
    printf "ppm %+4d, SFD only      : %s\n" ppm (rx_test ~ppm ~drop_preamble_nibbles:14));
  [%expect {|
    ppm -100, full preamble : match=true crc_ok=true
    ppm -100, SFD only      : match=true crc_ok=true
    ppm   +0, full preamble : match=true crc_ok=true
    ppm   +0, SFD only      : match=true crc_ok=true
    ppm +100, full preamble : match=true crc_ok=true
    ppm +100, SFD only      : match=true crc_ok=true
    |}]
;;

let%expect_test "end to end: chip A -> MII -> PHY pair -> MII -> chip B" =
  let a = Node.create () and b = Node.create ~ppm:80 () in
  Node.send a payload;
  for _ = 1 to 40_000 do
    Node.step a;
    (* What A's PHY sends, B's PHY receives (one nibble per 2.5 MHz period). *)
    Queue.iter a.tx_nibbles ~f:(fun x -> Queue.enqueue b.rx_queue (Some x));
    Queue.clear a.tx_nibbles;
    if Queue.is_empty b.rx_queue && not a.prev_tx_en then Queue.enqueue b.rx_queue None;
    Node.step b
  done;
  (match Queue.dequeue b.frames with
   | Some (bytes, status) ->
     printf "match=%b crc_ok=%b\n" ([%equal: int list] bytes (Reference.frame payload)) (crc_ok status)
   | None -> print_endline "no frame");
  [%expect {| match=true crc_ok=true |}]
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
    regs.(1) <- 0x782D; (* BMSR with link up *)
    regs.(2) <- 0x2000; (* PHY identifier 1 of the DP83848 *)
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

let%expect_test "MDIO: writes land in the PHY, and the readback matches" =
  let sim = Mdio_sim.create Mdio.create in
  let i = Cyclesim.inputs sim and o = Cyclesim.outputs sim in
  let phy = Phy_mdio.create () in
  i.start := Bits.vdd;
  let prev_mdc = ref false in
  for _ = 1 to 40_000 do
    let mac_oe = Bits.to_bool !(o.mdio_oe) and mac_o = Bits.to_bool !(o.mdio_o) in
    i.mdio_i := Bits.of_bool (Phy_mdio.line phy ~mac_oe ~mac_o);
    Cyclesim.cycle sim;
    let mdc = Bits.to_bool !(o.mdc) in
    if mdc && not !prev_mdc
    then Phy_mdio.rising phy (if mac_oe then Some mac_o else None);
    prev_mdc := mdc
  done;
  List.iter phy.writes ~f:(fun (p, r, d) -> printf "PHY got write: phy=%d reg=%d data=0x%04x\n" p r d);
  printf "done=%b id_ok=%b anar_ok=%b link=%b phy_drove=%b\n"
    (Bits.to_bool !(o.done_)) (Bits.to_bool !(o.id_ok)) (Bits.to_bool !(o.anar_ok))
    (Bits.to_bool !(o.link)) (Bits.to_bool !(o.phy_drove));
  [%expect {|
    PHY got write: phy=1 reg=4 data=0x0021
    PHY got write: phy=1 reg=0 data=0x1200
    done=true id_ok=true anar_ok=true link=true phy_drove=true
    |}]
;;

module Arty_sim = Cyclesim.With_interface (Arty_mii.I) (Arty_mii.O)

let%expect_test "Arty board logic: PHY reset, MDIO config, then a demo frame on MII" =
  let sim =
    Arty_sim.create (Arty_mii.create ~cfg ~period_bits:15 ~led_bits:4 ~phy_reset_bits:8)
  in
  let i = Cyclesim.inputs sim and o = Cyclesim.outputs sim in
  let phy = Phy_mdio.create () in
  i.rst_n := Bits.gnd;
  Cyclesim.cycle sim;
  i.rst_n := Bits.vdd;
  let rstn_at = ref None and configured_at = ref None and nibbles = ref [] in
  let prev_mdc = ref false in
  let views = Array.create ~len:4 0 in
  for cycle = 1 to 60_000 do
    i.eth_tx_clk := Bits.of_bool (cycle % 24 >= 12);
    i.eth_rx_clk := Bits.of_bool (cycle % 24 >= 12);
    let mac_oe = Bits.to_bool !(o.mdio_oe) and mac_o = Bits.to_bool !(o.mdio_o) in
    i.mdio_i := Bits.of_bool (Phy_mdio.line phy ~mac_oe ~mac_o);
    (* Cycle through the LED views near the end. *)
    i.sw := Bits.of_int ~width:2 (if cycle > 59_000 then (cycle - 59_000) / 250 % 4 else 0);
    if cycle % 24 = 12 && Bits.to_bool !(o.eth_tx_en)
    then nibbles := Bits.to_int !(o.eth_txd) :: !nibbles;
    Cyclesim.cycle sim;
    let mdc = Bits.to_bool !(o.eth_mdc) in
    if mdc && not !prev_mdc then Phy_mdio.rising phy (if mac_oe then Some mac_o else None);
    prev_mdc := mdc;
    if cycle > 59_000 && (cycle - 59_000) % 250 = 249
    then views.((cycle - 59_000) / 250 % 4) <- Bits.to_int !(o.led);
    if Option.is_none !rstn_at && Bits.to_bool !(o.eth_rstn) then rstn_at := Some cycle;
    if Option.is_none !configured_at && Bits.to_int !(o.led) land 4 <> 0
    then configured_at := Some cycle
  done;
  let first_frame =
    let expected = nibbles_of_bits (Reference.wire_bits (Demo.frame_bytes @ [ 0 ])) in
    [%equal: int list] (List.take (List.rev !nibbles) (List.length expected)) expected
  in
  printf "PHY out of reset at cycle %d, configured at cycle %d\n"
    (Option.value_exn !rstn_at) (Option.value_exn !configured_at);
  printf "first demo frame on MII matches reference: %b\n" first_frame;
  let show v = String.init 4 ~f:(fun k -> if v land (1 lsl k) <> 0 then '1' else '0') in
  printf "LD4..LD7  normal=%s  mii=%s  mdio=%s\n" (show views.(0)) (show views.(1)) (show views.(2));
  [%expect {|
    PHY out of reset at cycle 256, configured at cycle 4609
    first demo frame on MII matches reference: true
    LD4..LD7  normal=0011  mii=1100  mdio=1111
    |}]
;;
