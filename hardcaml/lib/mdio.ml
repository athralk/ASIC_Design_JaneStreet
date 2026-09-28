(* MDIO master for the PHY: writes the configuration once after [start], then keeps
   reading back the PHY ID and status so the board can show what the PHY really does.

   Every access is a 64-bit frame, sent MSB first:
     32 x 1 (preamble) | 01 (start) | OP | PHYAD | REGAD | TA | DATA (16)
   Write: OP = 01, and we drive TA = 10 and DATA.
   Read:  OP = 10; we release the line for TA and DATA and the PHY drives them.
   MDIO changes while MDC is low, and is sampled around MDC's rising edge. *)

open! Base
open Hardcaml
open Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; mdio_i : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { mdc : 'a
    ; mdio_o : 'a
    ; mdio_oe : 'a
    ; done_ : 'a (* configuration writes sent *)
    ; id_ok : 'a (* PHY identifier 1 reads 0x2000 (TI DP83848) *)
    ; link : 'a (* PHYSTS: link up *)
    ; speed_10 : 'a (* PHYSTS: link is 10 Mb/s *)
    ; full_duplex : 'a (* PHYSTS: full duplex *)
    }
  [@@deriving hardcaml]
end

(* DP83848 on the Arty A7. ANAR = 10BASE-T half and full duplex only; BMCR =
   auto-negotiation enabled and restarted. *)
let phy_address = 1
let anar = 0x0061
let writes = [ 4, anar; 0, 0x1200 ]
let phy_id1 = 0x2000
let physts = 0x10
let reads = [ 2; physts ] (* PHY identifier 1, PHY status *)

let bits n v = List.init n ~f:(fun k -> (v lsr (n - 1 - k)) land 1 = 1)

(* Bits to drive, and whether we drive each one. *)
let frame ~read ~reg ~data =
  let head =
    List.init 32 ~f:(fun _ -> true)
    @ bits 2 0b01
    @ bits 2 (if read then 0b10 else 0b01)
    @ bits 5 phy_address
    @ bits 5 reg
  in
  let tail = if read then List.init 18 ~f:(fun _ -> true) else bits 2 0b10 @ bits 16 data in
  List.map head ~f:(fun b -> b, true)
  @ List.map tail ~f:(fun b -> b, not read)
;;

let write_stream = List.concat_map writes ~f:(fun (reg, data) -> frame ~read:false ~reg ~data)
let read_stream = List.concat_map reads ~f:(fun reg -> frame ~read:true ~reg ~data:0)

(* Bits we drive during the write frames only; used by the tests. *)
let stream = List.map write_stream ~f:fst

(* MDC = clock / 2^divider_bits (25 MHz / 16 = 1.56 MHz, below the 25 MHz limit). *)
let create ?(divider_bits = 4) (i : _ I.t) =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let nr = Reg_spec.create ~clock:i.clock () in
  let all = write_stream @ read_stream in
  let len = List.length all in
  let first_read = List.length write_stream in
  let div = Variable.reg spec ~width:divider_bits in
  let index = Variable.reg spec ~width:(num_bits_to_represent len) in
  let busy = Variable.reg spec ~width:1 in
  let done_ = Variable.reg spec ~width:1 in
  let rom f = mux index.value (List.map all ~f:(fun b -> Signal.of_bool (f b)) @ [ gnd ]) in
  let drive_bit = rom fst in
  let drive_en = rom snd in
  let period_end = div.value ==: ones divider_bits in
  (* Sample just before MDC rises, when the PHY's data has long settled. *)
  let sample_now = busy.value &: (div.value ==:. (1 lsl (divider_bits - 1)) - 1) in
  let mdio_in = pipeline nr ~n:2 i.mdio_i in
  (* Position inside the current 64-bit frame; data bits are 48..63. *)
  let pos = sel_bottom index.value 6 in
  let in_read = index.value >=:. first_read in
  let data_bit = in_read &: (pos >=:. 48) in
  let shift = Variable.reg nr ~width:16 in
  let results = List.map reads ~f:(fun _ -> Variable.reg spec ~width:16) in
  let which = uresize (srl (index.value -:. first_read) 6) 2 in
  compile
    ([ if_
         busy.value
         [ div <-- div.value +:. 1
         ; when_
             period_end
             [ index <-- index.value +:. 1
             ; when_ (index.value ==:. first_read - 1) [ done_ <--. 1 ]
             ; (* After the last read, go round the reads again. *)
               when_ (index.value ==:. len - 1) [ index <--. first_read ]
             ]
         ]
         [ div <--. 0; when_ (i.start &: ~:(done_.value)) [ busy <--. 1; index <--. 0 ] ]
     ; when_
         (sample_now &: data_bit)
         [ shift <-- (sel_bottom shift.value 15 @: mdio_in) ]
     ]
     @ List.mapi results ~f:(fun k r ->
       when_
         (sample_now &: data_bit &: (pos ==:. 63) &: (which ==:. k))
         [ r <-- (sel_bottom shift.value 15 @: mdio_in) ]));
  let result reg =
    let k, _ = List.findi_exn reads ~f:(fun _ r -> r = reg) in
    (List.nth_exn results k).value
  in
  { O.mdc = busy.value &: msb div.value
  ; mdio_o = reg nr (busy.value &: drive_bit)
  ; mdio_oe = reg nr (busy.value &: drive_en)
  ; done_ = done_.value
  ; id_ok = result 2 ==:. phy_id1
  ; link = bit (result physts) 0
  ; speed_10 = bit (result physts) 1
  ; full_duplex = bit (result physts) 2
  }
;;
