(* Receiver jitter tolerance. Every edge on the cable moves by a uniform random amount
   in +-J ns, with the two clocks offset by -100/0/+100 ppm and sampling phases spread
   over the clock period. 802.3 Clause 14 asks the receiver to handle +-13.5 ns. *)

open! Core
open Harness
open Eth10t

let frames_per_trial = 8

let trial ~jitter ~ppm ~phase ~seed =
  let w = World.create ~ppm ~jitter_ns:jitter ~phase ~seed () in
  let frames =
    List.init frames_per_trial ~f:(fun k ->
      List.init 64 ~f:(fun i -> ((i * 13) + k) land 0xff))
  in
  List.iter frames ~f:(Node.send w.a);
  World.run_until w ~f:(fun w -> Node.tx_idle w.a && not (Node.busy w.a));
  World.run_cycles w 200;
  Queue.to_list w.b.rx_frames
  |> List.count ~f:(fun f ->
    status_bit f.status Eth_core.Status.crc_ok
    && List.exists frames ~f:(fun p -> [%equal: int list] f.bytes (Reference.frame p)))
;;

let%expect_test "jitter sweep: good frames" =
  let phases = [ 0.1; 0.35; 0.6; 0.85 ] in
  let ppms = [ -100; 0; 100 ] in
  let total = frames_per_trial * List.length phases * List.length ppms in
  List.iter [ 0.; 5.; 10.; 12.; 13.5; 15.; 17.5; 20. ] ~f:(fun jitter ->
    let good =
      List.sum (module Int) phases ~f:(fun phase ->
        List.sum (module Int) ppms ~f:(fun ppm ->
          trial ~jitter ~ppm ~phase ~seed:(Float.to_int (phase *. 100.) + ppm)))
    in
    printf "+-%4.1f ns  %3d/%d\n" jitter good total);
  [%expect {|
    +- 0.0 ns   96/96
    +- 5.0 ns   96/96
    +-10.0 ns   96/96
    +-12.0 ns   96/96
    +-13.5 ns   96/96
    +-15.0 ns   89/96
    +-17.5 ns   33/96
    +-20.0 ns    5/96
    |}]
;;
