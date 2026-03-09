(** Atomic Snapshot Implementation using Double-Collect Algorithm *)

(** Type of atomic snapshot object *)
type 'a t = {
  registers : 'a Atomic.t array;  (* Array of atomic registers *)
  n : int;                         (* Number of registers *)
}

let create _n _init_value = 
  if _n <= 0 then invalid_arg "Number of registers must be positive";
  {
    registers = Array.init _n (fun _ -> Atomic.make _init_value );
    n = _n
  }

let update _snapshot _idx _value = 
  if _idx < 0 || _idx >= _snapshot.n then invalid_arg "Index out of bound";
  Atomic.set _snapshot.registers.(_idx) _value


(** Helper: collect all register values *)
let collect _snapshot = 
  Array.init _snapshot.n (fun i -> Atomic.get _snapshot.registers.(i))

(** Scan using double-collect algorithm *)
let scan _snapshot = 
  let rec try_snapshot() = 
    let c1 = collect _snapshot in
    let c2 = collect _snapshot in
    if c1 = c2 then c1
    else try_snapshot()
  in try_snapshot()

let size _snapshot = _snapshot.n