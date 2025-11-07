message(STATUS "Generating build files for 548.exchange2_r...")

set(SRC_FILE_548 src/exchange2.F90)

add_library(exchange2_r SHARED
    ${SRC_FILE_548}
    ${HMSPEC_ROOT_DIR}/Fortran_main.c
)
target_compile_definitions(exchange2_r PRIVATE
    -DSPEC -DNDEBUG -DSPEC_AUTO_SUPPRESS_OPENMP -DSPEC_LP64
)

target_include_directories(exchange2_r PRIVATE
    "D:/llvm-project/flang/include"
)

target_link_libraries(exchange2_r PRIVATE
    FortranRuntime
    FortranDecimal
    clang_rt.builtins
)
