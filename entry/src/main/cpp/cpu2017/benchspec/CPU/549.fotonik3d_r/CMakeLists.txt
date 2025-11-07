message(STATUS "Generating build files for 549.fotonik3d_r...")

set(SRC_FILE_549
    src/globalvar.F90
    src/calcflops.F90
    src/parameter.f90
    src/PlaneSource.F90
    src/huygens.F90
    src/update.F90
    src/material.F90
    src/MPI_dummy.F90
    src/init.F90
    src/writeout.F90
    src/leapfrog.F90
    src/communicate.F90
    src/yeemain.F90
    src/timerRoutine.f90
    src/PEC.F90
    src/mur.F90
    src/power.F90
    src/readline.f90
    src/UPML.F90
)

add_library(fotonik3d_r SHARED
    ${SRC_FILE_549}
    ${HMSPEC_ROOT_DIR}/Fortran_main.c
)
target_compile_definitions(fotonik3d_r PRIVATE
    -DSPEC -DNDEBUG -DSPEC_AUTO_SUPPRESS_OPENMP -DSPEC_LP64
)


target_include_directories(fotonik3d_r PRIVATE
    "D:/llvm-project/flang/include"
)

target_link_libraries(fotonik3d_r PRIVATE
    FortranRuntime
    FortranDecimal
    clang_rt.builtins
)
