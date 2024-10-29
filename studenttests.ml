open Assert
open X86
open Ll
open Backend

(* These tests are provided by you -- they will not be graded  *)

(* You should also add additional test cases here to help you   *)
(* debug your program.                                          *)

let block0: block = { insns = []; term = ("termlabel", Ret (Void, None))}

let fdecl0 = 
  { f_ty = ([I64; I64; I8; I64; I64; I8; I1; I64; I8;I64; I64; I8], Void); f_param = ["a";"b";"c";"d";"e";"f";"g";"h";"i"]; f_cfg = (block0, []) }

let compiledFDeclCode: string = string_of_prog @@ compile_fdecl [] "hola" fdecl0

let compile_fdecl_tests =
  [ ("show fdecl output:\n" ^ compiledFDeclCode ^ "\nend of output.\n", assert_eqf (fun () -> 0) 1)
  ]

let compile_and_print path =
  let ast = Driver.parse_ll_file path in
  let asm_ast = Backend.compile_prog ast in
  X86.string_of_prog asm_ast

let compile_binop_tests =
  [
    ("show llprograms/add.ll output:\n" ^ compile_and_print "llprograms/add.ll" ^ "\nend of output.\n",
    assert_eqf (fun () -> 0) 1)
  ]

let provided_tests : suite = [
  GradedTest("compile_fdecl tests", 0, compile_fdecl_tests);
  GradedTest("compile_binop tests", 0, compile_binop_tests)
]
