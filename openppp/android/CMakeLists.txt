CMAKE_MINIMUM_REQUIRED(VERSION 3.0.0)

# Define the solutions name.
SET(NAME openppp2)
PROJECT(${NAME} C CXX) # CMAKE_CURRENT_SOURCE_DIR

# C/CXX compiler configurations.
SET(CMAKE_C_FLAGS "-fPIC -fvisibility=hidden -Wno-format -Wno-implicit-function-declaration")
SET(CMAKE_CXX_FLAGS "-fPIC -stdlib=libc++ -fvisibility=hidden -Ulinux -Wno-#pragma-messages -Wno-format -Wno-inconsistent-missing-override -Wno-pointer-bool-conversion -Wno-unsequenced -Wno-null-dereference -Wno-gnu-variable-sized-type-not-at-end -Wno-tautological-undefined-compare -Wno-deprecated-declarations -Wno-shift-count-overflow")

# Configure predefined compilation macros.
ADD_DEFINITIONS(-D_ANDROID)
ADD_DEFINITIONS(-D_LINUX)
ADD_DEFINITIONS(-DFUNCTION)
ADD_DEFINITIONS(-DBUDDY_ALLOC_IMPLEMENTATION)
ADD_DEFINITIONS(-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION)
SET(PROJECT_ROOT_DIR "${PROJECT_SOURCE_DIR}/../")

# ENV.
SET(PLATFORM_DEBUG FALSE)
IF(CMAKE_BUILD_TYPE STREQUAL "Debug" OR BT MATCHES "Debug")
    SET(PLATFORM_DEBUG TRUE)
ENDIF()

# For the sake of compatibility, reliability, and stability, it is advisable to prefer using Debug mode and enable the -g0 -O3 options,
# When compiling the libopenppp2 dynamic link library.
SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g0 -O3")
SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g0 -O3")

# If the aforementioned options are not required, you need to enable the compiler options configuration mentioned below.
# # C
# IF(PLATFORM_DEBUG)
#     SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -D_DEBUG -g3")
# ELSE()
#     SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3")
# ENDIF()

# # C/CXX
# IF(PLATFORM_DEBUG)
#     SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_DEBUG -g3")
# ELSE()
#     SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")
# ENDIF()

# Check C/CXX compiler supports.
INCLUDE(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++17" COMPILER_SUPPORTS_CXX17)
CHECK_CXX_COMPILER_FLAG("-std=c++1z" COMPILER_SUPPORTS_CXX1Z)

# If the current compiler environment is detected to support AES.
SET(__SIMD__ FALSE)
IF(__SIMD__)
    # Add in the compiler flag section.
    ADD_COMPILE_OPTIONS(-maes -msse2 -mpclmul)

    # Add the AES_NI compiler macro.
    ADD_DEFINITIONS(-D__SIMD__)

    # Additional options for the old version of GCC.
    IF(CMAKE_CXX_COMPILER_VERSION VERSION_LESS 8.0)
        ADD_COMPILE_OPTIONS(-march=westmere)
        ADD_COMPILE_OPTIONS(-fno-stack-protector)
    ENDIF()

    # AES is enabled, the source code of AES/128/256/CFB related to the library needs to be compiled.
    FILE(GLOB_RECURSE AES_NI_SOURCE_FILES
        ${PROJECT_ROOT_DIR}/common/aesni/impl/*.c
        ${PROJECT_ROOT_DIR}/common/aesni/impl/*.cpp)
ENDIF()

# According to the type of operating system to determine whether you need to check whether the compiler supports C/C++17,
# On the MACOS system, the following check code is invalid, so directly specify the standard version of C/C++,
# If an error or compilation does not pass, it means that you need to upgrade the LLVM GCC/CLANG compiler installed on MACOS.

# CXX17
SET(CMAKE_CXX_STANDARD 17)

# -rdynamic -Wl,-Bstatic -Wl,-Bdynamic -lstdc++ -lpthread -ldl -lz -lrt
SET(CMAKE_EXE_LINKER_FLAGS "-static-libstdc++ -rdynamic -Wl,-Bstatic")

# Set the tripartite library directorys.
SET(THIRD_PARTY_LIBRARY_DIR "${PROJECT_ROOT_DIR}/third-party" CACHE PATH "Android third-party root directory")

IF(NOT ANDROID_ABI)
    MESSAGE(FATAL_ERROR "ANDROID_ABI is required for the Android build.")
ENDIF()

SET(BOOST_ANDROID_LIB_DIR "${THIRD_PARTY_LIBRARY_DIR}/boost/${ANDROID_ABI}" CACHE PATH "Android Boost static library directory")
SET(OPENSSL_ANDROID_ROOT "${THIRD_PARTY_LIBRARY_DIR}/openssl-${ANDROID_ABI}" CACHE PATH "Android OpenSSL install root")
SET(BOOST_ANDROID_INCLUDE_DIR "${THIRD_PARTY_LIBRARY_DIR}/boost-src" CACHE PATH "Android Boost include directory")
SET(OPENSSL_ANDROID_INCLUDE_DIR "${OPENSSL_ANDROID_ROOT}/include")
SET(OPENSSL_ANDROID_LIB_DIR "${OPENSSL_ANDROID_ROOT}/lib")

SET(OPENPPP2_ANDROID_STATIC_LIBS
    "${OPENSSL_ANDROID_LIB_DIR}/libssl.a"
    "${OPENSSL_ANDROID_LIB_DIR}/libcrypto.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_system.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_coroutine.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_thread.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_context.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_regex.a"
    "${BOOST_ANDROID_LIB_DIR}/libboost_filesystem.a"
)

FOREACH(OPENPPP2_STATIC_LIB ${OPENPPP2_ANDROID_STATIC_LIBS})
    IF(NOT EXISTS "${OPENPPP2_STATIC_LIB}")
        MESSAGE(FATAL_ERROR "Missing Android static dependency: ${OPENPPP2_STATIC_LIB}")
    ENDIF()
ENDFOREACH()

# Set the compiled header file search directorys.
INCLUDE_DIRECTORIES(
    ${PROJECT_ROOT_DIR}/
    ${PROJECT_ROOT_DIR}/common
    ${PROJECT_ROOT_DIR}/common/json/include
    ${PROJECT_ROOT_DIR}/common/lwip/my
    ${PROJECT_ROOT_DIR}/common/lwip/include

    ${BOOST_ANDROID_INCLUDE_DIR}
    ${OPENSSL_ANDROID_INCLUDE_DIR}
)

SET(BUILD_SHARED_LIBS ON)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# List of common cpp source files compilations for ppp/unix cmake solution projects.
FILE(GLOB_RECURSE SOURCE_FILES
    ${PROJECT_ROOT_DIR}/common/lwip/my/*.c
    ${PROJECT_ROOT_DIR}/common/lwip/core/*.c
    ${PROJECT_ROOT_DIR}/common/lwip/api/*.c

    ${PROJECT_ROOT_DIR}/common/aggligator/*.cpp
    ${PROJECT_ROOT_DIR}/common/base64/*.cpp
    ${PROJECT_ROOT_DIR}/common/chnroutes2/*.cpp
    ${PROJECT_ROOT_DIR}/common/json/src/*.cpp
    ${PROJECT_ROOT_DIR}/common/libtcpip/*.cpp
    ${PROJECT_ROOT_DIR}/common/dnslib/*.cpp
    ${PROJECT_ROOT_DIR}/common/unix/*.c
    ${PROJECT_ROOT_DIR}/common/unix/*.cpp
    ${PROJECT_ROOT_DIR}/common/aesni/aes.cpp

    ${PROJECT_ROOT_DIR}/ppp/*.c
    ${PROJECT_ROOT_DIR}/ppp/*.cpp

    ${PROJECT_ROOT_DIR}/linux/*.c
    ${PROJECT_ROOT_DIR}/linux/*.cpp

    ${PROJECT_ROOT_DIR}/android/libopenppp2.cpp
    ${PROJECT_ROOT_DIR}/android/OpenPPP2VpnProtectBridge.cpp)

# Add the compiled output binary files.
ADD_LIBRARY(${NAME} SHARED ${SOURCE_FILES} ${PLATFORM_SOURCE_FILES} ${AES_NI_SOURCE_FILES})

# Set up library connections to dependent libraries.
TARGET_LINK_LIBRARIES(${NAME}
    ${OPENPPP2_ANDROID_STATIC_LIBS}
    log
    dl)
