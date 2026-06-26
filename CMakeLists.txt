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
find_package(Qt6 REQUIRED COMPONENTS Quick Charts SerialPort Multimedia)
find_package(Qt6 OPTIONAL_COMPONENTS LinguistTools)

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
        # ── Pantallas ──────────────────────────────────────────────────────────
        qml/screens/Main.qml
        qml/screens/PantallaCarga.qml
        qml/screens/PantallaError.qml
        qml/screens/PantallaPrincipal.qml
        qml/screens/PantallaAjustes.qml
        qml/screens/PantallaNuevoProyecto.qml
        qml/screens/Pantalla6.qml
        qml/screens/Pantalla7.qml
        qml/screens/PantallaPreparacion.qml
        qml/screens/PantallaProcesos.qml
        qml/screens/PantallaProyectosGuardados.qml
        qml/screens/PantallaConfigGraficas.qml
        qml/screens/PantallaPostProceso.qml
        qml/screens/PantallaExtraccion.qml
        qml/screens/PantallaGuardarConfig.qml
        qml/screens/PantallaLimpieza.qml
        qml/screens/PantallaRegistro.qml
        qml/screens/PantallaPruebaPH.qml
        # ── Componentes reutilizables ──────────────────────────────────────────
        qml/components/BotonAccionVerde.qml
        qml/components/BarraDisplaySensor.qml
        qml/components/BarraInputConfig.qml
        qml/components/CabeceraPersistente.qml
        qml/components/TecladoQwerty.qml
        qml/components/TecladoNumerico.qml
        qml/components/GraficaChart.qml
        qml/components/TarjetaProyecto.qml
        # ── Popups ─────────────────────────────────────────────────────────────
        qml/popups/PopupIngresoNombre.qml
        qml/popups/PopupConfirmarProceso.qml
        qml/popups/PopupOpcionesProyecto.qml
        qml/popups/PopupBorrarProyecto.qml
        qml/popups/PopupEdicionProyecto.qml
        qml/popups/PopupConfirmarEdicion.qml
    SOURCES
        src/backend/translationmanager.h    src/backend/translationmanager.cpp
        src/backend/gestorbiorreactor.h     src/backend/gestorbiorreactor.cpp
        src/backend/gestoraudio.h           src/backend/gestoraudio.cpp
        src/controllers/controladorpid.h    src/controllers/controladorpid.cpp
        src/controllers/controladorfuzzy.h  src/controllers/controladorfuzzy.cpp
        src/controllers/controladorhisteresis.h src/controllers/controladorhisteresis.cpp
        src/drivers/driverpca9685.h         src/drivers/driverpca9685.cpp
        src/drivers/driverxm125.h           src/drivers/driverxm125.cpp
        src/drivers/raspberrypi_config.h
)

# 3. Rutas de include — permite que los #include usen solo el nombre de archivo
target_include_directories(appPrototipo PRIVATE
    src/backend
    src/controllers
    src/drivers
)

# 4. Recursos de imagen — PREFIX por subcarpeta para que los QML los encuentren
#    con rutas relativas (QML en qml/screens/ busca en .../qml/screens/, etc.)
qt_add_resources(appPrototipo "imagesComponents"
    PREFIX "/qt/qml/Prototipo/qml/components"
    BASE "assets"
    FILES
        assets/Logo_IPN.png
        assets/Logo_UPIIZ.png
        assets/Logo_ENCB.png
)

qt_add_resources(appPrototipo "imagesScreens"
    PREFIX "/qt/qml/Prototipo/qml/screens"
    BASE "assets"
    FILES
        assets/Alerta.png
        assets/Engrane.png
        assets/Play_Pause.png
        assets/Basura.png
        assets/Lapiz.png
        assets/Hongo_1.png
        assets/Hongo_2.png
        assets/Hongo_3.png
        assets/Hongo_4.png
        assets/Hongo_5.png
        assets/Hongo_6.png
        assets/Hongo_7.png
        assets/Hongo_8.png
        assets/Hongo_9.png
)

qt_add_resources(appPrototipo "imagesPopups"
    PREFIX "/qt/qml/Prototipo/qml/popups"
    BASE "assets"
    FILES
        assets/Basura.png
        assets/Lapiz.png
)

# 5. Recursos de audio (WAV embebidos en el binario bajo el prefijo /audio)
qt_add_resources(appPrototipo "audioRes"
    PREFIX "/audio"
    BASE "audio"
    FILES
        audio/alerta.wav
        audio/advertencia.wav
        audio/exito.wav
        audio/inicio.wav
)

# 6. Traducciones
if(Qt6LinguistTools_FOUND)
    qt_add_translations(appPrototipo
        TS_FILES
            translations/appPrototipo_en.ts
            translations/appPrototipo_de.ts
            translations/appPrototipo_fr.ts
            translations/appPrototipo_zh.ts
            translations/appPrototipo_ja.ts
        RESOURCE_PREFIX "/i18n"
    )
else()
    message(STATUS "LinguistTools no encontrado — usando .qm precompilados")
    qt_add_resources(appPrototipo "i18nRes"
        PREFIX "/i18n"
        BASE "translations"
        FILES
            translations/appPrototipo_en.qm
            translations/appPrototipo_de.qm
            translations/appPrototipo_fr.qm
            translations/appPrototipo_zh.qm
            translations/appPrototipo_ja.qm
    )
endif()

# Configuraciones extra
set_target_properties(appPrototipo PROPERTIES
#   MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appPrototipo
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appPrototipo
    PRIVATE Qt6::Quick Qt6::Charts Qt6::Core Qt6::SerialPort Qt6::Multimedia
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
    LIBRARY DESTINATION ${CMAKE_INSTALL_BINDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
