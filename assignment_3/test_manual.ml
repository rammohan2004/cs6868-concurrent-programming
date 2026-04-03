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

  printf "PASSED\n"

(** Test that invalid arguments raise [Invalid_argument]. *)
let test_error_handling () = failwith "TODO: implement"

(** Test that deq blocks until items arrive (and/or enq blocks until space frees). *)
let test_blocking_enq_deq () = failwith "TODO: implement"

(** Test that a single producer/consumer pair sees items in FIFO order. *)
let test_fifo_single_producer_consumer () = failwith "TODO: implement"

(** Test dequeuer head-of-line blocking: deq(5) arrives before deq(2);
    even when 6 items are enqueued, deq(5) must be served first. *)
let test_dequeuer_head_of_line_blocking () = failwith "TODO: implement"

(** Test enqueuer head-of-line blocking: enq(3) arrives before enq(1);
    freeing 1 slot must NOT let enq(1) jump ahead. *)
let test_enqueuer_head_of_line_blocking () = failwith "TODO: implement"

(** Test that no items are lost or duplicated under concurrent access. *)
let test_no_lost_items () = failwith "TODO: implement"

(** Test that a batch enqueue is not interleaved with another batch. *)
let test_batch_atomicity () = failwith "TODO: implement"

(** Stress test: multiple producers and consumers with many operations. *)
let test_stress () = failwith "TODO: implement"

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