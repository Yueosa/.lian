qt_add_library(ClavisNotif SHARED)

set_target_properties(ClavisNotif PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Notif
)

qt_add_qml_module(ClavisNotif
    URI Clavis.Notif
    VERSION 1.0
    SOURCES
        src/notification_list_model.h
        src/notification_list_model.cpp
        src/notification_store.h
        src/notification_store.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Notif
)

target_include_directories(ClavisNotif PRIVATE src)

target_link_libraries(ClavisNotif PRIVATE
    ClavisStore
    Qt6::Core
    Qt6::Qml
)

install(DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/Notif
    DESTINATION /usr/lib/qt6/qml/Clavis
)
