cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# 在现有的 CMakeLists.txt 中添加
# 正确使用file(GLOB)解析通配符，获取所有匹配的DLL文件
file(GLOB EXTRA_DLLS
    "${CMAKE_CURRENT_SOURCE_DIR}/../../assets/bin/*.so"
)

# 检查是否找到DLL文件
message(STATUS "找到的DLL文件数量: ${CMAKE_ARGC}")
# 逐个复制DLL文件到输出目录
foreach(dll ${EXTRA_DLLS})
    message(STATUS "正在复制DLL: ${dll}")
    add_custom_command(
        TARGET ${BINARY_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${dll}"
        "$<TARGET_FILE_DIR:${BINARY_NAME}>"
    )
endforeach()
