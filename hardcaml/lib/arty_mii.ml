(* Arty A7 board logic: demo host + eth10t chip + MII bridge to the on-board DP83848
   PHY + MDIO configuration. Everything runs on the 60 MHz clock. The board wrapper
   (fpga/arty/top.v) supplies the clocks and pin buffers.

   LD4..LD7 (led[0..3]) show one of three views, chosen by SW1/SW0:
     00  normal: frame sent, good frame received, PHY configured, running
     01  MII:    TX_CLK arriving, RX_CLK arriving, we drive TX_EN, PHY drives RX_DV
     10  MDIO:   PHY ID reads 0x2000, our 10 Mb/s setting reads back, PHY link up,
                 PHY has driven MDIO at all *)

open! Base
open Hardcaml
open Signal

let name = "eth10t_arty"

module I = struct
  type 'a t =
    { clock : 'a
    ; rst_n : 'a
    ; sw : 'a [@bits 2]
    ; eth_tx_clk : 'a
    ; eth_rx_clk : 'a
    ; eth_rx_dv : 'a
    ; eth_rxd : 'a [@bits 4]
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

(* After reset: hold the PHY in reset for 2^phy_reset_bits cycles (~1 ms), then wait
   as long again before configuring it over MDIO. *)
let create ?cfg ?period_bits ?(led_bits = 22) ?(phy_reset_bits = 16) (i : _ I.t) =
  let spec = Reg_spec.create ~clock:i.clock ~clear:~:(i.rst_n) () in
  let clear = ~:(i.rst_n) in
  let timer =
    reg_fb spec ~width:(phy_reset_bits + 2) ~f:(fun t -> mux2 (msb t) t (t +:. 1))
  in
  let phy_out_of_reset = timer >=:. 1 lsl phy_reset_bits in
  let mdio = Mdio.create { Mdio.I.clock = i.clock; clear; start = msb timer; mdio_i = i.mdio_i } in
  let rd = wire 1 in
  let demo =
    Demo.create ?cfg ?period_bits ~led_bits { Demo.I.clock = i.clock; rst_n = i.rst_n; rd }
  in
  let bridge =
    Mii_bridge.create
      ?cfg
      { Mii_bridge.I.clock = i.clock
      ; clear
      ; td_p = demo.td_p
      ; td_n = demo.td_n
      ; tx_clk = i.eth_tx_clk
      ; rx_clk = i.eth_rx_clk
      ; rx_dv = i.eth_rx_dv
      ; rxd = i.eth_rxd
      }
  in
  rd <== bridge.rd;
  (* Keep an LED lit for ~70 ms after each event, so activity is visible. *)
  let stretch event =
    reg_fb spec ~width:led_bits ~f:(fun c ->
      mux2 event (ones led_bits) (mux2 (c ==:. 0) c (c -:. 1)))
    <>:. 0
  in
  let sw = pipeline (Reg_spec.create ~clock:i.clock ()) ~n:2 i.sw in
  let normal = concat_lsb [ demo.led_tx; demo.led_rx; mdio.done_; i.rst_n ] in
  let mii_view =
    concat_lsb
      [ stretch bridge.tx_clk_edge
      ; stretch bridge.rx_clk_edge
      ; stretch bridge.tx_en
      ; stretch bridge.rx_dv_seen
      ]
  in
  let mdio_view = concat_lsb [ mdio.id_ok; mdio.anar_ok; mdio.link; mdio.phy_drove ] in
  { O.eth_txd = bridge.txd
  ; eth_tx_en = bridge.tx_en
  ; eth_rstn = phy_out_of_reset
  ; eth_mdc = mdio.mdc
  ; mdio_o = mdio.mdio_o
  ; mdio_oe = mdio.mdio_oe
  ; led = mux sw [ normal; mii_view; mdio_view; normal ]
  }
;;

let circuit ?cfg ?period_bits ?led_bits ?phy_reset_bits () =
  let module C = Circuit.With_interface (I) (O) in
  C.create_exn ~name (create ?cfg ?period_bits ?led_bits ?phy_reset_bits)
;;
