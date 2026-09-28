(* Arty A7 board logic: an MII MAC for the on-board DP83848 PHY, plus PHY reset, MDIO
   and LEDs. Three clocks: [clock] (25 MHz system, from the MMCM), and the PHY's
   [eth_tx_clk] and [eth_rx_clk], which clock the MAC's TX and RX sides.

   LD4..LD7 (led[0..3]):
     SW0 down: frame sent, good frame from the PC, link up, link is 10 Mb/s
     SW0 up:   MDIO works (PHY ID), PHY receiving (RX_DV), our echo seen, full duplex *)

open! Base
open Hardcaml
open Signal

let name = "eth10t_arty"

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sw : 'a
    ; eth_tx_clk : 'a
    ; eth_rx_clk : 'a
    ; eth_rx_dv : 'a
    ; eth_rxd : 'a [@bits 4]
    ; eth_crs : 'a
    ; mdio_i : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { eth_txd : 'a [@bits 4]
    ; eth_tx_en : 'a
    ; eth_rstn : 'a
    ; eth_mdc : 'a
    ; mdio_o : 'a
    ; mdio_oe : 'a
    ; led : 'a [@bits 4]
    }
  [@@deriving hardcaml]
end

let payload = Demo.frame_bytes
let our_mac = List.sub payload ~pos:6 ~len:6

(* At 25 MHz: PHY reset for 2^15 cycles (1.3 ms), MDIO after as long again, a frame
   every 2^25 cycles (1.34 s), LEDs lit for 2^22 cycles (170 ms) per event. *)
let create ?(phy_reset_bits = 15) ?(period_bits = 25) ?(led_bits = 22) (i : _ I.t) =
  let clear = ~:(i.rst_n) in
  let spec = Reg_spec.create ~clock:i.clock ~clear () in
  let nr = Reg_spec.create ~clock:i.clock () in
  let timer =
    reg_fb spec ~width:(phy_reset_bits + 2) ~f:(fun t -> mux2 (msb t) t (t +:. 1))
  in
  let mdio =
    Mdio.create { Mdio.I.clock = i.clock; clear; start = msb timer; mdio_i = i.mdio_i }
  in
  let period = reg_fb spec ~width:period_bits ~f:(fun t -> t +:. 1) in
  let send = reg_fb spec ~width:1 ~f:(fun t -> mux2 (period ==:. 0) ~:t t) in
  let tx_spec = Reg_spec.create ~clock:i.eth_tx_clk () in
  let tx =
    Mii_mac.Tx.create
      ~clock:i.eth_tx_clk
      ~start:(Mii_mac.toggle_event tx_spec send)
      ~crs:i.eth_crs
      ~payload
  in
  let rx =
    Mii_mac.Rx.create ~clock:i.eth_rx_clk ~rx_dv:i.eth_rx_dv ~rxd:i.eth_rxd ~our_mac
  in
  (* Keep an LED lit for a while after each event. *)
  let stretch event =
    reg_fb spec ~width:led_bits ~f:(fun c ->
      mux2 event (ones led_bits) (mux2 (c ==:. 0) c (c -:. 1)))
    <>:. 0
  in
  let seen toggle = stretch (Mii_mac.toggle_event nr toggle) in
  let normal = concat_lsb [ seen tx.sent; seen rx.good; mdio.link; mdio.speed_10 ] in
  let check =
    concat_lsb
      [ mdio.id_ok
      ; stretch (pipeline nr ~n:2 rx.rx_dv)
      ; seen rx.echo
      ; mdio.full_duplex
      ]
  in
  { O.eth_txd = tx.txd
  ; eth_tx_en = tx.tx_en
  ; eth_rstn = timer >=:. 1 lsl phy_reset_bits
  ; eth_mdc = mdio.mdc
  ; mdio_o = mdio.mdio_o
  ; mdio_oe = mdio.mdio_oe
  ; led = mux2 (pipeline nr ~n:2 i.sw) check normal
  }
;;

let circuit ?phy_reset_bits ?period_bits ?led_bits () =
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name (create ?phy_reset_bits ?period_bits ?led_bits)
;;
