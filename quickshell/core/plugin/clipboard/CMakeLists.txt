qt_add_library(ClavisClipboard SHARED)

set_target_properties(ClavisClipboard PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Clipboard
)

qt_add_qml_module(ClavisClipboard
    URI Clavis.Clipboard
    VERSION 1.0
    SOURCES
        src/clipboard_list_model.h
        src/clipboard_list_model.cpp
        src/clipboard_store.h
        src/clipboard_store.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Clipboard
)

target_include_directories(ClavisClipboard PRIVATE src)

target_link_libraries(ClavisClipboard PRIVATE
    ClavisStore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

install(DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Clipboard
    DESTINATION /usr/lib/qt6/qml/Clavis
)
