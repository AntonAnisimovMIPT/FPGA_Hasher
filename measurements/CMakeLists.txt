cmake_minimum_required(VERSION 3.10)
project(FPGA_Hasher)

cmake_policy(SET CMP0167 OLD)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(BOOST_ROOT "C:/boost_1.85")
set(Boost_INCLUDE_DIR "C:/boost_1.85/include/boost-1_85/")
set(Boost_USE_STATIC_RUNTIME ON)
set(Boost_USE_STATIC_LIBS ON)
set(Boost_USE_MULTITHREADED ON)

find_package(Boost REQUIRED COMPONENTS system filesystem json program_options)
find_package(OpenSSL REQUIRED)

if(Boost_FOUND AND OpenSSL_FOUND)
    file(GLOB SOURCES "src/*.cpp")
    add_executable(FPGA_Hasher ${SOURCES})

    target_include_directories(FPGA_Hasher
        PRIVATE
        ${Boost_INCLUDE_DIRS})

    target_link_libraries(FPGA_Hasher
        ${Boost_LIBRARIES}
        OpenSSL::SSL
        OpenSSL::Crypto
        ws2_32
    )
endif()
