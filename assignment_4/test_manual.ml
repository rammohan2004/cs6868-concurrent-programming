
(** Manual tests for fiber-level Mutex / Condition / Semaphore / Barrier.

    Each test function returns [(ok, msg)] — [ok] is pass/fail, [msg]
    is a short description printed in the report.  Most tests run
    their fibers inside [Sched.run (fun () -> ...)]; remember that the
    scheduler is cooperative unicore, so you'll want [Sched.yield] to
    force interleavings. *)

open Golike_unicore_select

let passed = ref 0
let failed = ref 0

let report name ok msg =
  if ok then begin
    incr passed;
    Printf.printf "[ PASS ] %s — %s\n%!" name msg
  end else begin
    incr failed;
    Printf.printf "[ FAIL ] %s — %s\n%!" name msg
  end

let run_test name f =
  try
    let ok, msg = f () in
    report name ok msg
  with e ->
    incr failed;
    Printf.printf "[ EXN  ] %s — %s\n%!" name (Printexc.to_string e)

(** Test [try_lock] / [unlock] on a single mutex, sequentially. *)
let test_mutex_basic () = 
  let m = Mutex.create () in
  
  let step1 = Mutex.try_lock m in
  let step2 = not (Mutex.try_lock m) in
  Mutex.unlock m;
  let step3 = Mutex.try_lock m in
  let step4 = not (Mutex.try_lock m) in
  Mutex.unlock m;
  let step5 = Mutex.try_lock m in
  

  if not step1 then 
    (false, "Step 1 failed: try_lock failed on fresh mutex")
  else if not step2 then 
    (false, "Step 2 failed: try_lock succeeded on a locked mutex")
  else if not step3 then 
    (false, "Step 3 failed: try_lock failed after first unlock")
  else if not step4 then 
    (false, "Step 4 failed: try_lock succeeded on locked mutex (Round 2)")
  else if not step5 then 
    (false, "Step 5 failed: try_lock failed after second unlock")
  else 
    (true, "All 5 sequential try_lock/unlock steps passed!")

(** Test that blocked waiters are served in FIFO order. *)
let test_mutex_fifo () = 
  let m = Mutex.create () in
  let order = ref "" in

  Sched.run (fun () ->
    Mutex.lock m;
    Sched.fork (fun () ->
      Mutex.lock m;
      order := !order ^ "A";
      Mutex.unlock m
    );

    Sched.fork (fun () ->
      Mutex.lock m;
      order := !order ^ "B";
      Mutex.unlock m
    );

    Sched.fork (fun () ->
      Mutex.lock m;
      order := !order ^ "C";
      Mutex.unlock m
    );

    Mutex.unlock m;

    Sched.yield ()
  );

  if !order = "ABC" then
    (true, "Strict FIFO order verified")
  else
    (false, Printf.sprintf "FIFO failed: expected 'ABC', got '%s'" !order)




(** The [Bounded_buffer] module below is PROVIDED — a classic
    Mutex + two-condvar implementation of a bounded FIFO queue.
    Do not modify it; use it in [test_bounded_buffer]. *)

module Bounded_buffer = struct
  type 'a t = {
    m : Mutex.t;
    not_empty : Condition.t;
    not_full : Condition.t;
    buf : 'a Queue.t;
    capacity : int;
  }
  let create capacity = {
    m = Mutex.create ();
    not_empty = Condition.create ();
    not_full = Condition.create ();
    buf = Queue.create ();
    capacity;
  }
  let put b x =
    Mutex.lock b.m;
    while Queue.length b.buf = b.capacity do
      Condition.wait b.not_full b.m
    done;
    Queue.push x b.buf;
    Condition.signal b.not_empty;
    Mutex.unlock b.m
  let get b =
    Mutex.lock b.m;
    while Queue.is_empty b.buf do
      Condition.wait b.not_empty b.m
    done;
    let x = Queue.pop b.buf in
    Condition.signal b.not_full;
    Mutex.unlock b.m;
    x
end

(** Test bounded-buffer throughput — no items lost, no duplicates,
    under multiple concurrent producers and consumers. *)
let test_bounded_buffer () = 
  let b = Bounded_buffer.create 5 in
  let count = ref 0 in
  let sum = ref 0 in

  Sched.run (fun () ->
    
    let spawn_consumer () =
      Sched.fork (fun () ->
        for _ = 1 to 50 do
          let v = Bounded_buffer.get b in
          sum := !sum + v;
          count := !count + 1
        done
      )
    in
    
    spawn_consumer ();
    spawn_consumer ();

    Sched.fork (fun () ->
      for i = 1 to 50 do
        Bounded_buffer.put b i
      done
    );

    Sched.fork (fun () ->
      for i = 51 to 100 do
        Bounded_buffer.put b i
      done
    )
    
  );

  if !count <> 100 then
    (false, Printf.sprintf "Lost items: expected 100, got %d" !count)
  else if !sum <> 5050 then
    (false, Printf.sprintf "Duplicates: expected sum 5050, got %d" !sum)
  else
    (true, "Multiple producers and consumers processed 100 items correctly")

(** The [Rw_lock] module below is PROVIDED — writer-priority R/W lock.
    Do not modify it; use it in [test_readers_writers]. *)

module Rw_lock = struct
  type t = {
    m : Mutex.t;
    can_read : Condition.t;
    can_write : Condition.t;
    mutable readers : int;
    mutable writer : bool;
    mutable waiting_writers : int;
  }
  let create () = {
    m = Mutex.create ();
    can_read = Condition.create ();
    can_write = Condition.create ();
    readers = 0; writer = false; waiting_writers = 0;
  }
  let read_lock r =
    Mutex.lock r.m;
    while r.writer || r.waiting_writers > 0 do
      Condition.wait r.can_read r.m
    done;
    r.readers <- r.readers + 1;
    Mutex.unlock r.m
  let read_unlock r =
    Mutex.lock r.m;
    r.readers <- r.readers - 1;
    if r.readers = 0 then Condition.signal r.can_write;
    Mutex.unlock r.m
  let write_lock r =
    Mutex.lock r.m;
    r.waiting_writers <- r.waiting_writers + 1;
    while r.writer || r.readers > 0 do
      Condition.wait r.can_write r.m
    done;
    r.waiting_writers <- r.waiting_writers - 1;
    r.writer <- true;
    Mutex.unlock r.m
  let write_unlock r =
    Mutex.lock r.m;
    r.writer <- false;
    if r.waiting_writers > 0 then Condition.signal r.can_write
    else Condition.broadcast r.can_read;
    Mutex.unlock r.m
end

(** Test the R/W exclusion invariants: at most one writer,
    readers and writers never coexist. *)
let test_readers_writers () = 
  let rw = Rw_lock.create () in
  let active_readers = ref 0 in
  let active_writers = ref 0 in
  let violation = ref false in

  let check () =
    if !active_writers > 1 then violation := true;
    if !active_writers > 0 && !active_readers > 0 then violation := true
  in


  Sched.run (fun () ->
    
    let spawn_reader () =
      Sched.fork (fun () ->
        for _ = 1 to 5 do
          Rw_lock.read_lock rw;
          active_readers := !active_readers + 1;
          check ();
          Sched.yield (); 
          check ();
          active_readers := !active_readers - 1;
          Rw_lock.read_unlock rw;
          Sched.yield () 
        done
      )
    in

    let spawn_writer () =
      Sched.fork (fun () ->
        for _ = 1 to 5 do
          Rw_lock.write_lock rw;
          active_writers := !active_writers + 1;
          check ();
          Sched.yield (); 
          check ();
          active_writers := !active_writers - 1;
          Rw_lock.write_unlock rw;
          Sched.yield () 
        done
      )
    in

    spawn_reader ();
    spawn_writer ();
    spawn_reader ();
    spawn_writer ();
    spawn_reader ();
    spawn_writer ();
    spawn_writer ();
    spawn_reader ();
    spawn_writer ();
    spawn_reader ();
  );

  if !violation then
    (false, "Exclusion failed: Readers and writers overlapped, or multiple writers found")
  else
    (true, "R/W invariants held")

(** Test reusable N-party barrier: no fiber is more than one round
    ahead of any other across multiple barrier crossings. *)
let test_barrier () = 
  let n = 3 in
  let rounds = 3 in
  let b = Barrier.create n in
  
  let counters = Array.make n 0 in
  let violation = ref false in

  Sched.run (fun () ->
    
    for id = 0 to n - 1 do
      Sched.fork (fun () ->
        for r = 1 to rounds do
          counters.(id) <- r;
          for j = 0 to n - 1 do
            if counters.(id) - counters.(j) > 1 then
              violation := true
          done;
          Barrier.wait b;
          Sched.yield ()
        done
        
      )
    done
  );

  
  if !violation then
    (false, "Barrier Failed")
  else if counters.(0) <> rounds || counters.(1) <> rounds || counters.(2) <> rounds then
    (false, "Not all fibers completed all their rounds")
  else
    (true, "Barrier worked perfectly")

(** Test that a semaphore with [k] permits never allows more than
    [k] fibers in the critical section simultaneously. *)
let test_semaphore () = 
  let k = 3 in
  let sem = Semaphore.create k in
  let active_fibers = ref 0 in
  let violation = ref false in

  Sched.run (fun () ->
    for _ = 1 to 10 do
      Sched.fork (fun () ->
        Semaphore.acquire sem;
        active_fibers := !active_fibers + 1;
        if !active_fibers > k then violation := true;
        Sched.yield ();
        if !active_fibers > k then violation := true;
        active_fibers := !active_fibers - 1;
        Semaphore.release sem
      )
    done
  );

  if !violation then
    (false, Printf.sprintf "More than %d fibers entered at once!" k)
  else if !active_fibers <> 0 then
    (false, "Active fibers count did not return to 0")
  else
    (true, "Semaphore worked perfectly")

(** Test that [Select.select] picks an already-free mutex in phase 1
    (the fast path). *)
let test_lock_evt_fastpath () = 
  let m = Mutex.create () in
  let evt = Mutex.lock_evt m in
  let finished = ref false in

  Sched.run (fun () ->
    Select.select [evt];
    finished := true
  );

  if not !finished then
    (false, "select suspended the fiber instead of taking the fast path")
  else if Mutex.try_lock m then
    (false, "select completed but did not actually lock the mutex")
  else begin
    Mutex.unlock m;
    (true, "Select grabbed the free mutex instantly via the fast path")
  end

(** Test [Select.select] over two held mutexes — it should block until
    one is unlocked, then take that case; stale waiter on the other
    mutex must be tolerated. *)
let test_lock_evt_blocking () = 
  let m1 = Mutex.create () in
  let m2 = Mutex.create () in
  let result = ref "" in

  Sched.run (fun () ->
    Mutex.lock m1;
    Mutex.lock m2;
    Sched.fork (fun () ->
      let ev1 = Select.wrap (fun () -> "M1") (Mutex.lock_evt m1) in
      let ev2 = Select.wrap (fun () -> "M2") (Mutex.lock_evt m2) in
      let winner = Select.select [ev1; ev2] in
      result := winner;
      if winner = "M1" then Mutex.unlock m1
      else Mutex.unlock m2
    );

    Mutex.unlock m2;
    Sched.yield ();
    Mutex.unlock m1;
    Sched.yield ()
  );

  if !result <> "M2" then
    (false, Printf.sprintf "Select failed to pick/block the unlocked mutex (got '%s')" !result)
  else if not (Mutex.try_lock m1) then
    (false, "Stale waiter caused m1 to remain locked or broke its state")
  else if not (Mutex.try_lock m2) then
    (false, "Select won m2, but did not cleanly release it")
  else begin
    Mutex.unlock m1; Mutex.unlock m2; 
    (true, "Select Phase 2 blocked correctly, picked M2, and tolerated the stale M1 waiter")
  end

(** Test the load-balancer pattern from Lecture 10's [_scratch/test1.ml]:
    many clients race to claim any of several slot mutexes via
    [Select.select] over [lock_evt]. *)
let test_load_balancer () = 
  let slots = Array.init 3 (fun _ -> Mutex.create ()) in
  let b = Barrier.create 4 in
  let success = ref false in
  Sched.run (fun () ->
    for _ = 1 to 3 do
      Sched.fork (fun () ->
        let evts = [
          Select.wrap (fun () -> slots.(0)) (Mutex.lock_evt slots.(0));
          Select.wrap (fun () -> slots.(1)) (Mutex.lock_evt slots.(1));
          Select.wrap (fun () -> slots.(2)) (Mutex.lock_evt slots.(2));
        ] in
        
        let won_mutex = Select.select evts in
        Barrier.wait b; 
        
        Mutex.unlock won_mutex
      )
    done;

    Barrier.wait b;

    let slot0_free = Mutex.try_lock slots.(0) in
    let slot1_free = Mutex.try_lock slots.(1) in
    let slot2_free = Mutex.try_lock slots.(2) in

    if not slot0_free && not slot1_free && not slot2_free then
      success := true
    
    else begin
      if slot0_free then Mutex.unlock slots.(0);
      if slot1_free then Mutex.unlock slots.(1);
      if slot2_free then Mutex.unlock slots.(2);
    end
  );

  if !success then
    (true, "Select perfectly routed 3 workers to 3 distinct slots concurrently")
  else
    (false, "Deadlock or bad routing: A slot was left empty!")

(** Test that [Condition.wait] re-acquires the mutex before returning
    (POSIX semantics). *)
let test_wait_reacquires () = 
  let m = Mutex.create () in
  let c = Condition.create () in
  let violation = ref true in

  Sched.run (fun () ->
    Sched.fork (fun () ->
      Mutex.lock m;
      Condition.wait c m;
      Sched.yield ();
      Mutex.unlock m
    );

    Mutex.lock m;
    Condition.signal c;
    Mutex.unlock m; 
    
    Sched.yield ();
    violation := Mutex.try_lock m;
    if !violation then Mutex.unlock m
  );

  if !violation then
    (false, "Condition.wait returned without locking the mutex")
  else
    (true, "Condition.wait successfully reacquired the mutex")


let () =
  Printf.printf "=== Manual tests (fiber-level Mutex/Cond/Sem/Bar) ===\n%!";
  run_test "mutex_basic"           test_mutex_basic;
  run_test "mutex_fifo"            test_mutex_fifo;
  run_test "bounded_buffer"        test_bounded_buffer;
  run_test "readers_writers"       test_readers_writers;
  run_test "barrier"               test_barrier;
  run_test "semaphore"             test_semaphore;
  run_test "lock_evt_fastpath"     test_lock_evt_fastpath;
  run_test "lock_evt_blocking"     test_lock_evt_blocking;
  run_test "load_balancer"         test_load_balancer;
  run_test "wait_reacquires"       test_wait_reacquires;
  Printf.printf "\n%d passed, %d failed\n%!" !passed !failed;
  if !failed > 0 then exit 1