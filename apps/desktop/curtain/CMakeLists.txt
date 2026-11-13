# cybroid-curtain: covers the screens while the desktop restarts between
# designs (cybroid-appearance); in the cybroid-ui package.
file(GLOB _qml RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} qml/*.qml)
foreach(f ${_qml})
    get_filename_component(n ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${n})
endforeach()
qt_add_executable(cybroid-curtain main.cpp)
qt_add_qml_module(cybroid-curtain URI Cybroid.Curtain VERSION 1.0 QML_FILES qml/Main.qml)
target_link_libraries(cybroid-curtain PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)
install(TARGETS cybroid-curtain RUNTIME DESTINATION libexec/cybroid COMPONENT cybroid-ui)
