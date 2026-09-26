(* Simulation harness. A [Node] is one TinyTapeout tile plus a host model that speaks
   the pin protocol. A [Cable] carries a node's TD+/TD- to the other node's RD with
   delay and random edge jitter. [World] steps two nodes on independent clocks
   (different frequency and phase) in continuous time, femtosecond resolution. *)

open! Core
open Hardcaml
open Eth10t

module Sim_i = Tt_top.I_rd_fall
module Sim = Cyclesim.With_interface (Sim_i) (Tt_top.O_rd_fall)

let status_bit s b = (s lsr b) land 1 = 1

type rx_frame =
  { bytes : int list
  ; status : int
  }

module Node = struct
  type tx_state =
    | Ready
    | Sending of
        { payload : int array
        ; mutable k : int
        ; mutable busy_seen : bool
        }
    | Draining

  type tx_result =
    | Sent
    | Aborted of int (* status byte *)

  type t =
    { sim : Sim.t
    ; i : Bits.t ref Sim_i.t
    ; o : Bits.t ref Tt_top.O_rd_fall.t
    ; mutable cycle : int
    ; mutable tx : tx_state
    ; tx_queue : int list Queue.t
    ; tx_results : tx_result Queue.t
    ; mutable rx_bytes : int list
    ; rx_frames : rx_frame Queue.t
    ; mutable prev_uio : int
    ; mutable status : int
    ; mutable retry : (int list * int) option
    ; mutable backoff_until : int
    ; mutable collisions : int
    ; mutable on_rx : rx_frame -> unit
    ; rng : Random.State.t
    }

  let create ?(cfg = Config.default) ?(trace = false) ?(seed = 0) () =
    let config = if trace then Cyclesim.Config.trace_all else Cyclesim.Config.default in
    let sim = Sim.create ~config (Tt_top.create_rd_fall ~cfg) in
    let i = Cyclesim.inputs sim in
    let o = Cyclesim.outputs sim in
    i.rst_n := Bits.gnd;
    i.ena := Bits.vdd;
    for _ = 1 to 4 do
      Cyclesim.cycle sim
    done;
    i.rst_n := Bits.vdd;
    { sim
    ; i
    ; o
    ; cycle = 0
    ; tx = Ready
    ; tx_queue = Queue.create ()
    ; tx_results = Queue.create ()
    ; rx_bytes = []
    ; rx_frames = Queue.create ()
    ; prev_uio = 0
    ; status = 0
    ; retry = None
    ; backoff_until = 0
    ; collisions = 0
    ; on_rx = (fun _ -> ())
    ; rng = Random.State.make [| seed |]
    }
  ;;

  let send t payload =
    assert (not (List.is_empty payload));
    Queue.enqueue t.tx_queue payload
  ;;

  let uio t = Bits.to_int !(t.o.uio_out)
  let td_p t = uio t land 1 = 1
  let td_n t = uio t land 2 = 2
  let link_up t = uio t land 0x80 <> 0
  let busy t = status_bit t.status Eth_core.Status.tx_busy

  let tx_idle t =
    (match t.tx with
     | Ready -> true
     | _ -> false)
    && Option.is_none t.retry
    && Queue.is_empty t.tx_queue
  ;;

  let set_uio_in t ~mask v =
    let u = Bits.to_int !(t.i.uio_in) land lnot mask in
    t.i.uio_in := Bits.of_int ~width:8 (u lor if v then mask else 0)
  ;;

  (* [fall] is the line half a clock before [rise]. *)
  let set_rd t ~rise ~fall =
    set_uio_in t ~mask:0b100 rise;
    t.i.rd_fall := Bits.of_bool fall
  ;;

  let slot_cycles = 512 * 6 (* 51.2 us *)

  let drive t =
    (match t.tx with
     | Ready when t.cycle >= t.backoff_until ->
       let next =
         match t.retry with
         | Some (p, _) -> Some p
         | None -> Queue.dequeue t.tx_queue |> Option.map ~f:(fun p -> t.retry <- Some (p, 0); p)
       in
       Option.iter next ~f:(fun p ->
         t.tx <- Sending { payload = Array.of_list p; k = 0; busy_seen = false })
     | _ -> ());
    let tx_valid, byte =
      match t.tx with
      | Sending s -> true, s.payload.(s.k)
      | _ -> false, 0
    in
    t.i.ui_in := Bits.of_int ~width:8 byte;
    set_uio_in t ~mask:0b1000 tx_valid
  ;;

  (* Truncated binary exponential backoff, as a host MAC would do it. *)
  let finish t =
    let collided = status_bit t.status Eth_core.Status.collision in
    let jabbered = status_bit t.status Eth_core.Status.jabber in
    t.tx <- Ready;
    (* tx_valid must be seen low (through the 2-flop synchroniser) between frames. *)
    t.backoff_until <- t.cycle + 4;
    match t.retry with
    | Some (p, n) when collided && n < 15 ->
      t.collisions <- t.collisions + 1;
      let k = Random.State.int t.rng (1 lsl Int.min (n + 1) 10) in
      t.backoff_until <- t.cycle + 4 + (k * slot_cycles);
      t.retry <- Some (p, n + 1);
      Queue.enqueue t.tx_results (Aborted t.status)
    | _ ->
      t.retry <- None;
      Queue.enqueue
        t.tx_results
        (if collided || jabbered then Aborted t.status else Sent)

  (* Host side of the pin protocol: next byte on each tx_ready rise, collect a byte on
     each rx_valid rise, and a frame with its status when rx_frame falls. *)
  let observe t =
    let u = uio t in
    let rose b = u land b <> 0 && t.prev_uio land b = 0 in
    let fell b = u land b = 0 && t.prev_uio land b <> 0 in
    let uo = Bits.to_int !(t.o.uo_out) in
    let status_visible = u land 0x40 = 0 in
    if status_visible then t.status <- uo;
    (match t.tx with
     | Sending s ->
       if busy t then s.busy_seen <- true;
       if rose 0x10
       then if s.k + 1 >= Array.length s.payload then t.tx <- Draining else s.k <- s.k + 1
       else if s.busy_seen && status_visible && not (busy t)
       then finish t
     | Draining when status_visible && not (busy t) -> finish t
     | _ -> ());
    if rose 0x20 then t.rx_bytes <- uo :: t.rx_bytes;
    if fell 0x40
    then (
      let f = { bytes = List.rev t.rx_bytes; status = uo } in
      Queue.enqueue t.rx_frames f;
      t.rx_bytes <- [];
      t.on_rx f);
    t.prev_uio <- u
  ;;

  let step t =
    drive t;
    Cyclesim.cycle t.sim;
    t.cycle <- t.cycle + 1;
    if not (Bits.to_bool !(t.o.invariant)) then failwithf "invariant violated at cycle %d" t.cycle ();
    observe t
  ;;
end

module Cable = struct
  type t =
    { q : (int * bool) Queue.t
    ; mutable level : bool
    ; mutable last_in : bool
    ; mutable last_time : int
    ; delay_fs : int
    ; jitter_fs : int
    ; rng : Random.State.t
    ; mutable glitch : (int * int) option
    ; mutable cut : bool
    }

  let create ?(delay_fs = 500_000_000) ?(jitter_fs = 0) ~seed () =
    { q = Queue.create ()
    ; level = false
    ; last_in = false
    ; last_time = 0
    ; delay_fs
    ; jitter_fs
    ; rng = Random.State.make [| seed |]
    ; glitch = None
    ; cut = false
    }
  ;;

  (* Receiver comparator: positive differential reads as 1. *)
  let push t ~time ~td_p ~td_n =
    let v = td_p && not td_n in
    if Bool.( <> ) v t.last_in
    then (
      t.last_in <- v;
      let j =
        if t.jitter_fs = 0
        then 0
        else Random.State.int_incl t.rng (-t.jitter_fs) t.jitter_fs
      in
      let at = Int.max (t.last_time + 1) (time + t.delay_fs + j) in
      t.last_time <- at;
      Queue.enqueue t.q (at, v))
  ;;

  (* Destructive: call with non-decreasing [time]. *)
  let sample t ~time =
    let rec pop () =
      match Queue.peek t.q with
      | Some (at, v) when at <= time ->
        ignore (Queue.dequeue t.q : _ option);
        t.level <- v;
        pop ()
      | _ -> ()
    in
    pop ();
    match t.glitch with
    | _ when t.cut -> false
    | Some (a, b) when time >= a && time < b -> not t.level
    | _ -> t.level
  ;;
end

module World = struct
  type t =
    { a : Node.t
    ; b : Node.t
    ; ab : Cable.t
    ; ba : Cable.t
    ; period_a : int
    ; period_b : int
    ; mutable next_a : int
    ; mutable next_b : int
    }

  let nominal_period_fs (cfg : Config.t) = 1_000_000_000_000_000 / Config.clock_hz cfg

  let create ?(cfg = Config.default) ?(ppm = 0) ?(phase = 0.37) ?(jitter_ns = 0.) ?(seed = 1) () =
    let p = nominal_period_fs cfg in
    let jitter_fs = Float.to_int (jitter_ns *. 1e6) in
    { a = Node.create ~cfg ~seed:(2 * seed) ()
    ; b = Node.create ~cfg ~seed:((2 * seed) + 1) ()
    ; ab = Cable.create ~jitter_fs ~seed ()
    ; ba = Cable.create ~jitter_fs ~seed:(seed + 1) ()
    ; period_a = p
    ; period_b = p + (p * ppm / 1_000_000)
    ; next_a = 0
    ; next_b = Float.to_int (phase *. Float.of_int p)
    }
  ;;

  let step t =
    if t.next_a <= t.next_b
    then (
      let time = t.next_a in
      let fall = Cable.sample t.ba ~time:(time - (t.period_a / 2)) in
      let rise = Cable.sample t.ba ~time in
      Node.set_rd t.a ~rise ~fall;
      Node.step t.a;
      Cable.push t.ab ~time ~td_p:(Node.td_p t.a) ~td_n:(Node.td_n t.a);
      t.next_a <- time + t.period_a)
    else (
      let time = t.next_b in
      let fall = Cable.sample t.ab ~time:(time - (t.period_b / 2)) in
      let rise = Cable.sample t.ab ~time in
      Node.set_rd t.b ~rise ~fall;
      Node.step t.b;
      Cable.push t.ba ~time ~td_p:(Node.td_p t.b) ~td_n:(Node.td_n t.b);
      t.next_b <- time + t.period_b)
  ;;

  let now t = Int.min t.next_a t.next_b

  let run_until ?(max_cycles = 20_000_000) t ~f =
    let limit = t.a.cycle + max_cycles in
    while (not (f t)) && t.a.cycle < limit do
      step t
    done;
    if not (f t) then failwith "World.run_until: timeout"
  ;;

  let run_cycles t n =
    let limit = t.a.cycle + n in
    while t.a.cycle < limit do
      step t
    done
  ;;
end
