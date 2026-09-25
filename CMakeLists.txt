cmake_minimum_required(VERSION 3.28)

project(morph-shell VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Quick ShaderTools)

qt_standard_project_setup(REQUIRES 6.6)

# Where the built QML module lands in the build tree, and where it is
# installed relative to the prefix.
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
set(MORPH_QML_DIR "lib/qt-6/qml" CACHE STRING "QML module install dir")
set(MORPH_QSCONFDIR "share/morph-shell" CACHE STRING "Quickshell config install dir")

add_subdirectory(plugin)

install(
    DIRECTORY
        "${CMAKE_SOURCE_DIR}/components"
        "${CMAKE_SOURCE_DIR}/config"
        "${CMAKE_SOURCE_DIR}/modules"
        "${CMAKE_SOURCE_DIR}/services"
        "${CMAKE_SOURCE_DIR}/utils"
        "${CMAKE_SOURCE_DIR}/assets"
    DESTINATION "${MORPH_QSCONFDIR}"
)

install(
    FILES "${CMAKE_SOURCE_DIR}/shell.qml"
    DESTINATION "${MORPH_QSCONFDIR}"
)

install(
    FILES "${CMAKE_SOURCE_DIR}/LICENSE"
    DESTINATION "share/licenses/morph-shell"
)
