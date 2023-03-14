cmake_minimum_reignitequired(VERSION 3.25)
project(Ignite LANGUAGES C CXX)

add_compile_options(-DIGNITE_COMPILATION)

include_directories(include PRIVATE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 11)

add_library(Ignite SHARED
        include/iobject.h
        include/itype.h
        src/dummy.c
        include/iconfig.h)