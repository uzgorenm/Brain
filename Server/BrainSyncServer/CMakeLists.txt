cmake_minimum_required(VERSION 3.20)

project(BrainSyncServer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(brain-sync-server src/main.cpp)
