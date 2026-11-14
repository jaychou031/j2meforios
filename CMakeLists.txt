cmake_minimum_required(VERSION 3.24)
project(J2MEForIOS VERSION 0.1.8 LANGUAGES C CXX OBJCXX)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
  message(FATAL_ERROR "Configure with -DCMAKE_SYSTEM_NAME=iOS and an Apple toolchain")
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD 17)
set(UPSTREAM "${CMAKE_CURRENT_SOURCE_DIR}/upstream/esp32s31-korvo-nano-j2me")
set(CORE "${UPSTREAM}/third_party/nano_j2me")
foreach(option NJ_BUILD_TESTS NJ_BUILD_CLI NJ_BUILD_SDL2 NJ_BUILD_LIBRETRO NJ_BUILD_EMBEDDED_PORTS NJ_BUILD_POSIX_NETWORK)
  set(${option} OFF CACHE BOOL "" FORCE)
endforeach()
set(NJ_ENABLE_JIT 0 CACHE STRING "" FORCE)
set(NJ_ENABLE_MEDIA 1 CACHE STRING "" FORCE)
set(NJ_PIXFMT NJ_PIXFMT_ARGB8888 CACHE STRING "" FORCE)
set(NJ_THREADED_DISPATCH 1 CACHE STRING "" FORCE)
add_subdirectory("${CORE}" core)
include(cmake/CoreCompatibility.cmake)
j2me_apply_core_compatibility(nj2me "${CORE}")
# The upstream headless port defines _POSIX_C_SOURCE before sys/mman.h.
# Darwin hides MAP_ANONYMOUS in that strict mode unless its extensions are
# explicitly enabled. This port is compiled even with JIT disabled.
target_compile_definitions(nj2me PRIVATE _DARWIN_C_SOURCE=1)
# nj_config.h includes nj_libc.h before assigning NJ_USE_LIBC its default.
# Set it on the command line so the core and its ObjC++ consumers use Apple's
# hosted headers instead of the freestanding C declarations.
target_compile_definitions(nj2me PUBLIC NJ_USE_LIBC=1)
set(DEMO "${UPSTREAM}/assets/korvo_demo.jar")
set(CORE_LICENSE "${CORE}/LICENSE")
set_source_files_properties("${DEMO}" "${CORE_LICENSE}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
add_executable(J2MEForIOS MACOSX_BUNDLE ios/App.mm ios/NJSession.mm ios/AudioOutput.mm ios/GameStorage.mm "${DEMO}" "${CORE_LICENSE}")
set(APP_ICONS "${CMAKE_CURRENT_SOURCE_DIR}/ios/Assets.xcassets")
set_source_files_properties("${APP_ICONS}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
target_sources(J2MEForIOS PRIVATE "${APP_ICONS}")
set(SOUNDFONT "${CMAKE_CURRENT_SOURCE_DIR}/ios/SoundFont/GeneralUser-GS-SoftSynth-1.44.sf2")
set(SOUNDFONT_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/ios/SoundFont/GeneralUser-LICENSE.txt")
set(TSF_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/third_party/TinySoundFont/LICENSE")
set_source_files_properties("${SOUNDFONT}" "${SOUNDFONT_LICENSE}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
# Give the two upstream LICENSE files distinct bundle names/directories.
set_source_files_properties("${TSF_LICENSE}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources/TinySoundFont)
target_sources(J2MEForIOS PRIVATE "${SOUNDFONT}" "${SOUNDFONT_LICENSE}" "${TSF_LICENSE}")
target_include_directories(J2MEForIOS PRIVATE ios "${CORE}/src/port/posix")
target_compile_options(J2MEForIOS PRIVATE -fobjc-arc -Wall -Wextra)
target_link_libraries(J2MEForIOS PRIVATE nj2me "-framework UIKit" "-framework Foundation" "-framework CoreGraphics" "-framework QuartzCore" "-framework AVFoundation" "-framework AudioToolbox" "-framework UniformTypeIdentifiers")
set_target_properties(J2MEForIOS PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "org.nanoj2me.ios"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"
  XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
  XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
  XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES")
