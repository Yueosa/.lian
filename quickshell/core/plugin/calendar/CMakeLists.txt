qt_add_library(ClavisCalendar SHARED)

set_target_properties(ClavisCalendar PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Calendar
)

qt_add_qml_module(ClavisCalendar
    URI Clavis.Calendar
    VERSION 1.0
    SOURCES
        src/calendar_day_model.h
        src/calendar_day_model.cpp
        src/calendar_plugin.h
        src/calendar_plugin.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Calendar
)

qt_add_resources(ClavisCalendar "calendar_data"
    PREFIX "/Clavis/Calendar"
    FILES
        data/cn/2026.json
)

target_include_directories(ClavisCalendar PRIVATE src)

target_link_libraries(ClavisCalendar PRIVATE
    Qt6::Core
    Qt6::Qml
)

install(DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Calendar
    DESTINATION /usr/lib/qt6/qml/Clavis
)