cmake_minimum_required(VERSION 3.5.0)
project(speccpu2017)

#enable_language(Fortran)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)

message(STATUS "Configuring SPEC CPU 2017... ")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Ofast -fPIC")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Ofast -fPIC")

set(CMAKE_Fortran_COMPILER_FORCED TRUE)
set(CMAKE_Fortran_COMPILER "D:/llvm-project/build-windows/bin/flang-new.exe")
set(FORTRAN_LIB_DIR "D:/llvm-aarch64-linux-ohos/lib")
set(CMAKE_Fortran_FLAGS "-fPIC -Ofast -nostdlib --target=aarch64-linux-ohos --sysroot=D:/hwclt/sdk/default/openharmony/native/sysroot -L D:/hwclt/sdk/default/openharmony/native/llvm/lib/aarch64-linux-ohos -L ${FORTRAN_LIB_DIR} -L \"${OHOS_SDK_NATIVE}/llvm/lib/clang/15.0.4/lib/aarch64-linux-ohos\"")
enable_language(Fortran)

add_compile_options(-Ofast)

message(STATUS "C flags = ${CMAKE_C_FLAGS}")
message(STATUS "C++ flags = ${CMAKE_CXX_FLAGS}")
message(STATUS "Fortran flags = ${CMAKE_Fortran_FLAGS}")

# INTrate
add_subdirectory(benchspec/CPU/500.perlbench_r)
add_subdirectory(benchspec/CPU/502.gcc_r)
add_subdirectory(benchspec/CPU/505.mcf_r)
add_subdirectory(benchspec/CPU/520.omnetpp_r)
add_subdirectory(benchspec/CPU/523.xalancbmk_r)
add_subdirectory(benchspec/CPU/525.x264_r)
add_subdirectory(benchspec/CPU/531.deepsjeng_r)
add_subdirectory(benchspec/CPU/541.leela_r)
add_subdirectory(benchspec/CPU/548.exchange2_r)
add_subdirectory(benchspec/CPU/557.xz_r)

# FPrate
add_subdirectory(benchspec/CPU/503.bwaves_r)
add_subdirectory(benchspec/CPU/507.cactuBSSN_r)
add_subdirectory(benchspec/CPU/508.namd_r)
add_subdirectory(benchspec/CPU/510.parest_r)
add_subdirectory(benchspec/CPU/511.povray_r)
add_subdirectory(benchspec/CPU/519.lbm_r)
add_subdirectory(benchspec/CPU/521.wrf_r)
add_subdirectory(benchspec/CPU/526.blender_r)
add_subdirectory(benchspec/CPU/527.cam4_r)
add_subdirectory(benchspec/CPU/538.imagick_r)
add_subdirectory(benchspec/CPU/544.nab_r)
add_subdirectory(benchspec/CPU/549.fotonik3d_r)
add_subdirectory(benchspec/CPU/554.roms_r)

# INTspeed
#add_subdirectory(benchspec/CPU/600.perlbench_s)
#add_subdirectory(benchspec/CPU/602.gcc_s)
#add_subdirectory(benchspec/CPU/605.mcf_s)
#add_subdirectory(benchspec/CPU/620.omnetpp_s)
#add_subdirectory(benchspec/CPU/623.xalancbmk_s)
#add_subdirectory(benchspec/CPU/625.x264_s)
#add_subdirectory(benchspec/CPU/631.deepsjeng_s)
#add_subdirectory(benchspec/CPU/641.leela_s)
#add_subdirectory(benchspec/CPU/657.xz_s)

#FPspeed
#add_subdirectory(benchspec/CPU/619.lbm_s)
#add_subdirectory(benchspec/CPU/638.imagick_s)
#add_subdirectory(benchspec/CPU/644.nab_s)
