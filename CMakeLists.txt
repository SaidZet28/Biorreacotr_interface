cmake_minimum_required(VERSION 3.16)

project(Prototipo VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_GENERATE_QMLLS_INI ON)

# Activar con: cmake -DSIMULACION=ON
# Genera datos sintéticos sin necesidad de hardware (Raspberry Pi / sensores)
option(SIMULACION "Modo simulación — sin hardware real" OFF)
if(SIMULACION)
    add_compile_definitions(SIMULACION_ACTIVA)
    message(STATUS ">>> MODO SIMULACIÓN ACTIVO — sin hardware real <<<")
endif()

# 1. Buscamos los paquetes requeridos
find_package(Qt6 REQUIRED COMPONENTS Quick Charts LinguistTools SerialPort)

if(MINGW)
    add_compile_options("-Wa,-mbig-obj")
endif()

qt_standard_project_setup(REQUIRES 6.5)

# 2. PRIMERO creamos el ejecutable y el módulo QML
qt_add_executable(appPrototipo
    main.cpp
)

qt_add_qml_module(appPrototipo
    URI Prototipo
    QML_FILES
        Main.qml
        BotonAccionVerde.qml
        BarraDisplaySensor.qml
        BarraInputConfig.qml
        CabeceraPersistente.qml
        PopupIngresoNombre.qml
        PopupConfirmarProceso.qml
        TecladoQwerty.qml
        TecladoNumerico.qml
        PantallaCarga.qml
        PantallaError.qml
        PantallaPrincipal.qml
        PantallaAjustes.qml
        PantallaNuevoProyecto.qml
        Pantalla6.qml
        Pantalla7.qml
        PantallaProcesos.qml
        GraficaChart.qml
        PantallaProyectosGuardados.qml
        TarjetaProyecto.qml
        PopupOpcionesProyecto.qml
        PopupBorrarProyecto.qml
        PopupEdicionProyecto.qml
        PopupConfirmarEdicion.qml
        PantallaConfigGraficas.qml
        PantallaPostProceso.qml
        PantallaExtraccion.qml
        PantallaGuardarConfig.qml
        PantallaLimpieza.qml
        PantallaRegistro.qml
    RESOURCES
        Logo_IPN.png
        Logo_UPIIZ.png
        Logo_ENCB.png

        Alerta.png
        Engrane.png
        Play_Pause.png
        Lapiz.png
        Basura.png

        Hongo_1.png
        Hongo_2.png
        Hongo_3.png
        Hongo_4.png
        Hongo_5.png
        Hongo_6.png
        Hongo_7.png
        Hongo_8.png
        Hongo_9.png
        SOURCES translationmanager.h translationmanager.cpp
                gestorbiorreactor.h gestorbiorreactor.cpp
                controladorpid.h controladorpid.cpp
                controladorfuzzy.h controladorfuzzy.cpp
                controladorhisteresis.h controladorhisteresis.cpp
                driverpca9685.h driverpca9685.cpp
                driverxm125.h driverxm125.cpp
                raspberrypi_config.h
)

# 3. AHORA SÍ, le agregamos las traducciones al ejecutable
qt_add_translations(appPrototipo
    TS_FILES
        appPrototipo_en.ts
        appPrototipo_de.ts
        appPrototipo_fr.ts
        appPrototipo_zh.ts
        appPrototipo_ja.ts
    RESOURCE_PREFIX "/i18n"
)

# Configuraciones extra
set_target_properties(appPrototipo PROPERTIES
#   MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appPrototipo
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appPrototipo
    PRIVATE Qt6::Quick Qt6::Charts Qt6::Core Qt6::SerialPort
)

# En Raspberry Pi: enlazar pigpio (GPIO) y pthread
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_library(PIGPIO_LIB pigpio)
    if(PIGPIO_LIB)
        target_link_libraries(appPrototipo PRIVATE ${PIGPIO_LIB} pthread)
        message(STATUS "pigpio encontrado: ${PIGPIO_LIB}")
    else()
        message(WARNING "pigpio no encontrado — sin control GPIO de cruce por cero")
    endif()
endif()

install(TARGETS appPrototipo
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)