cmake_minimum_required(VERSION 3.16)

project(RK50012_pH VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# Incluimos SerialPort para la comunicación RS485
find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick SerialPort)

qt_standard_project_setup()

# Agregar los archivos de librería y la lógica principal
qt_add_executable(appRK50012_pH
    main.cpp
    SensorPH.h
    SensorPH.cpp
)

# Registrar los archivos de la interfaz Qt Quick (QML)
qt_add_qml_module(appRK50012_pH
    URI RK50012_pH
    VERSION 1.0
    QML_FILES
        main.qml
)

# Forzar la inclusión del archivo en el sistema de recursos
qt6_add_resources(appRK50012_pH "qml_res"
    PREFIX "/qt/qml/RK50012_pH"
    FILES
        main.qml
)
# Vincular las librerías al ejecutable
# Esto permite que C++ use Q_INVOKABLE y se comunique con el puerto serial
target_link_libraries(appRK50012_pH
    PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::SerialPort
)

#  Configuración de despliegue
install(TARGETS appRK50012_pH
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
