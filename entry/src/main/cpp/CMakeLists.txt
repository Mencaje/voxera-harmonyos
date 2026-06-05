cmake_minimum_required(VERSION 3.16)
project(voxera_luanti_host)

set(NATIVERENDER_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
set(VOXERA_LUANTI_ROOT "${NATIVERENDER_ROOT}/../../../../luanti")

option(VOXERA_BUILD_LUANTI "Link full Luanti engine (requires entry/ohos_deps)" OFF)

add_library(entry SHARED
    napi_init.cpp
    xcomponent_bridge.cpp
    luanti_host.cpp
    egl_preview.cpp
)

target_include_directories(entry PRIVATE ${NATIVERENDER_ROOT})

target_compile_features(entry PRIVATE cxx_std_17)

target_link_libraries(entry PUBLIC
    libace_napi.z.so
    libace_ndk.z.so
    libhilog_ndk.z.so
    libnative_window.so
    libEGL.so
    libGLESv3.so
)

if(VOXERA_BUILD_LUANTI)
    set(OHOS TRUE CACHE BOOL "HarmonyOS target" FORCE)
    set(BUILD_CLIENT TRUE CACHE BOOL "" FORCE)
    set(BUILD_SERVER FALSE CACHE BOOL "" FORCE)
    set(BUILD_UNITTESTS FALSE CACHE BOOL "" FORCE)
    set(BUILD_BENCHMARKS FALSE CACHE BOOL "" FORCE)
    set(BUILD_DOCUMENTATION FALSE CACHE BOOL "" FORCE)
    set(ENABLE_UPDATE_CHECKER FALSE CACHE BOOL "" FORCE)
    set(ENABLE_GETTEXT FALSE CACHE BOOL "" FORCE)
    if(CMAKE_OHOS_ARCH_ABI)
        set(OHOS_ARCH "${CMAKE_OHOS_ARCH_ABI}" CACHE STRING "" FORCE)
    elseif(OHOS_ARCH)
        set(CMAKE_OHOS_ARCH_ABI "${OHOS_ARCH}" CACHE STRING "" FORCE)
    endif()

    list(APPEND CMAKE_MODULE_PATH ${VOXERA_LUANTI_ROOT}/cmake/Modules)
    add_subdirectory(${VOXERA_LUANTI_ROOT} ${CMAKE_BINARY_DIR}/luanti EXCLUDE_FROM_ALL)

    target_link_libraries(entry PRIVATE luanti)
    target_compile_definitions(entry PRIVATE VOXERA_LINK_LUANTI=1)
    target_include_directories(entry PRIVATE ${VOXERA_LUANTI_ROOT}/src)
endif()
