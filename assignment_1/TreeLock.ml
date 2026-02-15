(* TreeLock.ml
 *
 * Tree-based lock implementation for n-thread mutual exclusion
 * Uses Peterson locks at each internal node of a binary tree
 *)

type t = PetersonNode.t array (* Define this yourself *)

(* Calculate the depth of the tree needed for n threads *)
let calculate_depth n =
  (* Depth = ceiling(log2(n)) *)
  if n <= 0 then invalid_arg "Number of threads must be positive";
  if n = 1 then 0
  else
    let count = ref 0 in
    let temp = ref (n - 1) in
    while !temp > 0 do
      temp := !temp lsr 1;
      count := !count + 1
    done;
    !count

(* Convert thread_id to binary path representation *)
let thread_id_to_path thread_id depth =
  (* Returns array of 0s and 1s representing path from root to leaf *)
  Array.init depth (fun i -> 
    let bit_mask = (1 lsl (depth-1-i) ) in
    if (thread_id land bit_mask = 0) then 0 else 1
  )
  (*failwith "Not implemented"*)

(* Get index of node in array given path from root *)
let path_to_index path level =
  (* Level 0 is root (index 0)
     Left child of i is 2*i + 1
     Right child of i is 2*i + 2 *)
    let index = ref 0 in
    for i = 0 to level-1 do
     index := ((!index * 2 )+ (path.(i)+1))
    done;
    !index


  (*failwith "Not implemented"*)

let create num_threads =
  let depth = calculate_depth num_threads in
  let internal_nodes = (1 lsl depth) - 1 in
  Array.init internal_nodes (fun _ -> PetersonNode.create())
  (*failwith "Not implemented"*)

let lock tree thread_id =
  let depth = calculate_depth ((Array.length tree)+1) in
  let path = thread_id_to_path thread_id depth in
  for i = depth-1 downto 0 do
    let index = path_to_index path i in
    PetersonNode.lock tree.(index) path.(i)
  done
  
  (*failwith "Not implemented"*)

let unlock tree thread_id =
  
  let depth = calculate_depth ((Array.length tree)+1)  in
  let path = thread_id_to_path thread_id depth in
  for i = 0 to depth-1 do
    let index = path_to_index path i in
    PetersonNode.unlock tree.(index) path.(i)
  done
  (*failwith "Not implemented"*)

(* Additional utility functions for debugging and analysis *)

let get_depth tree =
  let size = Array.length tree in
  let num_threads = size + 1 in 
  let depth = calculate_depth num_threads in
  depth

let get_num_nodes tree =
  Array.length tree

let print_tree_info tree =
  let depth = get_depth tree in 
  let num_nodes = get_num_nodes tree in
  Printf.printf "Depth : %d, Peterson Nodes %d \n%!" depth num_nodes