qt_add_library(ClavisLianwall SHARED)

set_target_properties(ClavisLianwall PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Lianwall
)

qt_add_qml_module(ClavisLianwall
    URI Clavis.Lianwall
    VERSION 1.0
    SOURCES
        src/lianwall_list_model.h
        src/lianwall_list_model.cpp
        src/lianwall_plugin.h
        src/lianwall_plugin.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Lianwall
)

target_include_directories(ClavisLianwall PRIVATE src)

target_link_libraries(ClavisLianwall PRIVATE
    Qt6::Core
    Qt6::Qml
)

install(DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Lianwall
    DESTINATION /usr/lib/qt6/qml/Clavis
)