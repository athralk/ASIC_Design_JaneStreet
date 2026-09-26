(* Transmit compliance checks against IEEE 802.3 Clause 14, on the cycle-exact TD+/TD-
   waveform of a single node. *)

open! Core
open Harness
open Eth10t

let cfg = Config.default
let ns cycles = Float.of_int cycles *. 1e9 /. Float.of_int (Config.clock_hz cfg)

let capture node ~cycles =
  Array.init cycles ~f:(fun _ ->
    Node.step node;
    Node.td_p node, Node.td_n node)
;;

(* Split a waveform into runs of (level, length). The level is +1, -1 or 0. *)
let runs wave =
  let level (p, n) = if p && not n then 1 else if n && not p then -1 else 0 in
  Array.fold wave ~init:[] ~f:(fun acc s ->
    let l = level s in
    match acc with
    | (l', k) :: rest when l = l' -> (l, k + 1) :: rest
    | _ -> (l, 1) :: acc)
  |> List.rev
;;

let%expect_test "frame waveform: Manchester, framing, padding, FCS, TP_IDL" =
  let node = Node.create ~cfg () in
  let payload = String.to_list "Hardcaml!" |> List.map ~f:Char.to_int in
  Node.send node payload;
  let wave = capture node ~cycles:9000 in
  let start = Array.findi_exn wave ~f:(fun _ (p, n) -> p || n) |> fst in
  let expected = Reference.wire_bits payload in
  let half = cfg.half_bit in
  let bits =
    List.mapi expected ~f:(fun b _ ->
      let at k = wave.(start + (b * 2 * half) + k) in
      let first = List.init half ~f:(fun k -> at k) in
      let second = List.init half ~f:(fun k -> at (half + k)) in
      let all_eq l = List.for_all l ~f:(fun x -> [%equal: bool * bool] x (List.hd_exn l)) in
      let differential (p, n) = Bool.( <> ) p n in
      assert (all_eq first && all_eq second);
      assert (List.for_all (first @ second) ~f:differential);
      let v1 = fst (List.hd_exn first) and v2 = fst (List.hd_exn second) in
      assert (Bool.( <> ) v1 v2);
      v2)
  in
  let last = start + (List.length expected * 2 * half) in
  let idle_high =
    Array.sub wave ~pos:last ~len:100
    |> Array.to_list
    |> List.take_while ~f:(fun (p, n) -> p && not n)
    |> List.length
  in
  let after = Array.sub wave ~pos:(last + idle_high) ~len:1000 in
  printf "bits match reference : %b\n" ([%equal: bool list] bits expected);
  printf "bits on wire         : %d (8 preamble/SFD + 60 data + 4 FCS bytes)\n" (List.length bits);
  printf "TP_IDL high          : %.0f ns (>= 250 ns)\n" (ns idle_high);
  printf "line idle after      : %b\n" (Array.for_all after ~f:(fun (p, n) -> not (p || n)));
  printf "host result          : %s\n"
    (match Queue.dequeue node.tx_results with
     | Some Sent -> "sent"
     | Some (Aborted s) -> sprintf "aborted %x" s
     | None -> "none");
  [%expect
    {|
    bits match reference : true
    bits on wire         : 576 (8 preamble/SFD + 60 data + 4 FCS bytes)
    TP_IDL high          : 250 ns (>= 250 ns)
    line idle after      : true
    host result          : sent
    |}]
;;

let%expect_test "link pulses: width and period (full-scale timers)" =
  let node = Node.create ~cfg () in
  let wave = capture node ~cycles:(3 * 1_100_000) in
  let r = runs wave in
  let pulses, _ =
    List.fold r ~init:([], 0) ~f:(fun (acc, t) (l, k) ->
      (if l = 1 then (t, k) :: acc else if l = -1 then failwith "negative pulse" else acc), t + k)
  in
  let pulses = List.rev pulses in
  let periods =
    List.zip_exn (List.drop_last_exn pulses) (List.tl_exn pulses)
    |> List.map ~f:(fun ((a, _), (b, _)) -> ns (b - a) /. 1e6)
  in
  List.iter pulses ~f:(fun (_, w) -> printf "NLP width  %.0f ns (100 ns nominal)\n" (ns w));
  List.iter periods ~f:(fun p -> printf "NLP period %.2f ms (16 +- 8 ms)\n" p);
  [%expect
    {|
    NLP width  100 ns (100 ns nominal)
    NLP width  100 ns (100 ns nominal)
    NLP width  100 ns (100 ns nominal)
    NLP period 16.38 ms (16 +- 8 ms)
    NLP period 16.38 ms (16 +- 8 ms)
    |}]
;;

let%expect_test "jabber: a host that never stops is cut off" =
  let node = Node.create ~cfg () in
  (* 60000 bytes is 48 ms on the wire. *)
  Node.send node (List.init 60_000 ~f:(fun i -> i land 0xff));
  let wave = capture node ~cycles:3_300_000 in
  let r = runs wave in
  let active =
    List.drop_while r ~f:(fun (l, _) -> l = 0)
    |> List.take_while ~f:(fun (l, k) -> l <> 0 || k < 1000)
    |> List.sum (module Int) ~f:snd
  in
  printf "transmitted for %.1f ms before cut-off (20..150 ms)\n" (ns active /. 1e6);
  printf "status jabber=%b\n" (status_bit node.status Eth_core.Status.jabber);
  printf "host saw abort: %b\n"
    (match Queue.dequeue node.tx_results with
     | Some (Aborted _) -> true
     | _ -> false);
  [%expect {|
    transmitted for 33.9 ms before cut-off (20..150 ms)
    status jabber=true
    host saw abort: true
    |}]
;;
