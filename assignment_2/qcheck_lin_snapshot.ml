(** QCheck-Lin Linearizability Test for Atomic Snapshot

    This test verifies that the atomic snapshot implementation is linearizable
    under concurrent access.

    == Your Task ==

    Implement the QCheck-Lin specification for the atomic snapshot.
    Follow the examples from Lecture 3:
    - qcheck_lin_bounded.ml
    - qcheck_lin_lockfree.ml

    You need to:
    1. Define the Lin API specification module (SnapshotSig)
    2. Specify init() and cleanup() functions
    3. Define the api list using Lin's DSL (val_ combinator)
    4. Generate and run the linearizability test

    == Lin DSL Type Descriptors ==

    The Snapshot.scan function returns 'int array'. Use:
      returning (array int)

    The others are standard and follow the API from the lectures.

    == Expected Result ==

    This test should PASS. The double-collect algorithm ensures linearizability:
    every scan returns a consistent snapshot that corresponds to some actual
    state that existed during the scan operation.
*)




(** QCheck-Lin Linearizability Test for Lock-Based Bounded Queue

    This test demonstrates that the lock-based bounded queue IS safe for
    multiple writers and multiple readers (MWMR).

    == Expected Result ==

    This test should PASS, confirming that the bounded queue with a mutex
    is linearizable. All concurrent executions should be reconcilable with
    some sequential execution.

    The mutex ensures that:
    - Only one thread accesses the queue state at a time
    - All operations appear atomic
    - No race conditions on head/tail updates

    Compare this with the lock-free queue test which fails!
*)

module SS = Snapshot

(** Lin API specification for the Atomic Snapshot*)
module SnapshotSig = struct
  type t = int SS.t

  (** Create a Snapshot with 4 registers for testing *)
  let init () = SS.create 4 0

  (** No cleanup needed *)
  let cleanup _ = ()

  open Lin

  (* Randomly generating indexes between 0 and 3*)
  let index = int_bound 3

  (** API description using Lin's combinator DSL *)
  let api =
    [ val_ "update" SS.update (t @-> index @-> int @-> returning unit);
      val_ "scan" SS.scan (t @-> returning (array int)); ]
end

(** Generate the linearizability test from the specification *)
module SS_domain = Lin_domain.Make(SnapshotSig)

(** Run 1000 test iterations - should all pass! *)
let () =
  QCheck_base_runner.run_tests_main [
    SS_domain.lin_test ~count:1000 ~name:"Atomic Snapshot Linearizability";
  ]