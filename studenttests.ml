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

let term_tests =
  [ "llprograms/returnvoid.ll", 0L
  ]

let provided_tests : suite = [
  GradedTest("compile_fdecl tests", 0, compile_fdecl_tests)
]
