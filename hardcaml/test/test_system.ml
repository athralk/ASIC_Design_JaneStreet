(* Two tiles on a cable, with independent clocks. Covers error injection, CSMA/CD
   behaviour and link integrity. *)

open! Core
open Harness
open Eth10t

let us_fs = 1_000_000_000
let payload n = List.init n ~f:(fun i -> (i * 7 + 3) land 0xff)
let crc_ok f = status_bit f.status Eth_core.Status.crc_ok
let in_frame (n : Node.t) = Node.uio n land 0x40 <> 0

let result_to_string = function
  | Node.Sent -> "sent"
  | Aborted s ->
    sprintf
      "aborted (collision=%b jabber=%b)"
      (status_bit s Eth_core.Status.collision)
      (status_bit s Eth_core.Status.jabber)
;;

let%expect_test "corrupted frame is delivered with crc_ok=false" =
  let w = World.create ~ppm:50 ~jitter_ns:5. () in
  Node.send w.a (payload 100);
  World.run_until w ~f:(fun w -> in_frame w.b);
  let t = World.now w + (20 * us_fs) in
  w.ab.glitch <- Some (t, t + 150_000_000);
  World.run_until w ~f:(fun w -> not (Queue.is_empty w.b.rx_frames));
  let f = Queue.dequeue_exn w.b.rx_frames in
  printf "bytes=%d crc_ok=%b\n" (List.length f.bytes) (crc_ok f);
  [%expect {| bytes=104 crc_ok=false |}]
;;

let%expect_test "receiver locks even if the first 1.5 us of preamble is lost" =
  let w = World.create ~ppm:(-80) ~jitter_ns:5. () in
  let p = payload 64 in
  Node.send w.a p;
  w.ab.cut <- true;
  World.run_until w ~f:(fun w -> Node.td_p w.a || Node.td_n w.a);
  let resume = World.now w + (3 * us_fs / 2) in
  World.run_until w ~f:(fun w -> World.now w >= resume);
  w.ab.cut <- false;
  World.run_until w ~f:(fun w -> not (Queue.is_empty w.b.rx_frames));
  let f = Queue.dequeue_exn w.b.rx_frames in
  printf "match=%b crc_ok=%b\n" ([%equal: int list] f.bytes (Reference.frame p)) (crc_ok f);
  [%expect {| match=true crc_ok=true |}]
;;

let%expect_test "simultaneous transmit: both sides detect collision and jam" =
  let w = World.create ~phase:0.5 () in
  Node.send w.a (payload 200);
  Node.send w.b (payload 200);
  World.run_until w ~f:(fun w ->
    Queue.length w.a.tx_results = 1 && Queue.length w.b.tx_results = 1);
  printf "A: %s\n" (result_to_string (Queue.dequeue_exn w.a.tx_results));
  printf "B: %s\n" (result_to_string (Queue.dequeue_exn w.b.tx_results));
  World.run_cycles w 2000;
  let good n = Queue.exists n.Node.rx_frames ~f:crc_ok in
  printf "any good frame received: %b\n" (good w.a || good w.b);
  [%expect {|
    A: aborted (collision=true jabber=false)
    B: aborted (collision=true jabber=false)
    any good frame received: false
    |}]
;;

let%expect_test "deference: B waits for the line to be idle plus 9.6 us" =
  let w = World.create ~ppm:30 () in
  let pa = payload 200 and pb = payload 50 in
  Node.send w.a pa;
  World.run_until w ~f:(fun w -> in_frame w.b);
  Node.send w.b pb;
  World.run_until w ~f:(fun w -> not (Queue.is_empty w.b.rx_frames));
  let carrier_end = World.now w in
  World.run_until w ~f:(fun w -> Node.td_p w.b || Node.td_n w.b);
  let gap_us = Float.of_int (World.now w - carrier_end) /. Float.of_int us_fs in
  World.run_until w ~f:(fun w -> not (Queue.is_empty w.a.rx_frames));
  let fa = Queue.dequeue_exn w.b.rx_frames and fb = Queue.dequeue_exn w.a.rx_frames in
  printf "B deferred, then transmitted %.1f us after carrier end (>= 9.6 us)\n" gap_us;
  printf "A->B ok=%b  B->A ok=%b\n"
    ([%equal: int list] fa.bytes (Reference.frame pa) && crc_ok fa)
    ([%equal: int list] fb.bytes (Reference.frame pb) && crc_ok fb);
  [%expect {|
    B deferred, then transmitted 9.9 us after carrier end (>= 9.6 us)
    A->B ok=true  B->A ok=true
    |}]
;;

(* Timers are scaled down by 2^6 here and the results scaled back up. *)
let%expect_test "link integrity: up on link pulses, down after silence" =
  let cfg = { Config.default with prescale_bits = 10 } in
  let scale = Float.of_int (1 lsl (Config.default.prescale_bits - cfg.prescale_bits)) in
  let ms (w : World.t) = Float.of_int (World.now w) /. 1e12 *. scale in
  let w = World.create ~cfg () in
  World.run_until w ~f:(fun w -> Node.link_up w.b);
  printf "link up at %.1f ms (first NLP)\n" (ms w);
  World.run_cycles w 200_000;
  printf "still up after %.0f ms of NLPs: %b\n" (ms w) (Node.link_up w.b);
  w.ab.cut <- true;
  let t0 = ms w in
  World.run_until w ~f:(fun w -> not (Node.link_up w.b));
  printf "link lost %.1f ms after cable cut (50..150 ms)\n" (ms w -. t0);
  printf "NLPs delivered as frames: %d\n" (Queue.length w.b.rx_frames);
  [%expect {|
    link up at 16.4 ms (first NLP)
    still up after 230 ms of NLPs: true
    link lost 69.5 ms after cable cut (50..150 ms)
    NLPs delivered as frames: 0
    |}]
;;
