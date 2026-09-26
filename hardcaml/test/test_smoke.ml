open! Core
open Harness

let%expect_test "one frame A -> B" =
  let w = World.create () in
  let payload = List.init 20 ~f:(fun i -> i) in
  Node.send w.a payload;
  World.run_until w ~f:(fun w -> not (Queue.is_empty w.b.rx_frames));
  let f = Queue.dequeue_exn w.b.rx_frames in
  printf
    "match=%b len=%d crc_ok=%b\n"
    ([%equal: int list] f.bytes (Reference.frame payload))
    (List.length f.bytes)
    (status_bit f.status Eth10t.Eth_core.Status.crc_ok);
  [%expect {| match=true len=64 crc_ok=true |}]
;;
