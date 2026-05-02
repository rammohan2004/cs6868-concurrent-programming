(** A reusable N-party barrier.

    Standard "sense-reversing" approach using a [round] counter: each
    fiber notes the current round on entry and waits until either the
    barrier trips (round advances) or, if it is the last arrival, trips
    the barrier itself.
*)

type t = {
  m : Mutex.t;
  c : Condition.t;
  n : int;
  mutable arrived : int;
  mutable round : int;
}

let create n = 
  if n <= 0 then invalid_arg "n must be greater than 0"
  else {
    m = Mutex.create();
    c = Condition.create();
    n;
    arrived = 0;
    round = 0;
  }

let wait b = 
  Mutex.lock b.m;
  b.arrived <- b.arrived + 1;
  if b.arrived = b.n then begin
    b.round <- b.round + 1;
    b.arrived <- 0;
    Condition.broadcast b.c
  end else begin
    let cur_round = b.round in
    while cur_round == b.round do
      Condition.wait b.c b.m
    done;
  end;
  Mutex.unlock b.m


