(** A counting semaphore built on the student's own {!Mutex} and
    {!Condition}.  Any bugs in those primitives surface here. *)

type t = {
  m : Mutex.t;
  c : Condition.t;
  mutable permits : int;
}

let create n = 
  if n < 0 then raise (Invalid_argument"n must be greater than 0")
  else {
    m = Mutex.create();
    c = Condition.create();
    permits = n;
  }
  

let acquire s = 
  Mutex.lock s.m;
  while (s.permits == 0) do
    Condition.wait s.c s.m
  done;
  s.permits <- s.permits-1;
  Mutex.unlock s.m


let release s = 
  Mutex.lock s.m;
  s.permits <- s.permits+1;
  Condition.signal s.c;
  Mutex.unlock s.m