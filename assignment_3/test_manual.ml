(** Manual concurrent tests for Batch Bounded Blocking Queue *)

let printf = Printf.printf

let assert_array_eq a b msg =
  if a <> b then begin
    printf "FAIL: %s\n  expected: [|%s|]\n  got:      [|%s|]\n" msg
      (Array.to_list a |> List.map string_of_int |> String.concat "; ")
      (Array.to_list b |> List.map string_of_int |> String.concat "; ");
    exit 1
  end

let assert_int_eq a b msg =
  if a <> b then begin
    printf "FAIL: %s\n  expected: %d\n  got: %d\n" msg a b;
    exit 1
  end

let assert_bool_eq expected actual msg =
  if expected <> actual then begin
    printf "FAIL: %s\n  expected: %b\n  got: %b\n" msg expected actual;
    exit 1
  end

let assert_raises_invalid_arg f msg =
  try
    ignore (f ());
    printf "FAIL: %s\n  expected Invalid_argument exception, but none was raised.\n" msg;
    exit 1
  with
  | Invalid_argument _ -> () (* Test passed! *)
  | e -> 
      printf "FAIL: %s\n  expected Invalid_argument, but got %s\n" msg (Printexc.to_string e);
      exit 1

(* Test create, enq, deq, size, capacity in a single thread. *)
let test_sequential_basic () = 
  printf "Running test_sequential_basic...\n";
  
  let q = BatchQueue.create 5 in
  
  assert_int_eq 5 (BatchQueue.capacity q) "initial capacity";
  assert_int_eq 0 (BatchQueue.size q) "initial size";
  assert (BatchQueue.try_deq q 1 = None); 


  assert_bool_eq true (BatchQueue.try_enq q [|10; 20; 30|]) "try_enq 3 items";
  assert_int_eq 3 (BatchQueue.size q) "size after try_enq 3";

  BatchQueue.enq q [|40; 50|];
  assert_int_eq 5 (BatchQueue.size q) "size after enq 2 (queue exactly full)";

  assert_bool_eq false (BatchQueue.try_enq q [|60|]) "try_enq 1 item when full";
  assert_int_eq 5 (BatchQueue.size q) "size remains 5 after failed try_enq";

  let res_full = BatchQueue.deq q 5 in
  assert_array_eq [|10; 20; 30; 40; 50|] res_full "deq exactly 5 items";
  assert_int_eq 0 (BatchQueue.size q) "size after emptying";

  BatchQueue.enq q [|1; 2|];
  assert_bool_eq true (BatchQueue.try_enq q [|3; 4; 5|]) "try_enq fill back to 5";
  
  let res_partial = BatchQueue.try_deq q 2 in
  (match res_partial with
   | Some arr -> assert_array_eq [|1; 2|] arr "try_deq 2 items"
   | None -> failwith "FAIL: try_deq returned None unexpectedly");
  assert_int_eq 3 (BatchQueue.size q) "size after try_deq 2";

  assert (BatchQueue.try_deq q 4 = None);
  assert_int_eq 3 (BatchQueue.size q) "size remains 3 after failed try_deq";

  let res_rest = BatchQueue.deq q 3 in
  assert_array_eq [|3; 4; 5|] res_rest "deq remaining 3";
  assert_int_eq 0 (BatchQueue.size q) "final size is 0";

  printf " ✓ Passed\n"

(** Test that invalid arguments raise [Invalid_argument]. *)
let test_error_handling () =
  printf "Running test_error_handling...\n";
  
  (* 1. Test create bounds *)
  assert_raises_invalid_arg (fun () -> BatchQueue.create 0) "create with capacity zero";
  assert_raises_invalid_arg (fun () -> BatchQueue.create (-5)) "create with negative capacity";
  
  let q = BatchQueue.create 5 in
  
  assert_raises_invalid_arg (fun () -> BatchQueue.enq q [||]) "enq empty array";
  assert_raises_invalid_arg (fun () -> BatchQueue.enq q [|1; 2; 3; 4; 5; 6|]) "enq items greater than capacity";
  
  assert_raises_invalid_arg (fun () -> BatchQueue.deq q 0) "deq zero items";
  assert_raises_invalid_arg (fun () -> BatchQueue.deq q (-1)) "deq negative items";
  assert_raises_invalid_arg (fun () -> BatchQueue.deq q 6) "deq items greater than capacity";
  
  assert_raises_invalid_arg (fun () -> BatchQueue.try_enq q [||]) "try_enq empty array";
  assert_raises_invalid_arg (fun () -> BatchQueue.try_enq q [|1; 2; 3; 4; 5; 6|]) "try_enq items greater than capacity";
  
  assert_raises_invalid_arg (fun () -> BatchQueue.try_deq q 0) "try_deq zero items";
  assert_raises_invalid_arg (fun () -> BatchQueue.try_deq q (-1)) "try_deq negative items";
  assert_raises_invalid_arg (fun () -> BatchQueue.try_deq q 6) "try_deq items greater than capacity";
  
  printf " ✓ Passed\n"

(** Test that deq blocks until items arrive (and/or enq blocks until space frees). *)
let test_blocking_enq_deq () = 
  printf "Running test_blocking_enq_deq...\n%!";
  let q = BatchQueue.create 5 in

  let deq_completed = Atomic.make false in
  
  let d1 = Domain.spawn (fun () ->
    ignore (BatchQueue.deq q 3);
    Atomic.set deq_completed true
  ) in

  Unix.sleepf 0.1;
  let deq_blocked_correctly = not (Atomic.get deq_completed) in

  BatchQueue.enq q [|1; 2; 3|];
  Domain.join d1;


  BatchQueue.enq q [|10; 20; 30; 40; 50|];
  
  let enq_completed = Atomic.make false in
  let d2 = Domain.spawn (fun () ->
    BatchQueue.enq q [|6; 7|];
    Atomic.set enq_completed true
  ) in

  Unix.sleepf 0.1;
  let enq_blocked_correctly = not (Atomic.get enq_completed) in

  ignore (BatchQueue.deq q 2);
  Domain.join d2;

  let final_size = BatchQueue.size q in

  if deq_blocked_correctly && enq_blocked_correctly && final_size = 5 then 
    printf " ✓ Passed : deq and enq blocked correctly. Final size: %d\n%!" final_size
  else begin
    printf " ✗ FAILED : Blocking logic failed (deq blocked: %b, enq blocked: %b, final size: %d)\n%!" 
      deq_blocked_correctly enq_blocked_correctly final_size;
    exit 1
  end 

(** Test that a single producer/consumer pair sees items in FIFO order. *)
let test_fifo_single_producer_consumer () = 
  printf "Running test_fifo_single_producer_consumer...\n%!";
  let q = BatchQueue.create 10 in
  let total_items = 100 in
  let passed = Atomic.make true in

  let producer () =
    let i = ref 1 in
    while !i <= total_items do
      let batch_size = min 3 (total_items - !i + 1) in
      let arr = Array.init batch_size (fun j -> !i + j) in
      BatchQueue.enq q arr;
      i := !i + batch_size
    done
  in

  let consumer () =
    let expected = ref 1 in
    while !expected <= total_items do
      let batch_size = min 4 (total_items - !expected + 1) in
      let arr = BatchQueue.deq q batch_size in
      for j = 0 to Array.length arr - 1 do
        if arr.(j) <> !expected then Atomic.set passed false;
        expected := !expected + 1
      done
    done
  in

  let p = Domain.spawn producer in
  let c = Domain.spawn consumer in

  Domain.join p;
  Domain.join c;

  if Atomic.get passed && BatchQueue.size q = 0 then
    Printf.printf " ✓ Passed : FIFO order maintained.\n%!"
  else begin
    Printf.printf " ✗ FAILED : Items received out of order or queue not empty.\n%!";
    exit 1
  end

(** Test dequeuer head-of-line blocking: deq(5) arrives before deq(2);
    even when 6 items are enqueued, deq(5) must be served first. *)
let test_dequeuer_head_of_line_blocking () = 
  printf "Running test_dequeuer_head_of_line_blocking...\n%!";
  let q = BatchQueue.create 10 in

  let d1_completed = Atomic.make false in
  let d2_completed = Atomic.make false in

  let d1 = Domain.spawn (fun () ->
    let res = BatchQueue.deq q 5 in
    assert_array_eq [|1; 2; 3; 4; 5|] res "d1 gets first 5";
    Atomic.set d1_completed true
  ) in

  Unix.sleepf 0.1; 

  let d2 = Domain.spawn (fun () ->
    let res = BatchQueue.deq q 2 in
    assert_array_eq [|6; 7|] res "d2 gets next 2";
    Atomic.set d2_completed true
  ) in

  Unix.sleepf 0.1;

  BatchQueue.enq q [|1; 2; 3|];
  Unix.sleepf 0.1;

  let d1_blocked_step1 = not (Atomic.get d1_completed) in
  let d2_blocked_step1 = not (Atomic.get d2_completed) in 

  BatchQueue.enq q [|4; 5; 6|];
  Unix.sleepf 0.1;

  let d1_finished_step2 = Atomic.get d1_completed in
  let d2_blocked_step2 = not (Atomic.get d2_completed) in

  BatchQueue.enq q [|7|];
  Domain.join d1;
  Domain.join d2;

  let d2_finished_final = Atomic.get d2_completed in

  if d1_blocked_step1 && d2_blocked_step1 && d1_finished_step2 && d2_blocked_step2 && d2_finished_final then
    printf " ✓ Passed : Head-of-line blocking satisfied.\n%!"
  else begin
    printf " ✗ FAILED : Head-of-line blocking violated.\n";
    exit 1
  end

(** Test enqueuer head-of-line blocking: enq(3) arrives before enq(1);
    freeing 1 slot must NOT let enq(1) jump ahead. *)
let test_enqueuer_head_of_line_blocking () = 
  Printf.printf "Running test_enqueuer_head_of_line_blocking...\n%!";
  let q = BatchQueue.create 5 in
  
  BatchQueue.enq q [|1; 2; 3; 4; 5|];

  let d1_completed = Atomic.make false in
  let d2_completed = Atomic.make false in

  let d1 = Domain.spawn (fun () ->
    BatchQueue.enq q [|10; 20; 30|];
    Atomic.set d1_completed true
  ) in
  Unix.sleepf 0.1; 
  let d2 = Domain.spawn (fun () ->
    BatchQueue.enq q [|40|];
    Atomic.set d2_completed true
  ) in
  Unix.sleepf 0.1; 
  ignore (BatchQueue.deq q 1);
  Unix.sleepf 0.1;

  let d1_blocked_step1 = not (Atomic.get d1_completed) in
  let d2_blocked_step1 = not (Atomic.get d2_completed) in 

  ignore (BatchQueue.deq q 2);
  Unix.sleepf 0.1;
  let d1_finished_step2 = Atomic.get d1_completed in
  let d2_blocked_step2 = not (Atomic.get d2_completed) in
  
  ignore (BatchQueue.deq q 1);
  
  Domain.join d1;
  Domain.join d2;

  let d2_finished_final = Atomic.get d2_completed in

  if d1_blocked_step1 && d2_blocked_step1 && d1_finished_step2 && d2_blocked_step2 && d2_finished_final then
    Printf.printf " ✓ Passed : Head-of-line blocking satisfied.\n%!"
  else begin
    Printf.printf " ✗ FAILED : Head-of-line blocking violated.\n";
    exit 1
  end

(** Test that no items are lost or duplicated under concurrent access. *)
let test_no_lost_items () = 
  Printf.printf "Running test_no_lost_items...\n%!";
  let q = BatchQueue.create 50 in
  let items_per_producer = 1000 in
  let total_items = items_per_producer * 4 in
  let seen = Array.init total_items (fun _ -> Atomic.make false) in
  let duplicate_found = Atomic.make false in

  let producer id () =
    for i = 0 to (items_per_producer / 5) - 1 do
      let arr = Array.init 5 (fun j -> (id * items_per_producer) + (i * 5) + j) in
      BatchQueue.enq q arr
    done
  in

  let consumer () =
    for _ = 1 to (1000 / 2) do 
      let arr = BatchQueue.deq q 2 in
      for j = 0 to Array.length arr - 1 do
        let value = arr.(j) in
        let was_seen = Atomic.exchange seen.(value) true in
        if was_seen then Atomic.set duplicate_found true
      done
    done
  in

  let p1 = Domain.spawn (producer 0) in
  let p2 = Domain.spawn (producer 1) in
  let p3 = Domain.spawn (producer 2) in
  let p4 = Domain.spawn (producer 3) in
  let c1 = Domain.spawn consumer in
  let c2 = Domain.spawn consumer in
  let c3 = Domain.spawn consumer in
  let c4 = Domain.spawn consumer in

  Domain.join p1;
  Domain.join p2;
  Domain.join p3;
  Domain.join p4;
  Domain.join c1;
  Domain.join c2;
  Domain.join c3;
  Domain.join c4;

  let missing_found = ref false in
  for i = 0 to total_items - 1 do
    if not (Atomic.get seen.(i)) then missing_found := true
  done;

  if not !missing_found && not (Atomic.get duplicate_found) && BatchQueue.size q = 0 then
    Printf.printf " ✓ Passed : No items are lost or duplicated \n%!"
  else begin
    Printf.printf " ✗ FAILED : Missing items: %b, Duplicates: %b \n%!" 
      !missing_found (Atomic.get duplicate_found);
    exit 1
  end

(** Test that a batch enqueue is not interleaved with another batch. *)
let test_batch_atomicity () = 
  Printf.printf "Running test_batch_atomicity...\n%!";
  
  let batch_size = 10 in
  let batches_per_producer = 100 in
  let num_producers = 4 in
  let total_items = batch_size * batches_per_producer * num_producers in
  let q = BatchQueue.create total_items in

  let producer id () =
    for _ = 1 to batches_per_producer do
      let arr = Array.make batch_size id in
      BatchQueue.enq q arr
    done
  in

  let p1 = Domain.spawn (producer 1) in
  let p2 = Domain.spawn (producer 2) in
  let p3 = Domain.spawn (producer 3) in
  let p4 = Domain.spawn (producer 4) in

  Domain.join p1;
  Domain.join p2;
  Domain.join p3;
  Domain.join p4;

  let result = BatchQueue.deq q total_items in
  let atomicity_maintained = ref true in

  for i = 0 to (total_items / batch_size) - 1 do
    let chunk_start = i * batch_size in
    let expected_id = result.(chunk_start) in
    for j = 1 to batch_size - 1 do
      if result.(chunk_start + j) <> expected_id then 
        atomicity_maintained := false
    done
  done;

  if !atomicity_maintained && BatchQueue.size q = 0 then
    Printf.printf " ✓ Passed : Batch enqueue is not interleaved with another batch.\n%!"
  else begin
    Printf.printf " ✗ FAILED : Batch interleaving detected.\n%!";
    exit 1
  end


(** Stress test: multiple producers and consumers with many operations. *)
let test_stress () = 
  printf "Running test_stress...\n%!";
  
  let q = BatchQueue.create 30 in
  let batches_per_producer = 2000 in
  let producer_batch_size = 3 in 
  let batches_per_consumer = 1500 in
  let consumer_batch_size = 4 in
  

  let producer () =
    for _ = 1 to batches_per_producer do
      let arr = Array.make producer_batch_size 1 in
      BatchQueue.enq q arr;
      Domain.cpu_relax () 
    done
  in

  let consumer () =
    for _ = 1 to batches_per_consumer do
      ignore (BatchQueue.deq q consumer_batch_size);
      Domain.cpu_relax ()
    done
  in

  let p1 = Domain.spawn producer in
  let p2 = Domain.spawn producer in
  let p3 = Domain.spawn producer in
  let p4 = Domain.spawn producer in
  let c1 = Domain.spawn consumer in
  let c2 = Domain.spawn consumer in
  let c3 = Domain.spawn consumer in
  let c4 = Domain.spawn consumer in

  Domain.join p1;
  Domain.join p2;
  Domain.join p3;
  Domain.join p4;
  Domain.join c1;
  Domain.join c2;
  Domain.join c3;
  Domain.join c4;

  if BatchQueue.size q = 0 then
    Printf.printf " ✓ Passed : Stress test passed\n%!"
  else begin
    Printf.printf " ✗ FAILED : Stress test failed! Final queue size is %d instead of 0.\n%!" (BatchQueue.size q);
    exit 1
  end

let () =
  test_sequential_basic ();
  test_error_handling ();
  test_blocking_enq_deq ();
  test_fifo_single_producer_consumer ();
  test_dequeuer_head_of_line_blocking ();
  test_enqueuer_head_of_line_blocking ();
  test_no_lost_items ();
  test_batch_atomicity ();
  test_stress ();
  printf "\nAll manual tests passed!\n"