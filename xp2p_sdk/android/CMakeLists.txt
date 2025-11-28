cmake_minimum_required(VERSION 3.10)
project(xp2p_bridge)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ==================== Dart SDK 配置 ====================
if(DEFINED ENV{FLUTTER_HOME})
    set(FLUTTER_ROOT "$ENV{FLUTTER_HOME}")
else()
    set(FLUTTER_ROOT "$ENV{HOME}/Library/flutter")  # macOS Flutter 安装位置
endif()

set(DART_SDK_ROOT "${FLUTTER_ROOT}/bin/cache/dart-sdk")

message(STATUS "Flutter Root: ${FLUTTER_ROOT}")
message(STATUS "Dart SDK Root: ${DART_SDK_ROOT}")

include_directories(
    "${DART_SDK_ROOT}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/include"  # 备用
)

# ==================== 共享源代码 ====================
# 引用顶层 src/ 目录的代码
set(BRIDGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../src")

include_directories("${BRIDGE_SOURCE_DIR}")

# ==================== 已有的 so ====================
set(XP2P_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/libs/${ANDROID_ABI}")

add_library(xp2p SHARED IMPORTED)
set_target_properties(xp2p PROPERTIES IMPORTED_LOCATION 
    "${XP2P_LIB_DIR}/libiot_video_demo.so")

# ==================== 创建桥接库 ====================
add_library(xp2p_bridge SHARED
    "${BRIDGE_SOURCE_DIR}/dart_bridge.cpp"  # 引用共享代码
    "${BRIDGE_SOURCE_DIR}/include/dart_api_dl.c"  # Dart API DL 实现
)

target_compile_definitions(xp2p_bridge PRIVATE __ANDROID__)

target_link_libraries(xp2p_bridge
    xp2p
    android
    log
)

# 输出到 libs 目录
set_target_properties(xp2p_bridge PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${XP2P_LIB_DIR}"
)
