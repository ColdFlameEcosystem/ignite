cmake_minimum_required(VERSION 3.25)
project(Ignite LANGUAGES C CXX)

add_compile_options(-DIGNITE_COMPILATION)

include_directories(src/ PRIVATE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

add_library(Ignite SHARED
        src/iobject.h
        src/itype.h
        src/dummy.c src/iconfig.h)