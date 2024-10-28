
open Assert
open X86
open Ll
open Backend

(* These tests are provided by you -- they will not be graded  *)

(* You should also add additional test cases here to help you   *)
(* debug your program.                                          *)

let block0: block = { insns = []; term = ("termlabel", Br "brlabel")}

let fdecl0 = 
  { f_ty = ([], Void); f_param = []; f_cfg = (block0, []) }

let compiledCode: string = string_of_prog @@ compile_fdecl [] "hola" fdecl0

let compile_fdecl_tests =
  [ ("show output: " ^ compiledCode, assert_eqf (fun () -> 0) 0)
  ]

let provided_tests : suite = [
  GradedTest("compile_fdecl tests", 0, compile_fdecl_tests)
]
