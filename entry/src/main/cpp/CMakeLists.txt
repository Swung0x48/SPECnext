# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(NativeHarmony)
set(CMAKE_CXX_STANDARD 17)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

set(HMSPEC_ROOT_DIR ${CMAKE_CURRENT_LIST_DIR})

add_library(wrap STATIC wrap.c)

set_source_files_properties(wrap.c PROPERTIES LANGUAGE C)


add_library(entry SHARED napi_init.cpp)
target_link_libraries(entry PUBLIC
                        libace_napi.z.so librawfile.z.so libqos.so libhilog_ndk.z.so
                        wrap)

add_subdirectory(cpu2017)
add_subdirectory(vkpeak)
add_subdirectory(c2clat)
#add_subdirectory(llama.cpp)
