# The QML files sit at the module's root (not under qml/), so they see the
# module's own types (System, Theme) without importing it.
file(GLOB _qml RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} qml/*.qml)
foreach(f ${_qml})
    get_filename_component(n ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${n})
endforeach()
# Cybroid.Ui: one plugin holding the shared QML controls and the System
# singleton, installed where Qt finds QML modules.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(cybroidui
    URI Cybroid.Ui
    VERSION 1.0
    PLUGIN_TARGET cybroidui
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml/Cybroid/Ui
    SOURCES system.h system.cpp
    QML_FILES
        qml/Theme.qml
        qml/Surface.qml
        qml/Label.qml
        qml/Section.qml
        qml/Card.qml
        qml/SettingRow.qml
        qml/Toggle.qml
        qml/Slide.qml
        qml/Btn.qml
        qml/Field.qml
        qml/Segmented.qml
        qml/Choice.qml
        qml/SettingsPage.qml
)
target_link_libraries(cybroidui PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::DBus)

install(TARGETS cybroidui LIBRARY DESTINATION ${CYBROID_QML_DIR}/Cybroid/Ui COMPONENT cybroid-ui)
install(FILES
    ${CMAKE_BINARY_DIR}/qml/Cybroid/Ui/qmldir
    ${CMAKE_BINARY_DIR}/qml/Cybroid/Ui/cybroidui.qmltypes
    DESTINATION ${CYBROID_QML_DIR}/Cybroid/Ui COMPONENT cybroid-ui)
