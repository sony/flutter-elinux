cmake_minimum_required(VERSION 3.15)
set(PROJECT_NAME "native_texture_view")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "native_texture_view_plugin")

find_package(PkgConfig)
pkg_check_modules(GLIB REQUIRED glib-2.0)
pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0)
if(USE_EGL_IMAGE_DMABUF)
pkg_check_modules(GSTREAMER_GL REQUIRED gstreamer-gl-1.0)
endif()

add_library(${PLUGIN_NAME} SHARED
  "native_texture_view_plugin.cc"
  "native_texture_view_factory.cc"
  "native_texture_view.cc"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

target_include_directories(${PLUGIN_NAME}
  PRIVATE
    ${GLIB_INCLUDE_DIRS}
    ${GSTREAMER_INCLUDE_DIRS}
)
if(USE_EGL_IMAGE_DMABUF)
target_include_directories(${PLUGIN_NAME}
  PRIVATE
    ${GSTREAMER_GL_INCLUDE_DIRS}
)
endif()

target_link_libraries(${PLUGIN_NAME}
  PRIVATE
    ${GLIB_LIBRARIES}
    ${GSTREAMER_LIBRARIES}
)
if(USE_EGL_IMAGE_DMABUF)
target_link_libraries(${PLUGIN_NAME}
  PRIVATE
    ${GSTREAMER_GL_LIBRARIES}
)
endif()

# List of absolute paths to libraries that should be bundled with the plugin
set(native_texture_view_bundled_libraries
  ""
  PARENT_SCOPE
)
