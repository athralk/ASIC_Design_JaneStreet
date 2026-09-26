(* Constrained-random traffic with a scoreboard and functional coverage.

   Each scenario draws a clock offset, cable jitter, phase and traffic shape. Node A
   sends a burst of frames and B optionally echoes every good frame back, so the two
   sides share the half-duplex line. Some scenarios give B its own traffic from the
   start, so both sides transmit together, collide, and back off. The
   scoreboard checks every delivered frame against the reference model, in order.
   Scenarios keep coming until every coverage bin is hit. *)

open! Core
open Harness
open Eth10t

let corner_lengths = [ 1; 2; 45; 46; 59; 60; 61; 63; 64; 127; 128; 1500 ]

let gen_length rng =
  if Random.State.int rng 10 < 4
  then List.random_element_exn ~random_state:rng corner_lengths
  else Random.State.int_incl rng 1 300
;;

let gen_payload rng n = List.init n ~f:(fun _ -> Random.State.int rng 256)

module Coverage = struct
  type t = (string, int) Hashtbl.t

  let bins =
    [ "len 1-45 (padded)"; "len 46-59 (padded)"; "len 60 (no pad)"; "len 61-1499"
    ; "len 1500 (max)"; "ppm -100"; "ppm 0"; "ppm +100"; "jitter 0 ns"; "jitter 4 ns"
    ; "jitter 8 ns"; "A->B"; "B->A (echo)"; "B->A (contending)"; "back-to-back"
    ; "collision + backoff"
    ]
  ;;

  let create () : t = Hashtbl.of_alist_exn (module String) (List.map bins ~f:(fun b -> b, 0))
  let hit (t : t) b = Hashtbl.update t b ~f:(fun v -> Option.value_exn v + 1)

  let length_bin n =
    if n <= 45
    then "len 1-45 (padded)"
    else if n <= 59
    then "len 46-59 (padded)"
    else if n = 60
    then "len 60 (no pad)"
    else if n < 1500
    then "len 61-1499"
    else "len 1500 (max)"
  ;;
end

let%expect_test "constrained random loopback with scoreboard and coverage" =
  let rng = Random.State.make [| 10 |] in
  let cov = Coverage.create () in
  let frames = ref 0 in
  let holes () = List.filter Coverage.bins ~f:(fun b -> Hashtbl.find_exn cov b = 0) in
  let scenario = ref 0 in
  (* Coverage-driven: at least 30 scenarios, then keep going until every bin is hit. *)
  while !scenario < 30 || ((not (List.is_empty (holes ()))) && !scenario < 200) do
    incr scenario;
    let scenario = !scenario in
    let ppm = List.random_element_exn ~random_state:rng [ -100; 0; 100 ] in
    let jitter = List.random_element_exn ~random_state:rng [ 0; 4; 8 ] in
    let echo = Random.State.bool rng in
    let w =
      World.create
        ~ppm
        ~jitter_ns:(Float.of_int jitter)
        ~phase:(Random.State.float rng 1.)
        ~seed:scenario
        ()
    in
    Coverage.hit cov (sprintf "ppm %s" (if ppm > 0 then "+100" else Int.to_string ppm));
    Coverage.hit cov (sprintf "jitter %d ns" jitter);
    let expect_b = Queue.create () and expect_a = Queue.create () in
    if echo
    then
      w.b.on_rx
      <- (fun f ->
           if status_bit f.status Eth_core.Status.crc_ok
           then (
             let data = List.take f.bytes (List.length f.bytes - 4) in
             Node.send w.b data;
             Queue.enqueue expect_a data;
             Coverage.hit cov "B->A (echo)"));
    (* Sometimes B has its own traffic from the start, so both sides contend. *)
    if Random.State.int rng 10 < 3
    then
      for _ = 1 to Random.State.int_incl rng 1 2 do
        let p = gen_payload rng (gen_length rng) in
        Node.send w.b p;
        Queue.enqueue expect_a p;
        Coverage.hit cov "B->A (contending)"
      done;
    let n = Random.State.int_incl rng 1 4 in
    for k = 1 to n do
      let p = gen_payload rng (gen_length rng) in
      Node.send w.a p;
      Queue.enqueue expect_b p;
      Coverage.hit cov (Coverage.length_bin (List.length p));
      Coverage.hit cov "A->B";
      if k > 1 then Coverage.hit cov "back-to-back"
    done;
    let good (n : Node.t) =
      Queue.count n.rx_frames ~f:(fun f -> status_bit f.status Eth_core.Status.crc_ok)
    in
    World.run_until w ~f:(fun w ->
      good w.b >= Queue.length expect_b
      && good w.a >= Queue.length expect_a
      && Node.tx_idle w.a
      && Node.tx_idle w.b);
    let check (node : Node.t) expected =
      (* Frames that collided are dropped from the scoreboard: bad CRC, not expected. *)
      let good = Queue.filter node.rx_frames ~f:(fun f -> status_bit f.status Eth_core.Status.crc_ok) in
      let got = Queue.to_list good |> List.map ~f:(fun f -> f.bytes) in
      let exp = Queue.to_list expected |> List.map ~f:Reference.frame in
      if not ([%equal: int list list] got exp)
      then (
        let summary l = List.map l ~f:List.length in
        let bad = Queue.count node.rx_frames ~f:(fun f -> not (status_bit f.status Eth_core.Status.crc_ok)) in
        raise_s
          [%message
            "scoreboard mismatch"
              (scenario : int)
              (ppm : int)
              (jitter : int)
              ~got:(summary got : int list)
              ~expected:(summary exp : int list)
              (bad : int)]);
      frames := !frames + List.length got
    in
    check w.b expect_b;
    check w.a expect_a;
    if w.a.collisions + w.b.collisions > 0 then Coverage.hit cov "collision + backoff"
  done;
  printf "%d scenarios, %d frames checked, 0 mismatches\n\n" !scenario !frames;
  List.iter Coverage.bins ~f:(fun b -> printf "%-22s %4d\n" b (Hashtbl.find_exn cov b));
  let holes = holes () in
  if not (List.is_empty holes) then raise_s [%message "coverage holes" (holes : string list)];
  [%expect {|
    36 scenarios, 152 frames checked, 0 mismatches

    len 1-45 (padded)        16
    len 46-59 (padded)       13
    len 60 (no pad)           2
    len 61-1499              56
    len 1500 (max)            1
    ppm -100                 12
    ppm 0                    10
    ppm +100                 14
    jitter 0 ns              19
    jitter 4 ns               9
    jitter 8 ns               8
    A->B                     88
    B->A (echo)              41
    B->A (contending)        23
    back-to-back             52
    collision + backoff      13
    |}]
;;
