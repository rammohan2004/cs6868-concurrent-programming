(** Manual Concurrent Tests for Atomic Snapshot

    These tests verify basic correctness of the snapshot implementation
    using manual concurrent scenarios.

    Each test includes clear expectations - read the comments above each
    test function to understand what behavior is required.
*)

(** Test 1: Sequential operations

    WHAT TO IMPLEMENT:
    - Snapshot.create should initialize n registers with the given value
    - Snapshot.update should set a register to a new value
    - Snapshot.scan should return an array containing all register values

    EXPECTED BEHAVIOR:
    - Create a snapshot with 4 registers initialized to 0
    - Update each register to a different value (10, 20, 30, 40)
    - Scan should return exactly [| 10; 20; 30; 40 |]

    This test should PASS if your basic operations work correctly.
*)
let test_sequential () =
  Printf.printf("Test 1: Sequential operations");
  let snapshot = Snapshot.create 4 0 in
  Snapshot.update snapshot 0 10 ;
  Snapshot.update snapshot 1 20 ;
  Snapshot.update snapshot 2 30 ;
  Snapshot.update snapshot 3 40 ;
  let actual = Snapshot.scan snapshot in
  let expected = [|10;20;30;40|] in
  if actual = expected then 
    Printf.printf " ✓ Passed : Actual array (%d , %d, %d, %d) ,  Expected array (%d , %d, %d, %d)\n%! " actual.(0) actual.(1) actual.(2) actual.(3) expected.(0) expected.(1) expected.(2) expected.(3)
  else 
    Printf.printf " ✗ FAILED : Actual array (%d , %d, %d, %d) ,  Expected array (%d , %d, %d, %d)\n%! " actual.(0) actual.(1) actual.(2) actual.(3) expected.(0) expected.(1) expected.(2) expected.(3)
 


(** Test 2: Concurrent updates, single scanner

    WHAT TO IMPLEMENT:
    - Snapshot.update must be thread-safe (use Atomic.set, not ref)
    - Multiple threads can update different registers simultaneously

    EXPECTED BEHAVIOR:
    - 4 domains each update their own register 100 times
    - Domain 0 writes values 0..100 to register 0
    - Domain 1 writes values 1000..1100 to register 1, etc.
    - Final scan should see a valid state where:
      * Register 0 has a value between 0 and 100
      * Register 1 has a value between 1000 and 1100
      * Register 2 has a value between 2000 and 2100
      * Register 3 has a value between 3000 and 3100

    This test should PASS if you use Atomic.t correctly (no data races).
*)
let test_concurrent_updates () =
   Printf.printf "Test 2: Concurrent updates, single scanner";
  let sanpshot = Snapshot.create 4 0 in
  let iterations = 100 in

  let writer_helper id = 
    for i = 0 to iterations do
      Snapshot.update sanpshot id (1000*id+i)
    done
  in

  let d1 = Domain.spawn(fun() -> writer_helper 0) in
  let d2 = Domain.spawn(fun() -> writer_helper 1) in
  let d3 = Domain.spawn(fun() -> writer_helper 2) in
  let d4 = Domain.spawn(fun() -> writer_helper 3) in
  let scanner = Domain.spawn(fun() -> Snapshot.scan sanpshot) in

  Domain.join d1;
  Domain.join d2;
  Domain.join d3;
  Domain.join d4;

  let final = Domain.join scanner in
  if (final.(0) >= 0 && final.(0) <= 100 && final.(1) >= 1000 && final.(1) <= 1100 && 
    final.(2) >= 2000 && final.(2) <= 2100 && final.(3) >= 3000 && final.(3) <= 3100) then
    Printf.printf " ✓ Passed : Final values (%d , %d, %d, %d)\n%!" final.(0) final.(1) final.(2) final.(3)
  else 
    Printf.printf " ✗ FAILED : Final values (%d , %d, %d, %d)\n%!" final.(0) final.(1) final.(2) final.(3)




(** Test 3: Multiple concurrent scanners - THE CRITICAL TEST FOR DOUBLE-COLLECT

    WHAT TO IMPLEMENT:
    - Snapshot.scan must use the DOUBLE-COLLECT algorithm
    - This ensures every scan returns a LINEARIZABLE (consistent) snapshot

    EXPECTED BEHAVIOR:
    - One updater continuously writes i, i*10, i*100 to registers 0, 1, 2
    - 4 scanner threads each perform 50 scans while updates happen
    - EVERY scan must see a consistent state:
      * The iteration number visible in each register must be non-increasing
        left to right: r0 >= r1/10 >= r2/100
      * Example valid states: [0,0,0], [5,50,500], [23,230,2300]
      * Scans can see partially-written states (registers updated left to right)
      * Example valid states: [5,40,400], [5,50,400]
      * Example INVALID state: [5,50,600] (r2/100=6 > r0=5: never existed!)

    WHY THIS MATTERS:
    - Without double-collect, you might see [5, 50, 600] - a state that
      NEVER actually existed atomically
    - Double-collect guarantees you only see states that truly existed

    This test should PASS (all 200 scans consistent) ONLY if you implement
    the double-collect algorithm correctly. A naive scan will fail here.
*)
let test_concurrent_scans () =
  Printf.printf " Test 3: Multiple concurrent scanners";
  let snapshot = Snapshot.create 0 0 in 
  let is_reads_completed = Atomic.make false in
  let all_scans_consistent = Atomic.make true in 

  let scanner_helper = 
    for _ = 0 to 50 do 
      let value = Snapshot.scan snapshot in
      if value.(0) < value.(1)/10 || value.(1)/10 < value.(2)/100  then 
        Atomic.set all_scans_consistent false;
    done
  in
  let writer_helper = 
    let i = ref 0 in
    while Atomic.get is_reads_completed = false do
      Snapshot.update snapshot 0 !i;
      Snapshot.update snapshot 0 (!i*10);
      Snapshot.update snapshot 0 (!i*100);
      i := !i+1;
    done 

  in 
  
  let w1 = Domain.spawn (fun () -> writer_helper) in
  let s1 = Domain.spawn (fun () -> scanner_helper) in
  let s2 = Domain.spawn (fun () -> scanner_helper) in
  let s3 = Domain.spawn (fun () -> scanner_helper) in
  let s4 = Domain.spawn (fun () -> scanner_helper) in

  Domain.join s1;
  Domain.join s2;
  Domain.join s3;
  Domain.join s4;
  Atomic.set is_reads_completed true;
  Domain.join w1;

  if Atomic.get all_scans_consistent then 
    Printf.printf "✓ Passed "
  else 
    Printf.printf "✗ FAILED "



(** Test 4: High contention stress test

    WHAT TO IMPLEMENT:
    - Your implementation must handle many threads reading/writing simultaneously
    - No deadlocks, no crashes, no data races

    EXPECTED BEHAVIOR:
    - 8 threads run simultaneously for 1000 iterations each
    - Even-numbered threads write to registers
    - Odd-numbered threads scan continuously
    - Test should complete without hanging or crashing

    This test should PASS if your atomic operations are correct and your
    double-collect handles high contention gracefully.
*)
let test_high_contention () =
  failwith "Not implemented"

(** Main test runner *)
let () =
  test_sequential ();
  test_concurrent_updates ();
  test_concurrent_scans ();
  test_high_contention ();
  Printf.printf "All manual tests passed!\n%!"