(* ll ir compilation -------------------------------------------------------- *)

open Ll
open X86

(* Overview ----------------------------------------------------------------- *)

(* We suggest that you spend some time understanding this entire file and
   how it fits with the compiler pipeline before making changes.  The suggested
   plan for implementing the compiler is provided on the project web page.
*)

(*
  Lets see whether this comment will still be present after restarting the docker container!
*)


(* helpers ------------------------------------------------------------------ *)

(* Map LL comparison operations to X86 condition codes *)
let compile_cnd = function
  | Ll.Eq  -> X86.Eq
  | Ll.Ne  -> X86.Neq
  | Ll.Slt -> X86.Lt
  | Ll.Sle -> X86.Le
  | Ll.Sgt -> X86.Gt
  | Ll.Sge -> X86.Ge



(* locals and layout -------------------------------------------------------- *)

(* One key problem in compiling the LLVM IR is how to map its local
   identifiers to X86 abstractions.  For the best performance, one
   would want to use an X86 register for each LLVM %uid.  However,
   since there are an unlimited number of %uids and only 16 registers,
   doing so effectively is quite difficult.  We will see later in the
   course how _register allocation_ algorithms can do a good job at
   this.

   A simpler, but less performant, implementation is to map each %uid
   in the LLVM source to a _stack slot_ (i.e. a region of memory in
   the stack).  Since LLVMlite, unlike real LLVM, permits %uid locals
   to store only 64-bit data, each stack slot is an 8-byte value.

   [ NOTE: For compiling LLVMlite, even i1 data values should be represented
   in 64 bit. This greatly simplifies code generation. ]

   We call the datastructure that maps each %uid to its stack slot a
   'stack layout'.  A stack layout maps a uid to an X86 operand for
   accessing its contents.  For this compilation strategy, the operand
   is always an offset from %rbp (in bytes) that represents a storage slot in
   the stack.
*)

type layout = (uid * X86.operand) list

(* A context contains the global type declarations (needed for getelementptr
   calculations) and a stack layout. *)
type ctxt = { tdecls : (tid * ty) list
            ; layout : layout
            }

(* useful for looking up items in tdecls or layouts *)
let lookup m x = List.assoc x m


(* compiling operands  ------------------------------------------------------ *)

(* LLVM IR instructions support several kinds of operands.

   LL local %uids live in stack slots, whereas global ids live at
   global addresses that must be computed from a label.  Constants are
   immediately available, and the operand Null is the 64-bit 0 value.

     NOTE: two important facts about global identifiers:

     (1) You should use (Platform.mangle gid) to obtain a string
     suitable for naming a global label on your platform (OS X expects
     "_main" while linux expects "main").

     (2) 64-bit assembly labels are not allowed as immediate operands.
     That is, the X86 code: movq _gid %rax which looks like it should
     put the address denoted by _gid into %rax is not allowed.
     Instead, you need to compute an %rip-relative address using the
     leaq instruction:   leaq _gid(%rip).

   One strategy for compiling instruction operands is to use a
   designated register (or registers) for holding the values being
   manipulated by the LLVM IR instruction. You might find it useful to
   implement the following helper function, whose job is to generate
   the X86 instruction that moves an LLVM operand into a designated
   destination (usually a register).
*)
let compile_operand (ctxt:ctxt) (dest:X86.operand) : Ll.operand -> ins =
  function on -> match on with
    | Gid lbl -> Leaq, [Ind3 (Lbl (Platform.mangle lbl), Rip); dest]
    | Null -> Movq, [Imm (Lit 0L); dest]
    | Const q -> Movq, [Imm (Lit q); dest]
    | Id lbl -> Movq, [lookup ctxt.layout lbl; dest]




(* compiling call  ---------------------------------------------------------- *)

(* You will probably find it helpful to implement a helper function that
   generates code for the LLVM IR call instruction.

   The code you generate should follow the x64 System V AMD64 ABI
   calling conventions, which places the first six 64-bit (or smaller)
   values in registers and pushes the rest onto the stack.  Note that,
   since all LLVM IR operands are 64-bit values, the first six
   operands will always be placed in registers.  (See the notes about
   compiling fdecl below.)

   [ NOTE: It is the caller's responsibility to clean up arguments
   pushed onto the stack, so you must free the stack space after the
   call returns. ]

   [ NOTE: Don't forget to preserve caller-save registers (only if
   needed). ]
*)




(* compiling getelementptr (gep)  ------------------------------------------- *)

(* The getelementptr instruction computes an address by indexing into
   a datastructure, following a path of offsets.  It computes the
   address based on the size of the data, which is dictated by the
   data's type.

   To compile getelementptr, you must generate x86 code that performs
   the appropriate arithmetic calculations.
*)

(* [size_ty] maps an LLVMlite type to a size in bytes.
    (needed for getelementptr)

   - the size of a struct is the sum of the sizes of each component
   - the size of an array of t's with n elements is n * the size of t
   - all pointers, I1, and I64 are 8 bytes
   - the size of a named type is the size of its definition

   - Void, i8, and functions have undefined sizes according to LLVMlite.
     Your function should simply return 0 in those cases
*)
let rec size_ty (tdecls:(tid * ty) list) (t:Ll.ty) : int =
  match t with
  | I1 -> 8
  | I64 -> 8
  | Ptr _ -> 8
  | Struct l -> List.fold_left (fun s t' -> s + size_ty tdecls t') 0 l
  | Array (s, t') -> s * size_ty tdecls t'
  | Namedt s -> size_ty tdecls (lookup tdecls s)
  | _ -> 0




(* Generates code that computes a pointer value.

   1. op must be of pointer type: t*

   2. the value of op is the base address of the calculation

   3. the first index in the path is treated as the index into an array
     of elements of type t located at the base address

   4. subsequent indices are interpreted according to the type t:

     - if t is a struct, the index must be a constant n and it
       picks out the n'th element of the struct. [ NOTE: the offset
       within the struct of the n'th element is determined by the
       sizes of the types of the previous elements ]

     - if t is an array, the index can be any operand, and its
       value determines the offset within the array.

     - if t is any other type, the path is invalid

   5. if the index is valid, the remainder of the path is computed as
      in (4), but relative to the type f the sub-element picked out
      by the path so far
*)
let compile_gep (ctxt:ctxt) (op : Ll.ty * Ll.operand) (path: Ll.operand list) : ins list =
failwith "compile_gep not implemented"



(* compiling instructions  -------------------------------------------------- *)

(* The result of compiling a single LLVM instruction might be many x86
   instructions.  We have not determined the structure of this code
   for you. Some of the instructions require only a couple of assembly
   instructions, while others require more.  We have suggested that
   you need at least compile_operand, compile_call, and compile_gep
   helpers; you may introduce more as you see fit.

   Here are a few notes:

   - Icmp:  the Setb instruction may be of use.  Depending on how you
     compile Cbr, you may want to ensure that the value produced by
     Icmp is exactly 0 or 1.

   - Load & Store: these need to dereference the pointers. Const and
     Null operands aren't valid pointers.  Don't forget to
     Platform.mangle the global identifier.

   - Alloca: needs to return a pointer into the stack

   - Bitcast: does nothing interesting at the assembly level
*)
let compile_insn (ctxt:ctxt) ((uid:uid), (i:Ll.insn)) : X86.ins list =
      failwith "compile_insn not implemented"



(* compiling terminators  --------------------------------------------------- *)

(* prefix the function name [fn] to a label to ensure that the X86 labels are
   globally unique . *)
let mk_lbl (fn:string) (l:string) = fn ^ "." ^ l

(* Compile block terminators is not too difficult:

   - Ret should properly exit the function: freeing stack space,
     restoring the value of %rbp, and putting the return value (if
     any) in %rax.

   - Br should jump

   - Cbr branch should treat its operand as a boolean conditional

   [fn] - the name of the function containing this terminator
*)
let compile_terminator (fn:string) (ctxt:ctxt) (t:Ll.terminator) : ins list =
  let stackSize = Imm (Lit (Int64.of_int (8 * (List.length ctxt.layout)))) in
  match t with
  | Ret (Void, None) -> [
      Addq, [stackSize; Reg Rsp];
      Popq, [Reg Rbp];
      Retq, []
    ]
  | Ret (Void, Some _) -> failwith "Cannot have Void return type with a Some _ value."
  | Ret (rty, Some (Const i)) -> [
      Addq, [stackSize; Reg Rsp];
      Movq, [Imm (Lit i); Reg Rax];
      Popq, [Reg Rbp];
      Retq, []
    ]
  | Ret (rty, Some (Gid gid)) -> failwith "compile_terminator doesn't support global returns yet."
  | Ret (rty, Some (Id uid)) -> [
      Addq, [stackSize; Reg Rsp];
      Movq, [lookup ctxt.layout uid; Reg Rax];
      Popq, [Reg Rbp];
      Retq, []
    ]
  | Br lbl -> [Jmp, [Imm (Lbl lbl)]]
  | Cbr (on, l1, l2) -> compile_operand ctxt (Reg Rax) on ::
    [
      Cmpq, [Imm (Lit 0L); Reg Rax];
      J Eq, [Imm (Lbl l2)];
      Jmp, [Imm (Lbl l1)]
    ]
  | _ -> failwith "compile_terminator not implemented"


(* compiling blocks --------------------------------------------------------- *)

(* We have left this helper function here for you to complete. 
   [fn] - the name of the function containing this block
   [ctxt] - the current context
   [blk]  - LLVM IR code for the block
*)
let compile_block (fn:string) (ctxt:ctxt) (blk:Ll.block) : ins list =
  compile_terminator fn ctxt (snd blk.term)

let compile_lbl_block fn lbl ctxt blk : elem =
  Asm.text (mk_lbl fn lbl) (compile_block fn ctxt blk)



(* compile_fdecl ------------------------------------------------------------ *)


(* This helper function computes the location of the nth incoming
   function argument: either in a register or relative to %rbp,
   according to the calling conventions.  You might find it useful for
   compile_fdecl.

   [ NOTE: the first six arguments are numbered 0 .. 5 ]
  First six assignments:
  rdi, rsi, rdx, rcx, r8, r9
  Following:
  ((n-7)+2)*8 + rbp
*)
let arg_loc (n : int) : operand = (* DONE NOTEST *)
  match n with
  | 0 -> Reg X86.Rdi
  | 1 -> Reg X86.Rsi
  | 2 -> Reg X86.Rdx
  | 3 -> Reg X86.Rcx
  | 4 -> Reg X86.R08
  | 5 -> Reg X86.R09
  | _ -> Ind3 ((Lit (Int64.of_int (((n-7)+2)*8))), X86.Rbp)

(*
  CUSTOM
  I want to have an easy way of creating integer ranges:
*)
let rec (--) (i: int) (j: int): int list = 
  if i <= j then i :: (succ i -- j)
  else []

(* We suggest that you create a helper function that computes the
   stack layout for a given function declaration.

   - each function argument should be copied into a stack slot
   - in this (inefficient) compilation strategy, each local id
     is also stored as a stack slot.
   - see the discussion about locals

*)
let stack_layout (args : uid list) ((block, lbled_blocks):cfg) : layout =
  let nargs = List.length args in
  let stackslot (n: int): operand = Ind3 (Lit (Int64.of_int @@ -8*n), Rbp) in
  let param_layout: layout = List.combine args @@ List.map stackslot (1 -- nargs) in
  let loc_lbls: lbl list = List.map fst @@ block.insns @ List.concat (List.map (fun (_, b) -> b.insns) lbled_blocks) in
  let local_layout: layout = List.combine loc_lbls @@ List.map stackslot ((nargs + 1) -- (nargs + List.length loc_lbls)) in
  param_layout @ local_layout

let interleave (l1: 'a list) (l2: 'a list): 'a list =
  List.fold_right (fun (a, b) l -> a::b::l) (List.combine l1 l2) []

(* The code for the entry-point of a function must do several things:

   - since our simple compiler maps local %uids to stack slots,
     compiling the control-flow-graph body of an fdecl requires us to
     compute the layout (see the discussion of locals and layout)

   - the function code should also comply with the calling
     conventions, typically by moving arguments out of the parameter
     registers (or stack slots) into local storage space.  For our
     simple compilation strategy, that local storage space should be
     in the stack. (So the function parameters can also be accounted
     for in the layout.)

   - the function entry code should allocate the stack storage needed
     to hold all of the local stack slots.
*)
let compile_fdecl (tdecls:(tid * ty) list) (name:string) ({ f_ty; f_param; f_cfg }:fdecl) : prog =
  let flayout = stack_layout f_param f_cfg in
  let getterP = List.map2 (fun n l -> (Movq, [arg_loc n; Reg Rax])) (0--(List.length f_param - 1)) f_param in
  let setterP = List.map (fun l -> (Movq, [Reg Rax; lookup flayout l])) f_param in
  let paramP = interleave getterP setterP in
  let stackSize = Imm (Lit (Int64.of_int (8 * (List.length flayout)))) in
  let iblockP = compile_block name { tdecls = tdecls; layout = flayout} (fst f_cfg) in
  let initSequence =
    (Pushq, [Reg Rbp])::(Subq, [stackSize; Reg Rsp])::paramP in
  [{lbl = name; global = true; asm = Text (
    initSequence @ iblockP
    )}]
  


(* compile_gdecl ------------------------------------------------------------ *)
(* Compile a global value into an X86 global data declaration and map
   a global uid to its associated X86 label.
*)
let rec compile_ginit : ginit -> X86.data list = function
  | GNull     -> [Quad (Lit 0L)]
  | GGid gid  -> [Quad (Lbl (Platform.mangle gid))]
  | GInt c    -> [Quad (Lit c)]
  | GString s -> [Asciz s]
  | GArray gs | GStruct gs -> List.map compile_gdecl gs |> List.flatten
  | GBitcast (t1,g,t2) -> compile_ginit g

and compile_gdecl (_, g) = compile_ginit g


(* compile_prog ------------------------------------------------------------- *)
let compile_prog {tdecls; gdecls; fdecls} : X86.prog =
  let g = fun (lbl, gdecl) -> Asm.data (Platform.mangle lbl) (compile_gdecl gdecl) in
  let f = fun (name, fdecl) -> compile_fdecl tdecls name fdecl in
  (List.map g gdecls) @ (List.map f fdecls |> List.flatten)
