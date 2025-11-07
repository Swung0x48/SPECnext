message(STATUS "Generating build files for 503.bwaves_r...")

set(SRC_FILE_503
    src/block_solver.F
    src/fill1.F
    src/fill2.F
    src/flow_lam.F
    src/flux_lam.F
    src/jacobian_lam.F
    src/shell_lam.F
)

add_library(bwaves_r SHARED
    ${SRC_FILE_503}
    ${HMSPEC_ROOT_DIR}/Fortran_main.c
)
target_compile_definitions(bwaves_r PRIVATE
    -DSPEC -DNDEBUG -DSPEC_AUTO_SUPPRESS_OPENMP -DSPEC_LP64
)

target_link_directories(bwaves_r PRIVATE
    ${FORTRAN_LIB_DIR}
)

target_include_directories(bwaves_r PRIVATE
    "D:/llvm-project/flang/include"
)

target_link_libraries(bwaves_r PRIVATE
    FortranRuntime
    FortranDecimal
    clang_rt.builtins
)
