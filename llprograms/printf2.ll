declare void @printf(i8*)

@format = global [15 x i8] c"test alignment\00"

define i64 @main(i64 %argc, i8** %argv) {
  %1 = getelementptr [15 x i8], [15 x i8]* @format, i32 0, i32 0
  %2 = add i64 0, 0
  call void @printf(i8* %1)
  ret i64 %2
}
