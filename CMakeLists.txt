cmake_minimum_required(VERSION 3.29)

project(Chinchilla LANGUAGES Swift VERSION 0.0.1 DESCRIPTION "栗鼠输入法")

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake" ${CMAKE_MODULE_PATH})

set(ARCH "native" CACHE STRING "Architecture to build")

set(VALID_ARCH native x86_64 arm64)

if(NOT ARCH IN_LIST VALID_ARCH)
    message(FATAL_ERROR "Invalid ARCH")
endif()

if(NOT ARCH STREQUAL "native")
    add_compile_options(-target "${ARCH}-apple-macos13")
endif()

set(MACOSX_BUNDLE_BUNDLE_NAME ${PROJECT_NAME})
set(MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION})
set(MACOSX_BUNDLE_INFO_STRING ${PROJECT_DESCRIPTION})
set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")

include_directories("Sources/CRime")
link_directories("Sources/CRime/lib")

file(GLOB CHINCHILLA_SOURCES Sources/**/*.swift)

add_executable(Chinchilla MACOSX_BUNDLE ${CHINCHILLA_SOURCES})

target_link_libraries(Chinchilla "rime")

set(APP_PATH "${CMAKE_CURRENT_BINARY_DIR}/Chinchilla.app/Contents")

add_custom_command(TARGET Chinchilla POST_BUILD
    COMMAND mkdir -p "${APP_PATH}/{Resources,Frameworks,SharedSupport}"
    COMMAND cp -r Sources/CRime/lib/* "${APP_PATH}/Frameworks"
    COMMAND cp assets/{AppIcon.icns,MenuIcon.pdf} "${APP_PATH}/Resources"
    COMMAND cp -r assets/{en,zh-Hans,Base}.lproj "${APP_PATH}/Resources"
    COMMAND rm -f "${APP_PATH}/MacOS/Chinchilla.d"
    # COMMAND "BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}" dmgbuild -s dmg/config.py Chinchilla "${CMAKE_CURRENT_BINARY_DIR}/Chinchilla.dmg"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

install(TARGETS Chinchilla DESTINATION "~/Library/Input Methods")
