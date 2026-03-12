(** Atomic Snapshot Implementation using Double-Collect Algorithm *)


(** Data inside each atomic register *)
type 'a register_state = {
  value : 'a;
  seq : int;          (* Sequence number to track how many times this register was updated *)
  view : 'a array;    (* The snapshot taken by the writer before updating *)
}

(** Type of the atomic snapshot object *)
type 'a t = {
  registers : 'a register_state Atomic.t array;
  n : int;
}


let create _n _init_value = 
  if _n <= 0 then invalid_arg "Number of registers must be positive";
  let initial_state = Array.init _n (fun _ -> _init_value) in
  let initial_value = {value = _init_value; seq = 0; view = initial_state} in 
  let registers = Array.init _n (fun _ -> Atomic.make initial_value) in 
  {registers = registers; n = _n}



(** Helper: collect all register values *)
let collect _snapshot = 
  Array.init _snapshot.n (fun i -> Atomic.get _snapshot.registers.(i))

(** Scan using double-collect algorithm *)
let scan snapshot =
  
  let moved = Array.make snapshot.n false in
  
  let rec try_snapshot () =
    let c1 = collect snapshot in
    let c2 = collect snapshot in
    
    let changed_idx = ref (-1) in
    for i = 0 to snapshot.n - 1 do
      if c1.(i).seq <> c2.(i).seq then 
        changed_idx := i
    done;
    
    if !changed_idx = -1 then
      let content = Array.init snapshot.n (fun i -> c1.(i).value) in
      content
      
    else
      let j = !changed_idx in
      if moved.(j) then
        c2.(j).view
      else begin
        moved.(j) <- true;
        try_snapshot ()
      end
  in
  try_snapshot ()


let update _snapshot _idx _value = 
  if _idx < 0 || _idx >= _snapshot.n then invalid_arg "Index out of bound";
  let snap = scan _snapshot in 
  let current_reg_state = Atomic.get _snapshot.registers.(_idx) in 
  let cur_seq = current_reg_state.seq in 
  let new_reg_state = {value = _value; seq = (cur_seq+1); view = snap} in 
  Atomic.set _snapshot.registers.(_idx) new_reg_state



let size _snapshot = _snapshot.n