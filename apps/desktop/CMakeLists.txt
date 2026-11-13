# CybroidOS's own desktop apps (Qt 6, QML on native C++), built for Debian 13.
#   Cybroid.Ui        the shared controls, theme and system layer (cybroid-ui)
#   cybroid-settings  Settings
#   cybroid-camera    Camera
# Each app's packaging is in common/packages/<name>; tools/build-native.sh
# builds and stages them.
cmake_minimum_required(VERSION 3.25)
project(cybroid-desktop-apps VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network Multimedia)
qt_standard_project_setup(REQUIRES 6.5)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Where Debian's Qt looks for QML modules (lib/<multiarch>/qt6/qml).
set(CYBROID_QML_DIR "${QT6_INSTALL_QML}")

add_subdirectory(ui)
add_subdirectory(settings)
add_subdirectory(camera)
add_subdirectory(curtain)
