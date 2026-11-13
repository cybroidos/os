# The QML files sit at the module's root (not under qml/), so they see the
# module's own types (System, Theme) without importing it.
file(GLOB _qml RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} qml/*.qml)
foreach(f ${_qml})
    get_filename_component(n ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${n})
endforeach()
qt_add_executable(cybroid-camera main.cpp)
qt_add_qml_module(cybroid-camera
    URI Cybroid.Camera
    VERSION 1.0
    QML_FILES qml/Main.qml
)
target_include_directories(cybroid-camera PRIVATE ${CMAKE_SOURCE_DIR}/common)
target_link_libraries(cybroid-camera PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network Qt6::Multimedia)
install(TARGETS cybroid-camera RUNTIME DESTINATION bin COMPONENT cybroid-camera)
install(FILES cybroid-camera.desktop DESTINATION share/applications COMPONENT cybroid-camera)
