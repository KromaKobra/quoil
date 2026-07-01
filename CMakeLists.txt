cmake_minimum_required(VERSION 3.19)

if(NOT DEFINED VERSION)
    execute_process(
        COMMAND git describe --tags --abbrev=0
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if("${VERSION}" STREQUAL "")
        set(VERSION "dev")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    execute_process(
        COMMAND git rev-parse HEAD
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        OUTPUT_VARIABLE GIT_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if("${GIT_REVISION}" STREQUAL "")
        set(GIT_REVISION "local")
    endif()
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")
project(quoil LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(DISTRIBUTOR "local" CACHE STRING "Distributor")

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture)
endif()

add_subdirectory(extras)
add_subdirectory(plugin)

message(STATUS "Fetching M3Shapes")
include(FetchContent)
set(M3SHAPES_REV bdc327b29f95394a732baf3c9b19658ba23755b6)
FetchContent_Declare(
    m3shapes_external
    GIT_REPOSITORY https://github.com/soramanew/m3shapes.git
    GIT_TAG        ${M3SHAPES_REV}
    SOURCE_DIR     "${CMAKE_BINARY_DIR}/_deps/m3shapes-${M3SHAPES_REV}"
)
FetchContent_MakeAvailable(m3shapes_external)
if(TARGET m3shapesplugin)
    set_target_properties(m3shapesplugin PROPERTIES INSTALL_RPATH "$ORIGIN")
endif()
