(* Test.ml
 *
 * Test suite for TreeLock implementation
 * Organized into: Unit Tests, Sequential Tests, and Concurrent Tests
 *)

(** PART 1: UNIT TESTS - Testing Observable Properties **)

(* Test calculate_depth produces correct tree depth *)

let check_tree n expected_depth expected_nodes =
  let tree = TreeLock.create n in
  let actual_depth = TreeLock.get_depth tree in
  let actual_nodes = TreeLock.get_num_nodes tree in
  
  if actual_depth = expected_depth && actual_nodes = expected_nodes then
    Printf.printf "  ✓ Passed: For %d threads: Expected: Depth=%d, Nodes=%d  Actual:   Depth=%d, Nodes=%d\n%!" n expected_depth expected_nodes actual_depth actual_nodes
  else
    Printf.printf "  ✗ FAILED: For %d threads: Expected: Depth=%d, Nodes=%d  Actual:   Depth=%d, Nodes=%d\n%!" n expected_depth expected_nodes actual_depth actual_nodes


let test_calculate_depth () =
  Printf.printf "Unit Test 1: Tree depth calculation...\n%!";
  let check_depth n expected =
      let tree = TreeLock.create n in
      let d = TreeLock.get_depth tree in
      if d = expected then
        Printf.printf "  ✓ Passed: Depth for %d threads = %d (expected %d)\n%!" n d expected
      else
        Printf.printf "  ✗ FAILED: Depth for %d threads = %d (expected %d)\n%!" n d expected
  in

  check_depth 1 0; 
  check_depth 2 1; 
  check_depth 3 2; 
  check_depth 4 2; 
  check_depth 5 3; 
  check_depth 8 3;
  check_depth 16 4;
  check_depth 18 5


(* Test tree structure properties *)
let test_tree_structure () =
  Printf.printf "Unit Test 2: Tree structure properties...\n%!";
  check_tree 1 0 0;
  check_tree 2 1 1;
  check_tree 3 2 3;
  check_tree 4 2 3;
  check_tree 5 3 7;
  check_tree 8 3 7;
  check_tree 16 4 15;
  check_tree 18 5 31

(* Test boundary conditions *)
let test_boundary_conditions () =
  Printf.printf "Unit Test 3: Boundary conditions...\n%!";
  Printf.printf "Negative treads condition...\n%!";
  begin
    try
      let _ = TreeLock.create (-2) in
      Printf.printf "  ✗ FAILED: create -2 should fail but succeeded\n%!" 
    with 
    | Invalid_argument msg -> 
        Printf.printf "  ✓ Passed: create -2 raised Invalid_argument (\"%s\")\n%!" msg 
  end;

  Printf.printf "Single threads condition...\n%!";
  check_tree 1 0 0 ;
  Printf.printf "Power of 2 threads condition...\n%!";
  check_tree 2 1 1 ;
  check_tree 4 2 3 

(** PART 2: SEQUENTIAL CORRECTNESS TESTS **)

(* Test single thread can lock/unlock *)
let test_single_thread () =
  Printf.printf "Sequential Test 1: Single thread lock/unlock...\n%!";
  let tree = TreeLock.create 6 in
  TreeLock.lock tree 0;
  Printf.printf "  ✓ Locked\n%!";
  TreeLock.unlock tree 0;
  Printf.printf "  ✓ Unlocked\n%!";
  TreeLock.lock tree 0;
  Printf.printf "  ✓ Locked\n%!";
  TreeLock.unlock tree 0;
  Printf.printf "  ✓ Unlocked\n%!";
  TreeLock.lock tree 0;
  Printf.printf "  ✓ Locked\n%!";
  TreeLock.unlock tree 0;
  Printf.printf "  ✓ Unlocked\n%!";
  TreeLock.lock tree 0;
  Printf.printf "  ✓ Locked\n%!";
  TreeLock.unlock tree 0;
  Printf.printf "  ✓ Unlocked\n%!"
  

(* Test multiple sequential acquisitions by different threads *)
let test_sequential_acquisitions () =
  Printf.printf "Sequential Test 2: Sequential acquisitions by multiple threads...\n%!";
  let tree = TreeLock.create 4 in
  TreeLock.lock tree 0;
  Printf.printf "  ✓ Lock by thread 0\n%!";
  TreeLock.unlock tree 0;
  Printf.printf "  ✓ Unlock by thread 0\n%!";
  TreeLock.lock tree 1;
  Printf.printf "  ✓ Lock by thread 1\n%!";
  TreeLock.unlock tree 1;
  Printf.printf "  ✓ Unlock by thread 1\n%!";
  TreeLock.lock tree 2;
  Printf.printf "  ✓ Lock by thread 2\n%!";
  TreeLock.unlock tree 2;
  Printf.printf "  ✓ Unlock by thread 2\n%!";
  TreeLock.lock tree 3;
  Printf.printf "  ✓ Lock by thread 3\n%!";
  TreeLock.unlock tree 3;
  Printf.printf "  ✓ Unlock by thread 3\n%!"



(** PART 3: CONCURRENT CORRECTNESS TESTS **)

(* Test 1: Basic functionality with 2 threads *)
let test_two_threads () =
  Printf.printf "Concurrent Test 1: Two threads...\n%!";
  let tree = TreeLock.create 2 in
  let counter = Atomic.make 0 in
  let iterations = 100000 in

  let worker thread_id =
    for _ = 1 to iterations do
      TreeLock.lock tree thread_id;
      (* Critical section *)
      let old_val = Atomic.get counter in
      Domain.cpu_relax (); (* Introduce some delay to test race conditions *)
      Atomic.set counter (old_val + 1);
      TreeLock.unlock tree thread_id
    done
  in

  let d1 = Domain.spawn (fun () -> worker 0) in
  let d2 = Domain.spawn (fun () -> worker 1) in

  Domain.join d1;
  Domain.join d2;

  let final = Atomic.get counter in
  let expected = 2 * iterations in
  if final = expected then
    Printf.printf "  ✓ Passed: counter = %d (expected %d)\n%!" final expected
  else
    Printf.printf "  ✗ FAILED: counter = %d (expected %d)\n%!" final expected
    
(* Test 2: Four threads *)
let test_four_threads () =
  Printf.printf "Concurrent Test 2: Four threads...\n%!";
  let tree = TreeLock.create 4 in
  let counter = Atomic.make 0 in
  let iterations = 100000 in

  let worker thread_id =
    for _ = 1 to iterations do
      TreeLock.lock tree thread_id;
      (* Critical section *)
      let old_val = Atomic.get counter in
      Domain.cpu_relax (); (* Introduce some delay to test race conditions *)
      Atomic.set counter (old_val + 1);
      TreeLock.unlock tree thread_id
    done
  in
   (*TreeLock.print_tree_info tree;*)

  let d1 = Domain.spawn (fun () -> worker 0) in
  let d2 = Domain.spawn (fun () -> worker 1) in
  let d3 = Domain.spawn (fun () -> worker 2) in
  let d4 = Domain.spawn (fun () -> worker 3) in

  Domain.join d1;
  Domain.join d2;
  Domain.join d3;
  Domain.join d4;
  

  let final = Atomic.get counter in
  let expected = 4 * iterations in
  if final = expected then
    Printf.printf "  ✓ Passed: counter = %d (expected %d)\n%!" final expected
  else
    Printf.printf "  ✗ FAILED: counter = %d (expected %d)\n%!" final expected

(* Test 3: Eight threads *)
let test_eight_threads () =
  Printf.printf "Concurrent Test 3: Eight threads...\n%!";
  let tree = TreeLock.create 8 in
  let counter = Atomic.make 0 in
  let iterations = 100000 in

  let worker thread_id =
    for _ = 1 to iterations do
      TreeLock.lock tree thread_id;
      (* Critical section *)
      let old_val = Atomic.get counter in
      Domain.cpu_relax (); (* Introduce some delay to test race conditions *)
      Atomic.set counter (old_val + 1);
      TreeLock.unlock tree thread_id
    done
  in

  (*TreeLock.print_tree_info tree;*)

  let d1 = Domain.spawn (fun () -> worker 0) in
  let d2 = Domain.spawn (fun () -> worker 1) in
  let d3 = Domain.spawn (fun () -> worker 2) in
  let d4 = Domain.spawn (fun () -> worker 3) in
  let d5 = Domain.spawn (fun () -> worker 4) in
  let d6 = Domain.spawn (fun () -> worker 5) in
  let d7 = Domain.spawn (fun () -> worker 6) in
  let d8 = Domain.spawn (fun () -> worker 7) in

  Domain.join d1;
  Domain.join d2;
  Domain.join d3;
  Domain.join d4;
  Domain.join d5;
  Domain.join d6;
  Domain.join d7;
  Domain.join d8;

  let final = Atomic.get counter in
  let expected = 8 * iterations in
  if final = expected then
    Printf.printf "  ✓ Passed: counter = %d (expected %d)\n%!" final expected
  else
    Printf.printf "  ✗ FAILED: counter = %d (expected %d)\n%!" final expected



(* Test 4: Non-power-of-two threads (5 threads) *)
let test_five_threads () =
  Printf.printf "Concurrent Test 4: Five threads...\n%!";
  let tree = TreeLock.create 5 in
  let counter = Atomic.make 0 in
  let iterations = 100000 in
  
  let worker thread_id =
    for _ = 1 to iterations do
      TreeLock.lock tree thread_id;
      (* Critical section *)
      let old_val = Atomic.get counter in
      Domain.cpu_relax (); (* Introduce some delay to test race conditions *)
      Atomic.set counter (old_val + 1);
      TreeLock.unlock tree thread_id
    done
  in

   (*TreeLock.print_tree_info tree;*)

  let d1 = Domain.spawn (fun () -> worker 0) in
  let d2 = Domain.spawn (fun () -> worker 1) in
  let d3 = Domain.spawn (fun () -> worker 2) in
  let d4 = Domain.spawn (fun () -> worker 3) in
  let d5 = Domain.spawn (fun () -> worker 4) in

  Domain.join d1;
  Domain.join d2;
  Domain.join d3;
  Domain.join d4;
  Domain.join d5;

  let final = Atomic.get counter in
  let expected = 5 * iterations in
  if final = expected then
    Printf.printf "  ✓ Passed: counter = %d (expected %d)\n%!" final expected
  else
    Printf.printf "  ✗ FAILED: counter = %d (expected %d)\n%!" final expected

    

(* Test 5: Stress test - multiple increments per critical section *)
let test_stress () =
  Printf.printf "Concurrent Test 5: Stress test...\n%!";
  let tree = TreeLock.create 4 in
  let arr_len = 100 in
  let arr = Array.make arr_len 0 in
  let iterations = 100000 in

  let worker thread_id =
    for _ = 1 to iterations do
      TreeLock.lock tree thread_id;
      (* Critical section *)
      for i = 0 to arr_len - 1 do
          arr.(i) <- arr.(i) + 1
      done;
      Domain.cpu_relax (); (* Introduce some delay to test race conditions *)
      TreeLock.unlock tree thread_id
    done
  in
   (*TreeLock.print_tree_info tree;*)

  let d1 = Domain.spawn (fun () -> worker 0) in
  let d2 = Domain.spawn (fun () -> worker 1) in
  let d3 = Domain.spawn (fun () -> worker 2) in
  let d4 = Domain.spawn (fun () -> worker 3) in

  Domain.join d1;
  Domain.join d2;
  Domain.join d3;
  Domain.join d4;
  
  let flag = ref 0 in 
  for i = 0 to arr_len - 1 do
    if arr.(i) <> 4*iterations then
      flag := 1
  done;
  if !flag = 0 then
    Printf.printf "  ✓ Passed\n%!"
  else
    Printf.printf "  ✗ FAILED\n%!"


(* Test 6: Tree structure verification *)
let test_structure_verification () =
  Printf.printf "Concurrent Test 6: Tree structure verification...\n%!";
  check_tree 1 0 0;
  check_tree 2 1 1;
  check_tree 3 2 3;
  check_tree 4 2 3;
  check_tree 5 3 7;
  check_tree 8 3 7;
  check_tree 16 4 15;
  check_tree 18 5 31

(* Test 7: Performance benchmark *)
let test_performance () =
  Printf.printf "Concurrent Test 7: Performance Benchmark...\n%!";

  let measure_time name test_func =
    Printf.printf "\n  --- Benchmarking %s ---\n%!" name;
    let start_time = Unix.gettimeofday () in
    
    test_func (); 
    
    let end_time = Unix.gettimeofday () in
    let duration = end_time -. start_time in
    Printf.printf "  %s Total Time: %.4f seconds\n%!" name duration
  in

  (* Run benchmarks on your existing test functions *)
  measure_time "2 Threads" test_two_threads;
  measure_time "4 Threads" test_four_threads;
  measure_time "5 Threads" test_five_threads; 
  measure_time "8 Threads" test_eight_threads

  


  
(* Main test runner *)
let () =
  Printf.printf "=== TreeLock Test Suite ===\n\n%!";

  TreeLock.print_tree_info (TreeLock.create 8);
  Printf.printf "\n%!";

  

  (* Unit Tests *)
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n%!";
  Printf.printf "PART 1: UNIT TESTS\n%!";
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n%!";
  test_calculate_depth ();
  Printf.printf "\n%!";
  test_tree_structure ();
  Printf.printf "\n%!";
  test_boundary_conditions ();
  Printf.printf "\n%!";



  (* Sequential Tests *)
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n%!";
  Printf.printf "PART 2: SEQUENTIAL CORRECTNESS\n%!";
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n%!";
  test_single_thread ();
  Printf.printf "\n%!";
  test_sequential_acquisitions ();
  Printf.printf "\n%!";

  

  (* Concurrent Tests *)
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n%!";
  Printf.printf "PART 3: CONCURRENT CORRECTNESS\n%!";
  Printf.printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n%!";
  test_two_threads ();
  test_four_threads ();
  test_eight_threads ();
  test_five_threads ();
  
  test_stress ();
  test_structure_verification ();
  test_performance ();

  

  Printf.printf "\n=== Test Suite Complete ===\n%!"



