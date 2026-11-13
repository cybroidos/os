# The QML files sit at the module's root (not under qml/), so they see the
# module's own types (System, Theme) without importing it.
file(GLOB _qml RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} qml/*.qml)
foreach(f ${_qml})
    get_filename_component(n ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${n})
endforeach()
qt_add_executable(cybroid-settings main.cpp)
qt_add_qml_module(cybroid-settings
    URI Cybroid.Settings
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/WifiPage.qml
        qml/SoundPage.qml
        qml/AppearancePage.qml
        qml/DateTimePage.qml
        qml/AboutPage.qml
        qml/BluetoothPage.qml
        qml/DisplaysPage.qml
        qml/PowerPage.qml
)
target_include_directories(cybroid-settings PRIVATE ${CMAKE_SOURCE_DIR}/common)
target_link_libraries(cybroid-settings PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network)
install(TARGETS cybroid-settings RUNTIME DESTINATION bin COMPONENT cybroid-settings)
install(FILES cybroid-settings.desktop DESTINATION share/applications COMPONENT cybroid-settings)
# Appearance's previews: screenshots of the desktop in each look (taken on
# the test VM at 1280×800, shown at 640×400).
install(DIRECTORY previews/ DESTINATION share/cybroid/settings/previews COMPONENT cybroid-settings)
