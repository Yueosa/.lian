qt_add_library(ClavisLianClaw SHARED)

set_target_properties(ClavisLianClaw PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/LianClaw
)

qt_add_qml_module(ClavisLianClaw
    URI Clavis.LianClaw
    VERSION 1.0
    SOURCES
        src/lianclaw_client.h
        src/lianclaw_client.cpp
        src/sse_stream.h
        src/sse_stream.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/LianClaw
)

target_include_directories(ClavisLianClaw PUBLIC src)

target_link_libraries(ClavisLianClaw PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Qml
)

install(DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/LianClaw
    DESTINATION /usr/lib/qt6/qml/Clavis
)
