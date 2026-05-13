cmake_minimum_required(VERSION 3.16)

project(RK50004_DO VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick SerialPort)

qt_standard_project_setup()

qt_add_executable(appRK50004_DO
    main.cpp
    sensordo.h
    sensordo.cpp
)

qt_add_qml_module(appRK50004_DO
    URI RK50004_DO
    VERSION 1.0
    QML_FILES
        main.qml
)

qt6_add_resources(appRK50004_DO "qml_res"
    PREFIX "/qt/qml/RK50004_DO"
    FILES
        main.qml
)

target_link_libraries(appRK50004_DO
    PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::SerialPort
)

install(TARGETS appRK50004_DO
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
