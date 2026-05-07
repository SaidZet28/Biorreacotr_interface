import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    id: mainWindow
    visible: true
    width: 1280
    height: 800
    title: qsTr("Interfaz de Biorreactor - UPIIZ")
    color: "#FFFFFF"

    // ==========================================
    // 1. LÓGICA CENTRAL Y GESTIÓN DE ESTADOS
    // ==========================================
    // estadoActual controla la navegación de la HMI.
    property string estadoActual: "pantalla_de_carga"

    property string estadoPrevioAjustes: "pantalla_principal"
    property string estadoPrevioPantalla6: "pantalla_nuevo_proyecto"

    property int sensor_estado_primero: 1
    property int sensor_estado_calibracion: 1
    property string estado_sensor_retorno_error: "pantalla_de_carga"
    property string textoMensajeError: qsTr("Falla en sensor")

    // --- Configuraciones Globales ---
    property string idiomaActual: "Español"
    property string unidadTemperatura: "C"

    // Bandera para nueva configuración de mismo experimento
    property bool omitirPedirNombre: false

    // --- Variables de Identificación de Proyecto ---
    property string var_nombre_proyecto: ""
    property string var_nombre_experimento: ""

    property int var_seleccion_grafica: 1 // 1: Temp, 2: Agua, 3: pH, 4: Luz
    property int var_vaciado_nivel_1: 5000
    property int var_vaciado_nivel_2: 5000

    // --- Lecturas actuales de sensores ---
    property real var_sensor_Tem: 24.5
    property real var_sensor_pH: 7.2
    property real var_sensor_Agua: 85.0
    property real var_sensor_Luz: 60.0
    property real var_sensor_CO2: 400.0

    // --- Setpoints (Valores deseados) ---
    property real var_deseada_Tem: 0.0
    property real var_deseada_pH: 0.0
    property real var_deseada_Agua: 0.0
    property real var_deseada_Luz: 0.0
    property real var_deseada_CO2: 0.0

    // --- Control de Tiempo ---
    property real var_deseada_tiempo_semanas: 0.0
    property real var_deseada_tiempo_dias: 0.0
    property real var_deseada_tiempo_horas: 0.0
    property real var_deseada_tiempo_minutos: 0.0
    property real var_deseada_tiempo_total_horas: 0.0

    // ==========================================
    // 2. FUNCIONES GLOBALES
    // ==========================================
    function limpiarDatos(mantenerNombres) {
        if (!mantenerNombres) {
            var_nombre_proyecto = ""
            var_nombre_experimento = ""
        }

        var_deseada_Tem = 0.0
        var_deseada_pH = 0.0
        var_deseada_Agua = 0.0
        var_deseada_Luz = 0.0
        var_deseada_tiempo_semanas = 0.0
        var_deseada_tiempo_dias = 0.0
        var_deseada_tiempo_horas = 0.0
        var_deseada_tiempo_minutos = 0.0
        var_deseada_tiempo_total_horas = 0.0

        pantalla6.tempConfigurada = false
        pantalla6.phConfigurado = false
        pantalla6.aguaConfigurada = false
        pantalla6.luzConfigurada = false
        pantalla6.tiempoConfigurado = false

        pantalla6.campoActivo = ""
        pantalla6.entradaTemporal = ""
    }

    // ==========================================
    // 3. BASES DE DATOS LOCALES
    // ==========================================
    ListModel {
        id: datos_guardados
        ListElement { nombre: "Cultivo Fresa"; temp: 24.5; ph: 6.0; agua: 80.0; luz: 50.0; tiempo: "168.0" }
        ListElement { nombre: "Cultivo Alga"; temp: 26.0; ph: 7.5; agua: 90.0; luz: 60.0; tiempo: "336.0" }
        ListElement { nombre: "Cepa X-12"; temp: 22.0; ph: 6.8; agua: 75.0; luz: 80.0; tiempo: "72.0" }
        ListElement { nombre: "Prueba Levadura"; temp: 25.0; ph: 4.5; agua: 50.0; luz: 0.0; tiempo: "48.0" }
        ListElement { nombre: "Proyecto Beta"; temp: 30.0; ph: 7.0; agua: 100.0; luz: 90.0; tiempo: "12.0" }
    }

    ListModel {
        id: registro_experimentos
        ListElement { proyecto: "Cepa X-12"; experimento: "Beta-1"; fecha: "20/03/2026"; tiempo: "72.0 / 72.0 hrs"; peso: "1.2 MB"; seleccionado: false }
        ListElement { proyecto: "Cultivo Fresa"; experimento: "Fase 2"; fecha: "21/03/2026"; tiempo: "160.0 / 168.0 hrs"; peso: "0.8 MB"; seleccionado: false }
        ListElement { proyecto: "Prueba Levadura"; experimento: "Muestra A"; fecha: "22/03/2026"; tiempo: "24.5 / 48.0 hrs"; peso: "0.5 MB"; seleccionado: false }
    }

    // ==========================================
    // ==========================================
    // 4. COMPONENTES REUTILIZABLES (archivos externos)
    // ==========================================

    CabeceraPersistente {}

    // ==========================================
    // ESTADOS / PANTALLAS
    // ==========================================

    // 1. PANTALLA DE CARGA
    Item {
        id: pantallaCarga
        anchors.fill: parent
        visible: estadoActual === "pantalla_de_carga"

        Column {
            anchors.centerIn: parent
            spacing: 20
            Text {
                text: qsTr("Cargando")
                font.pixelSize: 64
                font.bold: true
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: pantallaCarga.visible
            }
        }

        Timer {
            interval: 3000
            running: pantallaCarga.visible
            onTriggered: {
                if (sensor_estado_primero === 1) {
                    estadoActual = "pantalla_principal"
                } else {
                    estado_sensor_retorno_error = "pantalla_de_carga"
                    textoMensajeError = qsTr("Falla en sensor")
                    estadoActual = "pantalla_de_error"
                }
            }
        }
    }

    // 2. PANTALLA DE ERROR
    Item {
        id: pantallaError
        anchors.fill: parent
        visible: estadoActual === "pantalla_de_error"

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -mainWindow.height * 0.05
            spacing: mainWindow.height * 0.04

            Image {
                source: "Alerta.png"
                height: mainWindow.height * 0.35
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: qsTr("Se detectó un error :(")
                font.pixelSize: mainWindow.height * 0.08
                font.bold: true
                color: "black"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15
                Text {
                    text: qsTr("Error:")
                    font.pixelSize: mainWindow.height * 0.06
                    font.bold: true
                    color: "black"
                }
                Text {
                    text: textoMensajeError
                    font.pixelSize: mainWindow.height * 0.06
                    color: "black"
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: mainWindow.width * 0.08
            anchors.bottomMargin: mainWindow.height * 0.08
            width: mainWindow.width * 0.20
            height: mainWindow.height * 0.10
            color: areaOkError.pressed ? "#7b3ce6" : "#8b5cf6"
            radius: height / 2

            Text {
                anchors.centerIn: parent
                text: qsTr("Okay")
                color: "black"
                font.pixelSize: parent.height * 0.40
                font.bold: true
            }
            MouseArea {
                id: areaOkError
                anchors.fill: parent
                onClicked: estadoActual = estado_sensor_retorno_error
            }
        }
    }

    // 3. PANTALLA PRINCIPAL
    Item {
        id: pantallaPrincipal
        anchors.fill: parent
        visible: estadoActual === "pantalla_principal"

        Image {
            source: "Hongo_3.png"
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: parent.width * 0.02
            width: parent.width * 0.11
            fillMode: Image.PreserveAspectFit
        }

        Column {
            id: columnaBarrasPrincipales
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.05
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: mainWindow.height * 0.03
            spacing: parent.height * 0.03

            BarraDisplaySensor { textoEtiqueta: qsTr("Temperatura:"); textoValor: qsTr("%1 °%2").arg(var_sensor_Tem.toFixed(1)).arg(mainWindow.unidadTemperatura) }
            BarraDisplaySensor { textoEtiqueta: qsTr("Nivel de pH:"); textoValor: qsTr("%1").arg(var_sensor_pH.toFixed(1)) }
            BarraDisplaySensor { textoEtiqueta: qsTr("Nivel de agua:"); textoValor: qsTr("%1 %").arg(var_sensor_Agua.toFixed(0)) }
            BarraDisplaySensor { textoEtiqueta: qsTr("Nivel de luz:"); textoValor: qsTr("%1 %").arg(var_sensor_Luz.toFixed(0)) }
            BarraDisplaySensor { textoEtiqueta: qsTr("Nivel de CO2:"); textoValor: qsTr("%1 ppm").arg(var_sensor_CO2.toFixed(0)) }
        }

        Column {
            anchors.left: parent.left
            anchors.right: columnaBarrasPrincipales.left
            anchors.top: columnaBarrasPrincipales.top
            spacing: columnaBarrasPrincipales.spacing

            BotonAccionVerde {
                anchors.horizontalCenter: parent.horizontalCenter
                textoBoton: qsTr("Nuevo Proyecto")
                onClicado: {
                    omitirPedirNombre = false;
                    estadoActual = "pantalla_nuevo_proyecto";
                }
            }
            BotonAccionVerde {
                anchors.horizontalCenter: parent.horizontalCenter
                textoBoton: qsTr("Datos Guardados")
                onClicado: {
                    omitirPedirNombre = false;
                    estadoActual = "pantalla_15";
                }
            }
        }

        Rectangle {
            id: botonAjustes
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.width * 0.05
            anchors.bottomMargin: mainWindow.height * 0.04
            width: mainWindow.width * 0.09
            height: mainWindow.height * 0.11
            radius: width * 0.35
            color: areaMouseEngrane.pressed ? "#9ca3af" : "#B3B3B3"

            Image {
                source: "Engrane.png"
                anchors.centerIn: parent
                width: parent.width * 0.65
                height: parent.height * 0.65
                fillMode: Image.PreserveAspectFit
            }
            MouseArea {
                id: areaMouseEngrane
                anchors.fill: parent
                onClicked: {
                    estadoPrevioAjustes = "pantalla_principal"
                    estadoActual = "pantalla_configuraciones"
                }
            }
        }
    }

    // 4. PANTALLA DE CONFIGURACIONES
        Item {
            id: pantallaAjustes
            anchors.fill: parent
            visible: estadoActual === "pantalla_configuraciones"

            // Variables temporales para los popups
            property bool mostrarPopupIdioma: false
            property string tempIdioma: mainWindow.idiomaActual

            property bool mostrarPopupUnidades: false
            property string tempUnidades: mainWindow.unidadTemperatura

            property bool mostrarPopupCreditos: false

            // Título
            Text {
                text: qsTr("Configuraciones")
                font.pixelSize: mainWindow.height * 0.08
                font.bold: true
                color: "black"
                anchors.top: parent.top
                anchors.topMargin: mainWindow.height * 0.15
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Botones de Configuración
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: mainWindow.height * 0.05
                spacing: mainWindow.height * 0.05

                BotonAccionVerde {
                    textoBoton: qsTr("Idioma: %1").arg(qsTr(mainWindow.idiomaActual))
                    onClicado: {
                        pantallaAjustes.tempIdioma = mainWindow.idiomaActual;
                        pantallaAjustes.mostrarPopupIdioma = true;
                    }
                }
                BotonAccionVerde {
                    textoBoton: qsTr("Unidades: °%1").arg(mainWindow.unidadTemperatura)
                    onClicado: {
                        pantallaAjustes.tempUnidades = mainWindow.unidadTemperatura;
                        pantallaAjustes.mostrarPopupUnidades = true;
                    }
                }
                BotonAccionVerde {
                    textoBoton: qsTr("Créditos")
                    onClicado: pantallaAjustes.mostrarPopupCreditos = true
                }
            }

            // Botón Atrás
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: parent.width * 0.05
                width: parent.width * 0.12
                height: parent.height * 0.10
                color: areaAtrasAjustes.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: "↶"
                    color: "black"
                    font.pixelSize: parent.height * 0.70
                    font.bold: true
                }
                MouseArea {
                    id: areaAtrasAjustes
                    anchors.fill: parent
                    onClicked: estadoActual = estadoPrevioAjustes
                }
            }

            // --- POPUP: IDIOMA ---
                    Item {
                        anchors.fill: parent
                        z: 200
                        visible: pantallaAjustes.mostrarPopupIdioma
                        MouseArea { anchors.fill: parent; hoverEnabled: true }

                        Rectangle {
                            width: parent.width * 0.65
                            height: parent.height * 0.65
                            anchors.centerIn: parent
                            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                            radius: 20

                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: parent.height * 0.08
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Seleccione el Idioma")
                                font.pixelSize: parent.height * 0.08
                                font.bold: true
                                color: "black"
                            }

                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: mainWindow.width * 0.05
                                rowSpacing: mainWindow.height * 0.03

                                Repeater {
                                    // Aquí está la magia: separamos el nombre interno del nombre traducido
                                    model: [
                                        { original: "Español", traducido: qsTr("Español") },
                                        { original: "Inglés", traducido: qsTr("Inglés") },
                                        { original: "Alemán", traducido: qsTr("Alemán") },
                                        { original: "Francés", traducido: qsTr("Francés") },
                                        { original: "Chino", traducido: qsTr("Chino") },
                                        { original: "Japonés", traducido: qsTr("Japonés") }
                                    ]
                                    Rectangle {
                                        width: mainWindow.width * 0.22
                                        height: mainWindow.height * 0.08
                                        radius: height / 2
                                        color: pantallaAjustes.tempIdioma === modelData.original ? "#A5D6A7" : "white"
                                        border.color: "black"
                                        border.width: pantallaAjustes.tempIdioma === modelData.original ? 3 : 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.traducido
                                            font.pixelSize: parent.height * 0.45
                                            font.bold: true
                                            color: "black"
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: pantallaAjustes.tempIdioma = modelData.original
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: mainWindow.width * 0.15
                                height: mainWindow.height * 0.08
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.08
                                anchors.left: parent.left
                                anchors.leftMargin: parent.width * 0.15
                                color: areaOkIdioma.pressed ? "#6b42b5" : "#8b5cf6"
                                radius: height / 2
                                Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                MouseArea {
                                    id: areaOkIdioma
                                    anchors.fill: parent
                                    onClicked: {
                                        mainWindow.idiomaActual = pantallaAjustes.tempIdioma;

                                        if (mainWindow.idiomaActual === "Inglés") {
                                            TraductorC.cambiarIdioma("en");
                                        } else if (mainWindow.idiomaActual === "Alemán") {
                                            TraductorC.cambiarIdioma("de");
                                        } else if (mainWindow.idiomaActual === "Francés") {
                                            TraductorC.cambiarIdioma("fr");
                                        } else if (mainWindow.idiomaActual === "Chino") {
                                            TraductorC.cambiarIdioma("zh");
                                        } else if (mainWindow.idiomaActual === "Japonés") {
                                            TraductorC.cambiarIdioma("ja");
                                        } else {
                                            TraductorC.cambiarIdioma("es");
                                        }

                                        pantallaAjustes.mostrarPopupIdioma = false;
                                    }
                                }
                            }

                            Rectangle {
                                width: mainWindow.width * 0.15
                                height: mainWindow.height * 0.08
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.08
                                anchors.right: parent.right
                                anchors.rightMargin: parent.width * 0.15
                                color: areaAtrasIdioma.pressed ? "#cc1e1e" : "#FF2D2D"
                                radius: height / 2
                                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                                MouseArea { id: areaAtrasIdioma; anchors.fill: parent; onClicked: pantallaAjustes.mostrarPopupIdioma = false }
                            }
                        }
                    }

            // --- POPUP: UNIDADES ---
            Item {
                anchors.fill: parent
                z: 200
                visible: pantallaAjustes.mostrarPopupUnidades
                MouseArea { anchors.fill: parent; hoverEnabled: true }

                Rectangle {
                    width: parent.width * 0.65
                    height: parent.height * 0.55
                    anchors.centerIn: parent
                    color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                    radius: 20

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.10
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Unidades de Temperatura")
                        font.pixelSize: parent.height * 0.10
                        font.bold: true
                        color: "black"
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: mainWindow.width * 0.05

                        Repeater {
                            model: ["C", "F"]
                            Rectangle {
                                width: mainWindow.width * 0.20
                                height: mainWindow.height * 0.10
                                radius: height / 2
                                color: pantallaAjustes.tempUnidades === modelData ? "#A5D6A7" : "white"
                                border.color: "black"
                                border.width: pantallaAjustes.tempUnidades === modelData ? 3 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Grados °%1").arg(modelData)
                                    font.pixelSize: parent.height * 0.40
                                    font.bold: true
                                    color: "black"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: pantallaAjustes.tempUnidades = modelData
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: mainWindow.width * 0.15
                        height: mainWindow.height * 0.08
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.10
                        anchors.left: parent.left
                        anchors.leftMargin: parent.width * 0.15
                        color: areaOkUnidades.pressed ? "#6b42b5" : "#8b5cf6"
                        radius: height / 2
                        Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaOkUnidades
                            anchors.fill: parent
                            onClicked: {
                                if (mainWindow.unidadTemperatura === "C" && pantallaAjustes.tempUnidades === "F") {
                                    var_deseada_Tem = (var_deseada_Tem * 9/5) + 32;
                                    var_sensor_Tem = (var_sensor_Tem * 9/5) + 32;
                                } else if (mainWindow.unidadTemperatura === "F" && pantallaAjustes.tempUnidades === "C") {
                                    var_deseada_Tem = (var_deseada_Tem - 32) * 5/9;
                                    var_sensor_Tem = (var_sensor_Tem - 32) * 5/9;
                                }
                                mainWindow.unidadTemperatura = pantallaAjustes.tempUnidades;
                                pantallaAjustes.mostrarPopupUnidades = false;
                            }
                        }
                    }

                    Rectangle {
                        width: mainWindow.width * 0.15
                        height: mainWindow.height * 0.08
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.10
                        anchors.right: parent.right
                        anchors.rightMargin: parent.width * 0.15
                        color: areaAtrasUnidades.pressed ? "#cc1e1e" : "#FF2D2D"
                        radius: height / 2
                        Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                        MouseArea { id: areaAtrasUnidades; anchors.fill: parent; onClicked: pantallaAjustes.mostrarPopupUnidades = false }
                    }
                }
            }

            // --- POPUP: CRÉDITOS ---
            Item {
                id: popupCreditosRoot
                anchors.fill: parent
                z: 200
                visible: pantallaAjustes.mostrarPopupCreditos
                MouseArea { anchors.fill: parent; hoverEnabled: true }

                Rectangle {
                    id: cajaCreditos
                    width: parent.width * 0.75
                    height: parent.height * 0.75
                    anchors.centerIn: parent
                    color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                    radius: 20

                    Text {
                        id: tituloCreditos
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.08
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Créditos del Proyecto")
                        font.pixelSize: parent.height * 0.08
                        font.bold: true
                        color: "black"
                    }

                    Text {
                        anchors.top: tituloCreditos.bottom
                        anchors.topMargin: parent.height * 0.06
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.RichText
                        horizontalAlignment: Text.AlignHCenter
                        text: "<div align='center'><b>" + qsTr("Hecho por:") + "</b><br>" +
                              "Huang Sánchez Jet Ming Adrián<br>" +
                              "Júnez Huerta María Jimena<br>" +
                              "Zesati Márquez Jesús Said<br><br>" +
                              "<b>" + qsTr("Asesores:") + "</b><br>" +
                              "M. en I. Hernández González Umanel Azazael<br>" +
                              "M. en C. Mirelez Delgado Flabio Dario<br>" +
                              "M. en P. y M. Talavera Otero Jorge</div>"
                        font.pixelSize: parent.height * 0.045
                        color: "black"
                    }

                    Rectangle {
                        width: mainWindow.width * 0.20
                        height: mainWindow.height * 0.08
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: parent.height * 0.05
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: areaOkCreditos.pressed ? "#6b42b5" : "#8b5cf6"
                        radius: height / 2
                        Text { anchors.centerIn: parent; text: qsTr("Cerrar"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaOkCreditos
                            anchors.fill: parent
                            onClicked: pantallaAjustes.mostrarPopupCreditos = false
                        }
                    }
                }
            }
        }

    // 5. SELECCIÓN DE PROYECTOS
        Item {
            id: pantallaNuevoProyecto
            anchors.fill: parent
            visible: estadoActual === "pantalla_nuevo_proyecto"

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.height * 0.05
                spacing: parent.width * 0.05

                Rectangle {
                    width: mainWindow.width * 0.35
                    height: mainWindow.height * 0.40
                    color: areaBotonProyectosGuardados.pressed ? "#7da84c" : "#8DBB5A"
                    radius: 20
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Proyectos\nguardados")
                        horizontalAlignment: Text.AlignHCenter
                        color: "black"
                        font.pixelSize: parent.height * 0.15
                        font.bold: true
                    }
                    MouseArea {
                        id: areaBotonProyectosGuardados
                        anchors.fill: parent
                        onClicked: estadoActual = "pantalla_proyectos_guardados"
                    }
                }
                Rectangle {
                    width: mainWindow.width * 0.35
                    height: mainWindow.height * 0.40
                    color: areaBotonNuevoProyecto.pressed ? "#5a8282" : "#6E9C9C"
                    radius: 20
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Nuevo\nproyecto")
                        horizontalAlignment: Text.AlignHCenter
                        color: "black"
                        font.pixelSize: parent.height * 0.15
                        font.bold: true
                    }
                    MouseArea {
                        id: areaBotonNuevoProyecto
                        anchors.fill: parent
                        onClicked: {
                            estadoPrevioPantalla6 = "pantalla_nuevo_proyecto"
                            omitirPedirNombre = false
                            mainWindow.limpiarDatos(false)
                            estadoActual = "pantalla_6"
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: parent.width * 0.05
                width: parent.width * 0.12
                height: parent.height * 0.10
                color: areaAtrasSeleccion.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: "↶"
                    color: "black"
                    font.pixelSize: parent.height * 0.70
                    font.bold: true
                }
                MouseArea {
                    id: areaAtrasSeleccion
                    anchors.fill: parent
                    onClicked: estadoActual = "pantalla_principal"
                }
            }
        }

        // 6. CONFIGURACIÓN NUEVO PROYECTO
        Item {
            id: pantalla6
            anchors.fill: parent
            visible: estadoActual === "pantalla_6"

            property string campoActivo: ""
            property string entradaTemporal: ""

            property bool mostrarPopupGuardar: false
            property bool mostrarPopupAdvertencia: false
            property bool mostrarPopupConfirmacion: false

            property bool tempConfigurada: false
            property bool phConfigurado: false
            property bool aguaConfigurada: false
            property bool luzConfigurada: false
            property bool tiempoConfigurado: false

            focus: visible
            Keys.onPressed: (event) => {
                if (campoActivo !== "" && !mostrarPopupGuardar && !mostrarPopupAdvertencia && !mostrarPopupConfirmacion) {
                    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                        let digito = (event.key - Qt.Key_0).toString()
                        entradaTemporal = (entradaTemporal === "0") ? digito : entradaTemporal + digito
                        event.accepted = true
                    } else if (event.key === Qt.Key_Period) {
                        if (entradaTemporal.indexOf(".") === -1) {
                            entradaTemporal += (entradaTemporal === "" ? "0." : ".")
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backspace) {
                        if (entradaTemporal.length > 0) {
                            entradaTemporal = entradaTemporal.substring(0, entradaTemporal.length - 1)
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        let val = parseFloat(entradaTemporal);
                        if (!isNaN(val)) {
                            if (campoActivo === "Tem") {
                                let minT = mainWindow.unidadTemperatura === "C" ? 20 : 68;
                                let maxT = mainWindow.unidadTemperatura === "C" ? 100 : 212;
                                var_deseada_Tem = Math.max(minT, Math.min(maxT, val));
                                tempConfigurada = true;
                            }
                            else if (campoActivo === "pH") { var_deseada_pH = Math.max(1, Math.min(14, val)); phConfigurado = true; }
                            else if (campoActivo === "Agua") { var_deseada_Agua = Math.max(30, Math.min(100, val)); aguaConfigurada = true; }
                            else if (campoActivo === "Luz") { var_deseada_Luz = Math.max(0, Math.min(100, val)); luzConfigurada = true; }
                            else if (campoActivo === "Semanas") { var_deseada_tiempo_semanas = Math.max(0, val); tiempoConfigurado = true; }
                            else if (campoActivo === "Dias") { var_deseada_tiempo_dias = Math.max(0, val); tiempoConfigurado = true; }
                            else if (campoActivo === "Horas") { var_deseada_tiempo_horas = Math.max(0, val); tiempoConfigurado = true; }
                            else if (campoActivo === "Minutos") { var_deseada_tiempo_minutos = Math.max(0, val); tiempoConfigurado = true; }

                            var_deseada_tiempo_total_horas = (var_deseada_tiempo_semanas * 168) + (var_deseada_tiempo_dias * 24) + var_deseada_tiempo_horas + (var_deseada_tiempo_minutos / 60);
                        }
                        campoActivo = ""; entradaTemporal = ""; event.accepted = true
                    }
                }
            }

            Column {
                id: columnaBarrasConfiguracion
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.05
                anchors.top: parent.top
                anchors.topMargin: mainWindow.height * 0.22
                spacing: parent.height * 0.02

                BarraInputConfig {
                    idCampo: "Tem"
                    campoActivo: pantalla6.campoActivo
                    textoEtiqueta: qsTr("Temperatura:")
                    valorMostrado: (pantalla6.campoActivo === "Tem" ? pantalla6.entradaTemporal + "|" : var_deseada_Tem) + " °" + mainWindow.unidadTemperatura
                    onBarraClicada: { pantalla6.campoActivo = "Tem"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                }
                BarraInputConfig {
                    idCampo: "pH"
                    campoActivo: pantalla6.campoActivo
                    textoEtiqueta: qsTr("Nivel de pH:")
                    valorMostrado: (pantalla6.campoActivo === "pH" ? pantalla6.entradaTemporal + "|" : var_deseada_pH)
                    onBarraClicada: { pantalla6.campoActivo = "pH"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                }
                BarraInputConfig {
                    idCampo: "Agua"
                    campoActivo: pantalla6.campoActivo
                    textoEtiqueta: qsTr("Nivel de agua:")
                    valorMostrado: (pantalla6.campoActivo === "Agua" ? pantalla6.entradaTemporal + "|" : var_deseada_Agua) + " %"
                    onBarraClicada: { pantalla6.campoActivo = "Agua"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                }
                BarraInputConfig {
                    idCampo: "Luz"
                    campoActivo: pantalla6.campoActivo
                    textoEtiqueta: qsTr("Nivel de luz:")
                    valorMostrado: (pantalla6.campoActivo === "Luz" ? pantalla6.entradaTemporal + "|" : var_deseada_Luz) + " %"
                    onBarraClicada: { pantalla6.campoActivo = "Luz"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                }

                // Tiempos (Semanas/Días)
                Rectangle {
                    width: mainWindow.width * 0.45
                    height: mainWindow.height * 0.08
                    color: "#8DBB5A"
                    radius: height / 2
                    Row {
                        anchors.fill: parent
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.9
                                height: parent.height * 0.8
                                color: pantalla6.campoActivo === "Semanas" ? "#A5D6A7" : "transparent"
                                radius: height / 2
                            }
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Semanas: ") + (pantalla6.campoActivo === "Semanas" ? pantalla6.entradaTemporal + "|" : var_deseada_tiempo_semanas)
                                font.pixelSize: parent.height * 0.35
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { pantalla6.campoActivo = "Semanas"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                            }
                        }
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.9
                                height: parent.height * 0.8
                                color: pantalla6.campoActivo === "Dias" ? "#A5D6A7" : "transparent"
                                radius: height / 2
                            }
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Días: ") + (pantalla6.campoActivo === "Dias" ? pantalla6.entradaTemporal + "|" : var_deseada_tiempo_dias)
                                font.pixelSize: parent.height * 0.35
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { pantalla6.campoActivo = "Dias"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                            }
                        }
                    }
                }

                // Tiempos (Horas/Minutos)
                Rectangle {
                    width: mainWindow.width * 0.45
                    height: mainWindow.height * 0.08
                    color: "#8DBB5A"
                    radius: height / 2
                    Row {
                        anchors.fill: parent
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.9
                                height: parent.height * 0.8
                                color: pantalla6.campoActivo === "Horas" ? "#A5D6A7" : "transparent"
                                radius: height / 2
                            }
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Horas: ") + (pantalla6.campoActivo === "Horas" ? pantalla6.entradaTemporal + "|" : var_deseada_tiempo_horas)
                                font.pixelSize: parent.height * 0.35
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { pantalla6.campoActivo = "Horas"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                            }
                        }
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width * 0.9
                                height: parent.height * 0.8
                                color: pantalla6.campoActivo === "Minutos" ? "#A5D6A7" : "transparent"
                                radius: height / 2
                            }
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Minutos: ") + (pantalla6.campoActivo === "Minutos" ? pantalla6.entradaTemporal + "|" : var_deseada_tiempo_minutos)
                                font.pixelSize: parent.height * 0.35
                                font.bold: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { pantalla6.campoActivo = "Minutos"; pantalla6.entradaTemporal = ""; pantalla6.forceActiveFocus() }
                            }
                        }
                    }
                }
            }

            Image {
                source: "Hongo_4.png"
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.08
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: mainWindow.height * 0.03
                width: parent.width * 0.30
                fillMode: Image.PreserveAspectFit
                z: 1
            }

            // --- TECLADO NUMÉRICO 4x4 ---
            TecladoNumerico {
                id: tecladoNumerico
                z: 10
                visible: pantalla6.campoActivo !== ""
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.08
                anchors.verticalCenter: columnaBarrasConfiguracion.verticalCenter
                width: parent.width * 0.35
                height: parent.height * 0.45
                onDigitoPresionado: function(d) { pantalla6.entradaTemporal = pantalla6.entradaTemporal === "0" ? d : pantalla6.entradaTemporal + d }
                onPuntoPresionado:  { if (pantalla6.entradaTemporal.indexOf(".") === -1) pantalla6.entradaTemporal += pantalla6.entradaTemporal === "" ? "0." : "." }
                onBorrarPresionado: { if (pantalla6.entradaTemporal.length > 0) pantalla6.entradaTemporal = pantalla6.entradaTemporal.slice(0, -1) }
                onOkPresionado: {
                    let val = parseFloat(pantalla6.entradaTemporal);
                    if (!isNaN(val)) {
                        if (pantalla6.campoActivo === "Tem") {
                            let minT = mainWindow.unidadTemperatura === "C" ? 20 : 68;
                            let maxT = mainWindow.unidadTemperatura === "C" ? 100 : 212;
                            var_deseada_Tem = Math.max(minT, Math.min(maxT, val));
                            pantalla6.tempConfigurada = true;
                        }
                        else if (pantalla6.campoActivo === "pH") { var_deseada_pH = Math.max(1, Math.min(14, val)); pantalla6.phConfigurado = true; }
                        else if (pantalla6.campoActivo === "Agua") { var_deseada_Agua = Math.max(30, Math.min(100, val)); pantalla6.aguaConfigurada = true; }
                        else if (pantalla6.campoActivo === "Luz") { var_deseada_Luz = Math.max(0, Math.min(100, val)); pantalla6.luzConfigurada = true; }
                        else if (pantalla6.campoActivo === "Semanas") { var_deseada_tiempo_semanas = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                        else if (pantalla6.campoActivo === "Dias") { var_deseada_tiempo_dias = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                        else if (pantalla6.campoActivo === "Horas") { var_deseada_tiempo_horas = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                        else if (pantalla6.campoActivo === "Minutos") { var_deseada_tiempo_minutos = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                        var_deseada_tiempo_total_horas = (var_deseada_tiempo_semanas * 168) + (var_deseada_tiempo_dias * 24) + var_deseada_tiempo_horas + (var_deseada_tiempo_minutos / 60);
                    }
                    pantalla6.campoActivo = "";
                    pantalla6.entradaTemporal = "";
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: parent.width * 0.05
                width: parent.width * 0.20
                height: parent.height * 0.10
                color: areaOkPantalla6.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Okay")
                    color: "black"
                    font.pixelSize: parent.height * 0.40
                    font.bold: true
                }
                MouseArea {
                    id: areaOkPantalla6
                    anchors.fill: parent
                    onClicked: {
                        if (pantalla6.campoActivo !== "" && pantalla6.entradaTemporal !== "") {
                            let val = parseFloat(pantalla6.entradaTemporal);
                            if (!isNaN(val)) {
                                if (pantalla6.campoActivo === "Tem") { var_deseada_Tem = Math.max(20, Math.min(100, val)); pantalla6.tempConfigurada = true; }
                                else if (pantalla6.campoActivo === "pH") { var_deseada_pH = Math.max(1, Math.min(14, val)); pantalla6.phConfigurado = true; }
                                else if (pantalla6.campoActivo === "Agua") { var_deseada_Agua = Math.max(30, Math.min(100, val)); pantalla6.aguaConfigurada = true; }
                                else if (pantalla6.campoActivo === "Luz") { var_deseada_Luz = Math.max(0, Math.min(100, val)); pantalla6.luzConfigurada = true; }
                                else if (pantalla6.campoActivo === "Semanas") { var_deseada_tiempo_semanas = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                                else if (pantalla6.campoActivo === "Dias") { var_deseada_tiempo_dias = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                                else if (pantalla6.campoActivo === "Horas") { var_deseada_tiempo_horas = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                                else if (pantalla6.campoActivo === "Minutos") { var_deseada_tiempo_minutos = Math.max(0, val); pantalla6.tiempoConfigurado = true; }
                            }
                            pantalla6.campoActivo = "";
                            pantalla6.entradaTemporal = "";
                        }

                        var_deseada_tiempo_total_horas = (var_deseada_tiempo_semanas * 168) + (var_deseada_tiempo_dias * 24) + var_deseada_tiempo_horas + (var_deseada_tiempo_minutos / 60);

                        if (pantalla6.tiempoConfigurado && var_deseada_tiempo_total_horas < 6) {
                            var_deseada_tiempo_horas = 6; // Piso mínimo de 6 horas
                            var_deseada_tiempo_minutos = 0;
                            var_deseada_tiempo_dias = 0;
                            var_deseada_tiempo_semanas = 0;
                            var_deseada_tiempo_total_horas = 6;
                        }

                        if (pantalla6.tempConfigurada && pantalla6.phConfigurado && pantalla6.aguaConfigurada && pantalla6.luzConfigurada && pantalla6.tiempoConfigurado) {
                            if (omitirPedirNombre) {
                                pantalla6.mostrarPopupConfirmacion = true;
                            } else {
                                pantalla6.mostrarPopupGuardar = true;
                            }
                        } else {
                            pantalla6.mostrarPopupAdvertencia = true;
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: parent.width * 0.05
                width: parent.width * 0.12
                height: parent.height * 0.10
                color: areaAtrasPantalla6.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2

                Text {
                    anchors.centerIn: parent
                    text: "↶"
                    color: "black"
                    font.pixelSize: parent.height * 0.70
                    font.bold: true
                }
                MouseArea {
                    id: areaAtrasPantalla6
                    anchors.fill: parent
                    onClicked: {
                        mainWindow.limpiarDatos(false)
                        omitirPedirNombre = false
                        estadoActual = estadoPrevioPantalla6
                    }
                }
            }

            PopupIngresoNombre {
                id: popupGuardado6
                visible: pantalla6.mostrarPopupGuardar
                tituloPopup: qsTr("Ingrese nombre del experimento")
                nombrePorDefecto: ""
                onAceptado: function(name) {
                    var nombreFinal = name.trim();
                    if (nombreFinal === "") {
                        var d = new Date();
                        nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
                    }
                    var_nombre_experimento = nombreFinal;
                    var_nombre_proyecto = qsTr("Experimento Nuevo");
                    pantalla6.mostrarPopupGuardar = false;
                    pantalla6.mostrarPopupConfirmacion = true;
                }
                onCancelado: {
                    pantalla6.mostrarPopupGuardar = false;
                }
            }

            PopupConfirmarProceso {
                id: popupConfirmacion6
                visible: pantalla6.mostrarPopupConfirmacion
                nombreProyecto: var_nombre_proyecto
                nombreExperimento: var_nombre_experimento
                temp: var_deseada_Tem
                ph: var_deseada_pH
                agua: var_deseada_Agua
                luz: var_deseada_Luz
                tiempoSemanas: var_deseada_tiempo_semanas
                tiempoDias: var_deseada_tiempo_dias
                tiempoHoras: var_deseada_tiempo_horas
                tiempoMinutos: var_deseada_tiempo_minutos
                tiempoTotal: var_deseada_tiempo_total_horas
                unidadTemperatura: mainWindow.unidadTemperatura

                onConfirmado: {
                    pantalla6.mostrarPopupConfirmacion = false;
                    var d = new Date();
                    var cadenaFecha = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear();

                    registro_experimentos.append({
                        "proyecto": var_nombre_proyecto,
                        "experimento": var_nombre_experimento,
                        "fecha": cadenaFecha,
                        "tiempo": "0.0 / " + var_deseada_tiempo_total_horas.toFixed(1) + " hrs",
                        "peso": (Math.random() * 5 + 0.5).toFixed(1) + " MB",
                        "seleccionado": false
                    });
                    estadoActual = "pantalla_7"
                }
                onCancelado: {
                    pantalla6.mostrarPopupConfirmacion = false;
                }
            }

            Item {
                id: overlayAdvertencia
                anchors.fill: parent
                z: 200
                visible: pantalla6.mostrarPopupAdvertencia

                MouseArea {
                    anchors.fill: parent
                }
                Rectangle {
                    width: parent.width * 0.75
                    height: parent.height * 0.55
                    anchors.centerIn: parent
                    color: Qt.rgba(0.7, 0.7, 0.7, 0.9)
                    radius: 20

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.10
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Por favor, ingrese todos los parámetros")
                        font.pixelSize: parent.height * 0.08
                        font.bold: true
                        color: "black"
                    }
                    Image {
                        source: "Alerta.png"
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -parent.height * 0.03
                        height: parent.height * 0.35
                        fillMode: Image.PreserveAspectFit
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: parent.height * 0.10
                        width: mainWindow.width * 0.20
                        height: mainWindow.height * 0.10
                        color: areaOkAdvertencia.pressed ? "#6b42b5" : "#8b5cf6"
                        radius: height / 2

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Okay")
                            color: "black"
                            font.pixelSize: parent.height * 0.40
                            font.bold: true
                        }
                        MouseArea {
                            id: areaOkAdvertencia
                            anchors.fill: parent
                            onClicked: pantalla6.mostrarPopupAdvertencia = false
                        }
                    }
                }
            }
        }

        // 7. CALIBRACIÓN RÁPIDA
        Item {
            id: pantalla7
            anchors.fill: parent
            visible: estadoActual === "pantalla_7"

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: mainWindow.height * 0.05
                spacing: mainWindow.height * 0.05

                Text {
                    text: qsTr("Calibración rápida")
                    font.pixelSize: mainWindow.height * 0.10
                    font.bold: true
                    color: "black"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("Espere un momento por favor")
                    font.pixelSize: mainWindow.height * 0.05
                    font.bold: true
                    color: "black"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Image {
                    id: hongoCalibracion
                    source: "Hongo_5.png"
                    width: mainWindow.width * 0.20
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter

                    SequentialAnimation on rotation {
                        loops: Animation.Infinite
                        running: pantalla7.visible
                        NumberAnimation {
                            from: 0
                            to: 360
                            duration: 600
                            easing.type: Easing.InOutQuad
                        }
                        PauseAnimation {
                            duration: 600
                        }
                    }
                }
            }
            Timer {
                interval: 3500
                running: pantalla7.visible
                onTriggered: {
                    if (sensor_estado_calibracion === 1) {
                        estadoActual = "pantalla_procesos"
                    } else {
                        estado_sensor_retorno_error = "pantalla_7"
                        textoMensajeError = qsTr("Error en calibración rápida")
                        estadoActual = "pantalla_de_error"
                    }
                }
            }
        }

        // 8. PROCESOS
                Item {
                    id: pantallaProcesos
                    anchors.fill: parent
                    visible: estadoActual === "pantalla_procesos"

                    property real progresoSimulado: 0.0
                    property bool mostrarPopupPausa: false
                    property bool mostrarPopupFinalizado: false
                    property bool mostrarPopupConfirmarDetener: false

                    PropertyAnimation {
                        id: animacionProgreso
                        target: pantallaProcesos
                        property: "progresoSimulado"
                        from: 0.0
                        to: 1.0
                        duration: Math.max(1000, Math.floor(var_deseada_tiempo_total_horas * 3600000))
                        onFinished: {
                            // YA NO SE DETIENE SI LA PANTALLA NO ES VISIBLE
                            if (pantallaProcesos.progresoSimulado >= 1.0) {
                                pantallaProcesos.mostrarPopupFinalizado = true;
                            }
                        }
                    }

                    onVisibleChanged: {
                        if (visible) {
                            // SOLO INICIA SI ESTÁ EN CERO (PROCESO NUEVO)
                            if (progresoSimulado === 0.0 && !mostrarPopupFinalizado) {
                                mostrarPopupPausa = false;
                                mostrarPopupFinalizado = false;
                                mostrarPopupConfirmarDetener = false;
                                animacionProgreso.start();
                            }
                        }
                        // SE ELIMINÓ EL 'else' QUE PAUSABA LA ANIMACIÓN AL CAMBIAR DE PANTALLA
                    }

                    Rectangle {
                        id: cajaGrafica
                        width: parent.width * 0.45
                        height: parent.height * 0.55
                        anchors.left: parent.left
                        anchors.leftMargin: parent.width * 0.05
                        anchors.top: parent.top
                        anchors.topMargin: parent.height * 0.20
                        color: "#6E9C9C"
                        radius: 20

                        MouseArea {
                            anchors.fill: parent
                            onClicked: estadoActual = "pantalla_configuracion_graficas"
                        }
                        Text {
                            text: qsTr("Gráfica de :")
                            font.pixelSize: parent.height * 0.08
                            font.bold: true
                            color: "black"
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.left: parent.left
                            anchors.leftMargin: 30
                        }
                        Rectangle {
                            width: 4
                            color: "black"
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.top: parent.top
                            anchors.topMargin: 70
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 40
                        }
                        Rectangle {
                            height: 4
                            color: "black"
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 40
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 40
                        }
                    }

                    Column {
                        id: pildorasProceso
                        anchors.right: parent.right
                        anchors.rightMargin: parent.width * 0.05
                        anchors.verticalCenter: cajaGrafica.verticalCenter
                        width: parent.width * 0.40
                        spacing: mainWindow.height * 0.025

                        Rectangle {
                            width: parent.width
                            height: mainWindow.height * 0.08
                            color: "#8DBB5A"
                            radius: height / 2
                            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Temp °%1: %2").arg(mainWindow.unidadTemperatura).arg(var_sensor_Tem.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
                            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Temp °%1: %2").arg(mainWindow.unidadTemperatura).arg(var_deseada_Tem.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        }
                        Rectangle {
                            width: parent.width
                            height: mainWindow.height * 0.08
                            color: "#8DBB5A"
                            radius: height / 2
                            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. pH: %1").arg(var_sensor_pH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
                            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. pH: %1").arg(var_deseada_pH.toFixed(1)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        }
                        Rectangle {
                            width: parent.width
                            height: mainWindow.height * 0.08
                            color: "#8DBB5A"
                            radius: height / 2
                            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. Agua: %1%").arg(var_sensor_Agua.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
                            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. Agua: %1%").arg(var_deseada_Agua.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        }
                        Rectangle {
                            width: parent.width
                            height: mainWindow.height * 0.08
                            color: "#8DBB5A"
                            radius: height / 2
                            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. Luz: %1%").arg(var_sensor_Luz.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            Text { anchors.centerIn: parent; text: "→"; font.pixelSize: parent.height * 0.50; font.bold: true; color: "black" }
                            Text { anchors.left: parent.horizontalCenter; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. Luz: %1%").arg(var_deseada_Luz.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        }
                        Rectangle {
                            width: parent.width
                            height: mainWindow.height * 0.08
                            color: "#8DBB5A"
                            radius: height / 2
                            Text { anchors.left: parent.left; anchors.leftMargin: 30; anchors.verticalCenter: parent.verticalCenter; text: qsTr("N. CO2: %1 ppm").arg(var_sensor_CO2.toFixed(0)); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        }
                    }

                    Item {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: mainWindow.height * 0.15

                        Rectangle {
                            id: botonAjustes8
                            anchors.left: parent.left
                            anchors.leftMargin: mainWindow.width * 0.05
                            anchors.verticalCenter: parent.verticalCenter
                            width: mainWindow.width * 0.08
                            height: mainWindow.height * 0.10
                            radius: width * 0.35
                            color: areaMouseEngrane8.pressed ? "#9ca3af" : "#B3B3B3"
                            Image {
                                source: "Engrane.png"
                                anchors.centerIn: parent
                                width: parent.width * 0.65
                                height: parent.height * 0.65
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: areaMouseEngrane8
                                anchors.fill: parent
                                onClicked: {
                                    estadoPrevioAjustes = "pantalla_procesos"
                                    estadoActual = "pantalla_configuraciones"
                                }
                            }
                        }

                        Item {
                            anchors.left: botonAjustes8.right
                            anchors.leftMargin: mainWindow.width * 0.03
                            anchors.right: btnPlayPausa.left
                            anchors.rightMargin: mainWindow.width * 0.03
                            anchors.verticalCenter: parent.verticalCenter
                            height: mainWindow.height * 0.08

                            Rectangle {
                                id: fondoBarraProgreso
                                anchors.top: parent.top
                                width: parent.width
                                height: mainWindow.height * 0.04
                                color: "#A0A0A0"
                                radius: height / 2
                                Rectangle {
                                    width: parent.width * pantallaProcesos.progresoSimulado
                                    height: parent.height
                                    color: "#5a8282"
                                    radius: parent.radius
                                }
                            }

                            Item {
                                anchors.top: fondoBarraProgreso.bottom
                                anchors.bottom: parent.bottom
                                width: parent.width
                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    property int t_h: Math.floor(var_deseada_tiempo_total_horas)
                                    property int t_m: Math.round((var_deseada_tiempo_total_horas - t_h) * 60)
                                    text: qsTr("Tiempo total: %1 h %2 min").arg(t_h).arg(t_m)
                                    font.pixelSize: parent.height * 0.55
                                    font.bold: true
                                    color: "black"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Math.floor(pantallaProcesos.progresoSimulado * 100) + "%"
                                    font.pixelSize: parent.height * 0.55
                                    font.bold: true
                                    color: "black"
                                }
                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    property real e_total: pantallaProcesos.progresoSimulado * var_deseada_tiempo_total_horas
                                    property int e_h: Math.floor(e_total)
                                    property int e_m: Math.round((e_total - e_h) * 60)
                                    text: qsTr("Tiempo transcurrido: %1 h %2 min").arg(e_h).arg(e_m)
                                    font.pixelSize: parent.height * 0.55
                                    font.bold: true
                                    color: "black"
                                }
                            }
                        }

                        Image {
                            id: btnPlayPausa
                            source: "Play_Pause.png"
                            anchors.right: imgHongoOculto.left
                            anchors.rightMargin: mainWindow.width * 0.02
                            anchors.verticalCenter: parent.verticalCenter
                            height: mainWindow.height * 0.06
                            fillMode: Image.PreserveAspectFit
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    animacionProgreso.pause();
                                    pantallaProcesos.mostrarPopupPausa = true;
                                }
                            }
                        }

                        Image {
                            id: imgHongoOculto
                            source: "Hongo_6.png"
                            anchors.right: parent.right
                            anchors.rightMargin: mainWindow.width * 0.03
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: mainWindow.height * 0.01
                            height: parent.height * 0.90
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    Item {
                        id: overlayPausa
                        anchors.fill: parent
                        z: 200
                        visible: pantallaProcesos.mostrarPopupPausa && !pantallaProcesos.mostrarPopupConfirmarDetener
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Rectangle {
                            width: parent.width * 0.65
                            height: parent.height * 0.55
                            anchors.centerIn: parent
                            color: Qt.rgba(0.8, 0.8, 0.8, 0.9)
                            radius: 20

                            Rectangle {
                                width: parent.width * 0.55
                                height: parent.height * 0.50
                                anchors.centerIn: parent
                                color: areaDetenerProceso.pressed ? "#404040" : "#555555"
                                radius: 20
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Detener\nproceso")
                                    font.pixelSize: parent.height * 0.20
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                MouseArea {
                                    id: areaDetenerProceso
                                    anchors.fill: parent
                                    onClicked: {
                                        pantallaProcesos.mostrarPopupConfirmarDetener = true;
                                    }
                                }
                            }

                            Rectangle {
                                width: mainWindow.width * 0.12
                                height: mainWindow.height * 0.10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.10
                                anchors.right: parent.right
                                anchors.rightMargin: parent.width * 0.05
                                color: areaAtrasPausa.pressed ? "#cc1e1e" : "#FF2D2D"
                                radius: height / 2
                                Text {
                                    anchors.centerIn: parent
                                    text: "↶"
                                    font.pixelSize: parent.height * 0.70
                                    font.bold: true
                                    color: "black"
                                }
                                MouseArea {
                                    id: areaAtrasPausa
                                    anchors.fill: parent
                                    onClicked: {
                                        pantallaProcesos.mostrarPopupPausa = false;
                                        animacionProgreso.resume();
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: overlayConfirmarParo
                        anchors.fill: parent
                        z: 250
                        visible: pantallaProcesos.mostrarPopupConfirmarDetener
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Rectangle {
                            width: parent.width * 0.60
                            height: parent.height * 0.40
                            anchors.centerIn: parent
                            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                            radius: 20

                            Text {
                                anchors.top: parent.top
                                anchors.topMargin: parent.height * 0.15
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("¿Seguro que deseas detener el proceso?")
                                font.pixelSize: parent.height * 0.10
                                font.bold: true
                                color: "black"
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: mainWindow.width * 0.15
                                height: mainWindow.height * 0.08
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.15
                                anchors.left: parent.left
                                anchors.leftMargin: parent.width * 0.10
                                color: areaOkDetener.pressed ? "#6b42b5" : "#8b5cf6"
                                radius: height / 2
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Okay")
                                    font.pixelSize: parent.height * 0.40
                                    font.bold: true
                                    color: "black"
                                }
                                MouseArea {
                                    id: areaOkDetener
                                    anchors.fill: parent
                                    onClicked: {
                                        animacionProgreso.stop(); // <--- LA ANIMACIÓN SE DETIENE AQUÍ
                                        let lastIdx = registro_experimentos.count - 1;
                                        if (lastIdx >= 0) {
                                            let e_total = pantallaProcesos.progresoSimulado * var_deseada_tiempo_total_horas;
                                            registro_experimentos.setProperty(lastIdx, "tiempo", e_total.toFixed(1) + " / " + var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
                                        }
                                        pantallaProcesos.mostrarPopupConfirmarDetener = false;
                                        pantallaProcesos.mostrarPopupPausa = false;
                                        pantallaProcesos.progresoSimulado = 0.0;
                                        estadoActual = "pantalla_11";
                                    }
                                }
                            }

                            Rectangle {
                                width: mainWindow.width * 0.15
                                height: mainWindow.height * 0.08
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.15
                                anchors.right: parent.right
                                anchors.rightMargin: parent.width * 0.10
                                color: areaAtrasDetener.pressed ? "#cc1e1e" : "#FF2D2D"
                                radius: height / 2
                                Text {
                                    anchors.centerIn: parent
                                    text: "↶"
                                    font.pixelSize: parent.height * 0.70
                                    font.bold: true
                                    color: "black"
                                }
                                MouseArea {
                                    id: areaAtrasDetener
                                    anchors.fill: parent
                                    onClicked: {
                                        pantallaProcesos.mostrarPopupConfirmarDetener = false;
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: overlayFinalizado
                        anchors.fill: parent
                        z: 200
                        visible: pantallaProcesos.mostrarPopupFinalizado
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Rectangle {
                            width: parent.width * 0.65
                            height: parent.height * 0.55
                            anchors.centerIn: parent
                            color: Qt.rgba(0.8, 0.8, 0.8, 0.9)
                            radius: 20

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -parent.height * 0.10
                                text: qsTr("Proceso\nfinalizado")
                                font.pixelSize: parent.height * 0.20
                                font.bold: true
                                color: "black"
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: mainWindow.width * 0.20
                                height: mainWindow.height * 0.10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: parent.height * 0.10
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: areaOkFinalizado.pressed ? "#6b42b5" : "#8b5cf6"
                                radius: height / 2
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Okay")
                                    font.pixelSize: parent.height * 0.40
                                    font.bold: true
                                    color: "black"
                                }
                                MouseArea {
                                    id: areaOkFinalizado
                                    anchors.fill: parent
                                    onClicked: {
                                        let lastIdx = registro_experimentos.count - 1;
                                        if (lastIdx >= 0) {
                                            registro_experimentos.setProperty(lastIdx, "tiempo", var_deseada_tiempo_total_horas.toFixed(1) + " / " + var_deseada_tiempo_total_horas.toFixed(1) + " hrs");
                                        }
                                        pantallaProcesos.progresoSimulado = 0.0;
                                        pantallaProcesos.mostrarPopupFinalizado = false;
                                        estadoActual = "pantalla_11";
                                    }
                                }
                            }
                        }
                    }
                }

        // 9. PROYECTOS GUARDADOS
            Item {
                id: pantallaProyectosGuardados
                anchors.fill: parent
                visible: estadoActual === "pantalla_proyectos_guardados"

                property bool mostrarPopupGuardar: false
                property bool mostrarPopupConfirmacion: false

                property bool mostrarPopupOpciones: false
                property bool mostrarPopupBorrarGuardado: false
                property bool mostrarPopupEdicionProyecto: false
                property bool mostrarPopupConfirmarEdicion: false

                property int indexEditando: -1
                QtObject {
                    id: datosEdicion
                    property string nombre: ""
                    property real temp: 0.0
                    property real ph: 0.0
                    property real agua: 0.0
                    property real luz: 0.0
                    property string tiempo: ""
                }

                // Variables para el teclado de edición
                property string campoEditActivo: ""
                property string entradaEditTemporal: ""

                Column {
                    id: colTituloProyectos
                    anchors.top: parent.top
                    anchors.topMargin: mainWindow.height * 0.16
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: mainWindow.height * 0.01

                    Text {
                        text: qsTr("Proyectos Guardados")
                        font.pixelSize: mainWindow.height * 0.06
                        font.bold: true
                        color: "black"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item {
                    anchors.top: colTituloProyectos.bottom
                    anchors.topMargin: mainWindow.height * 0.05
                    anchors.bottom: botonAtras9.top
                    anchors.bottomMargin: mainWindow.height * 0.02
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: mainWindow.width * 0.05

                    Rectangle {
                        id: botonCarruselIzq
                        width: mainWindow.width * 0.04
                        height: mainWindow.height * 0.15
                        radius: width / 2
                        color: carruselGuardados.currentIndex > 0 ? "#A0A0A0" : "#D0D0D0"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "◀"
                            font.pixelSize: parent.width * 0.50
                            color: "#333333"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (carruselGuardados.currentIndex > 0) {
                                    carruselGuardados.currentIndex--;
                                    carruselGuardados.positionViewAtIndex(carruselGuardados.currentIndex, ListView.Beginning);
                                }
                            }
                        }
                    }

                    ListView {
                        id: carruselGuardados
                        anchors.left: botonCarruselIzq.right
                        anchors.right: botonCarruselDer.left
                        anchors.leftMargin: mainWindow.width * 0.02
                        anchors.rightMargin: mainWindow.width * 0.02
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height * 0.85
                        orientation: ListView.Horizontal
                        spacing: mainWindow.width * 0.02
                        clip: true
                        interactive: false
                        snapMode: ListView.SnapToItem

                        Behavior on contentX { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }

                        model: datos_guardados
                        delegate: Rectangle {
                            width: (carruselGuardados.width - (carruselGuardados.spacing * 2)) / 3
                            height: carruselGuardados.height
                            radius: 20
                            color: index % 2 === 0 ? "#8DBB5A" : "#6E9C9C"

                            Image {
                                source: "Engrane.png"
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: parent.width * 0.05
                                width: parent.width * 0.12
                                height: width
                                fillMode: Image.PreserveAspectFit
                                z: 10
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        pantallaProyectosGuardados.indexEditando = index;
                                        pantallaProyectosGuardados.mostrarPopupOpciones = true;
                                    }
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.08
                                spacing: parent.height * 0.015
                                Text { text: qsTr("Proyecto %1:").arg(index + 1); font.pixelSize: parent.height * 0.08; font.bold: true; color: "black" }
                                Text { text: model.nombre; font.pixelSize: parent.height * 0.07; font.bold: true; color: "black"; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                                Item { height: parent.height * 0.01; width: 1 }
                                Text {
                                    // Si la unidad es C, muestra el valor tal cual. Si es F, hace la conversión matemática para la vista.
                                    text: qsTr("Temp °%1: %2").arg(mainWindow.unidadTemperatura).arg(mainWindow.unidadTemperatura === "C" ? model.temp : (model.temp * 9/5 + 32).toFixed(1))
                                    font.pixelSize: parent.height * 0.06; font.bold: true; color: "black"
                                }
                                Text { text: qsTr("Nivel pH: %1").arg(model.ph); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                                Text { text: qsTr("Nivel agua: %1 %").arg(model.agua); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                                Text { text: qsTr("Nivel luz: %1 %").arg(model.luz); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                                Text { text: qsTr("Tiempo: %1 hrs").arg(model.tiempo); font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    mainWindow.limpiarDatos(false);
                                    var_nombre_proyecto = model.nombre;
                                    // Si la app está en F, convertimos el valor de la base de datos (que es C) a F al cargar.
                                    var_deseada_Tem = (mainWindow.unidadTemperatura === "C" ? model.temp : (model.temp * 9/5 + 32));
                                    var_deseada_pH = model.ph;
                                    var_deseada_Agua = model.agua;
                                    var_deseada_Luz = model.luz;
                                    let total = parseFloat(model.tiempo);
                                    var_deseada_tiempo_total_horas = total;
                                    var_deseada_tiempo_semanas = Math.floor(total / 168);
                                    let rem = total % 168;
                                    var_deseada_tiempo_dias = Math.floor(rem / 24);
                                    rem = rem % 24;
                                    var_deseada_tiempo_horas = Math.floor(rem);
                                    var_deseada_tiempo_minutos = Math.round((rem - var_deseada_tiempo_horas) * 60);
                                    popupGuardar9.nombrePorDefecto = "";
                                    pantallaProyectosGuardados.mostrarPopupGuardar = true;
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: botonCarruselDer
                        width: mainWindow.width * 0.04
                        height: mainWindow.height * 0.15
                        radius: width / 2
                        color: carruselGuardados.currentIndex < carruselGuardados.count - 3 ? "#A0A0A0" : "#D0D0D0"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            font.pixelSize: parent.width * 0.50
                            color: "#333333"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (carruselGuardados.currentIndex < carruselGuardados.count - 3) {
                                    carruselGuardados.currentIndex++;
                                    carruselGuardados.positionViewAtIndex(carruselGuardados.currentIndex, ListView.Beginning);
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: botonAtras9
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: parent.width * 0.05
                    width: parent.width * 0.12
                    height: parent.height * 0.10
                    color: areaAtras9.pressed ? "#cc1e1e" : "#FF2D2D"
                    radius: height / 2
                    Text {
                        anchors.centerIn: parent
                        text: "↶"
                        color: "black"
                        font.pixelSize: parent.height * 0.70
                        font.bold: true
                    }
                    MouseArea {
                        id: areaAtras9
                        anchors.fill: parent
                        onClicked: {
                            mainWindow.limpiarDatos(false);
                            estadoActual = "pantalla_nuevo_proyecto"
                        }
                    }
                }

                PopupIngresoNombre {
                    id: popupGuardar9
                    visible: pantallaProyectosGuardados.mostrarPopupGuardar
                    tituloPopup: qsTr("Ingrese nombre del experimento")
                    onAceptado: function(name) {
                        var nombreFinal = name.trim();
                        if (nombreFinal === "") {
                            var d = new Date();
                            nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
                        }
                        var_nombre_experimento = nombreFinal;
                        pantallaProyectosGuardados.mostrarPopupGuardar = false;
                        pantallaProyectosGuardados.mostrarPopupConfirmacion = true;
                    }
                    onCancelado: {
                        pantallaProyectosGuardados.mostrarPopupGuardar = false;
                    }
                }

                PopupConfirmarProceso {
                    id: popupConfirmacion9
                    visible: pantallaProyectosGuardados.mostrarPopupConfirmacion
                    nombreProyecto: var_nombre_proyecto
                    nombreExperimento: var_nombre_experimento
                    temp: var_deseada_Tem
                    ph: var_deseada_pH
                    agua: var_deseada_Agua
                    luz: var_deseada_Luz
                    tiempoSemanas: var_deseada_tiempo_semanas
                    tiempoDias: var_deseada_tiempo_dias
                    tiempoHoras: var_deseada_tiempo_horas
                    tiempoMinutos: var_deseada_tiempo_minutos
                    tiempoTotal: var_deseada_tiempo_total_horas
                unidadTemperatura: mainWindow.unidadTemperatura

                    onConfirmado: {
                        pantallaProyectosGuardados.mostrarPopupConfirmacion = false;
                        var d = new Date();
                        var cadenaFecha = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear();
                        registro_experimentos.append({
                            "proyecto": var_nombre_proyecto,
                            "experimento": var_nombre_experimento,
                            "fecha": cadenaFecha,
                            "tiempo": "0.0 / " + var_deseada_tiempo_total_horas.toFixed(1) + " hrs",
                            "peso": (Math.random() * 5 + 0.5).toFixed(1) + " MB",
                            "seleccionado": false
                        });
                        estadoActual = "pantalla_7"
                    }
                    onCancelado: {
                        pantallaProyectosGuardados.mostrarPopupConfirmacion = false;
                    }
                }

                // --- POPUP OPCIONES (Lápiz y Papelera) ---
                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaProyectosGuardados.mostrarPopupOpciones
                    MouseArea { anchors.fill: parent; hoverEnabled: true }

                    Rectangle {
                        width: parent.width * 0.50
                        height: parent.height * 0.45
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.10
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Opciones del proyecto")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                        }

                        Row {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -10
                            spacing: mainWindow.width * 0.05

                            // Botón Lápiz
                            Rectangle {
                                width: mainWindow.width * 0.12
                                height: width
                                radius: 20
                                color: areaLapizOpt.pressed ? "#d1d5db" : "#F3F4F6"
                                Image { source: "Lapiz.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                                MouseArea {
                                    id: areaLapizOpt
                                    anchors.fill: parent
                                    onClicked: {
                                        let item = datos_guardados.get(pantallaProyectosGuardados.indexEditando);
                                        datosEdicion.nombre = item.nombre;
                                        datosEdicion.temp = item.temp;
                                        datosEdicion.ph = item.ph;
                                        datosEdicion.agua = item.agua;
                                        datosEdicion.luz = item.luz;
                                        datosEdicion.tiempo = item.tiempo;
                                        pantallaProyectosGuardados.mostrarPopupOpciones = false;
                                        pantallaProyectosGuardados.mostrarPopupEdicionProyecto = true;
                                    }
                                }
                            }

                            // Botón Papelera
                            Rectangle {
                                width: mainWindow.width * 0.12
                                height: width
                                radius: 20
                                color: areaPapeleraOpt.pressed ? "#d1d5db" : "#F3F4F6"
                                Image { source: "Basura.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                                MouseArea {
                                    id: areaPapeleraOpt
                                    anchors.fill: parent
                                    onClicked: {
                                        pantallaProyectosGuardados.mostrarPopupOpciones = false;
                                        pantallaProyectosGuardados.mostrarPopupBorrarGuardado = true;
                                    }
                                }
                            }
                        }

                        // Botón Flecha Atras
                        Rectangle {
                            width: mainWindow.width * 0.12
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.08
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: areaAtrasOpt.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                            MouseArea { id: areaAtrasOpt; anchors.fill: parent; onClicked: pantallaProyectosGuardados.mostrarPopupOpciones = false }
                        }
                    }
                }

                // --- POPUP CONFIRMACIÓN DE BORRADO INDIVIDUAL ---
                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaProyectosGuardados.mostrarPopupBorrarGuardado
                    MouseArea { anchors.fill: parent; hoverEnabled: true }

                    Rectangle {
                        width: parent.width * 0.50
                        height: parent.height * 0.40
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("¿Desea borrar este proyecto guardado?")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.9
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: mainWindow.width * 0.12
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            color: areaOkBorrar.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            MouseArea {
                                id: areaOkBorrar;
                                anchors.fill: parent;
                                onClicked: {
                                    datos_guardados.remove(pantallaProyectosGuardados.indexEditando);
                                    pantallaProyectosGuardados.mostrarPopupBorrarGuardado = false;
                                }
                            }
                        }

                        Rectangle {
                            width: mainWindow.width * 0.12
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            color: areaAtrasBorrar.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                            MouseArea { id: areaAtrasBorrar; anchors.fill: parent; onClicked: pantallaProyectosGuardados.mostrarPopupBorrarGuardado = false }
                        }
                    }
                }

                // --- POPUP EDICIÓN DE DATOS ---
                Item {
                    id: popupEdicionDatosRoot
                    anchors.fill: parent
                    z: 200
                    visible: pantallaProyectosGuardados.mostrarPopupEdicionProyecto

                    // Clic en la pantalla de fondo oculta el teclado
                    MouseArea {
                        anchors.fill: parent;
                        hoverEnabled: true
                        onClicked: {
                            pantallaProyectosGuardados.campoEditActivo = "";
                        }
                    }

                    // Control global del teclado de la computadora y límites min/max
                    focus: visible
                    Keys.onPressed: (event) => {
                        if (pantallaProyectosGuardados.campoEditActivo === "Nombre") {
                            if (event.key === Qt.Key_Backspace) {
                                if (datosEdicion.nombre.length > 0)
                                    datosEdicion.nombre = datosEdicion.nombre.substring(0, datosEdicion.nombre.length - 1);
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                pantallaProyectosGuardados.campoEditActivo = "";
                            } else if (event.text.length > 0) {
                                datosEdicion.nombre += event.text;
                            }
                            event.accepted = true;
                        } else if (pantallaProyectosGuardados.campoEditActivo !== "") {
                            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                                let digito = (event.key - Qt.Key_0).toString()
                                pantallaProyectosGuardados.entradaEditTemporal = (pantallaProyectosGuardados.entradaEditTemporal === "0") ? digito : pantallaProyectosGuardados.entradaEditTemporal + digito
                                event.accepted = true
                            } else if (event.key === Qt.Key_Period) {
                                if (pantallaProyectosGuardados.entradaEditTemporal.indexOf(".") === -1) {
                                    pantallaProyectosGuardados.entradaEditTemporal += (pantallaProyectosGuardados.entradaEditTemporal === "" ? "0." : ".")
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Backspace) {
                                if (pantallaProyectosGuardados.entradaEditTemporal.length > 0) {
                                    pantallaProyectosGuardados.entradaEditTemporal = pantallaProyectosGuardados.entradaEditTemporal.substring(0, pantallaProyectosGuardados.entradaEditTemporal.length - 1)
                                }
                                event.accepted = true
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                let val = parseFloat(pantallaProyectosGuardados.entradaEditTemporal);
                                if (!isNaN(val)) {
                                    if (pantallaProyectosGuardados.campoEditActivo === "Tem") {
                                        let minT = mainWindow.unidadTemperatura === "C" ? 20 : 68;
                                        let maxT = mainWindow.unidadTemperatura === "C" ? 100 : 212;
                                                        datosEdicion.temp = Math.max(minT, Math.min(maxT, val));
                                    }
                                    else if (pantallaProyectosGuardados.campoEditActivo === "pH") datosEdicion.ph = Math.max(1, Math.min(14, val));
                                    else if (pantallaProyectosGuardados.campoEditActivo === "Agua") datosEdicion.agua = Math.max(30, Math.min(100, val));
                                    else if (pantallaProyectosGuardados.campoEditActivo === "Luz") datosEdicion.luz = Math.max(0, Math.min(100, val));
                                    else if (pantallaProyectosGuardados.campoEditActivo === "Tiempo") datosEdicion.tiempo = Math.max(6, val).toString();
                                }
                                pantallaProyectosGuardados.campoEditActivo = "";
                                pantallaProyectosGuardados.entradaEditTemporal = "";
                                event.accepted = true
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width * 0.80
                        height: parent.height * 0.85
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20
                        clip: true

                        MouseArea {
                            anchors.fill: parent
                            onClicked: pantallaProyectosGuardados.campoEditActivo = ""
                        }

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Editar Proyecto")
                            font.pixelSize: parent.height * 0.06
                            font.bold: true
                            color: "black"
                        }

                        Row {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.95
                            height: parent.height * 0.45
                            spacing: 15

                            // --- COLUMNA IZQUIERDA: Píldoras verdes ---
                            Column {
                                width: parent.width * 0.55
                                height: parent.height
                                spacing: parent.height * 0.035

                                // 1. Nombre
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "Nombre" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Nombre:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.35; anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: pantallaProyectosGuardados.campoEditActivo === "Nombre" ? datosEdicion.nombre + "|" : datosEdicion.nombre; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black"; elide: Text.ElideRight }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "Nombre"; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                                // 2. Temp
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "Tem" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Temp °%1:").arg(mainWindow.unidadTemperatura); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (pantallaProyectosGuardados.campoEditActivo === "Tem" ? pantallaProyectosGuardados.entradaEditTemporal + "|" : datosEdicion.temp); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "Tem"; pantallaProyectosGuardados.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                                // 3. pH
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "pH" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Nivel de pH:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (pantallaProyectosGuardados.campoEditActivo === "pH" ? pantallaProyectosGuardados.entradaEditTemporal + "|" : datosEdicion.ph); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "pH"; pantallaProyectosGuardados.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                                // 4. Agua
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "Agua" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Nivel agua %:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (pantallaProyectosGuardados.campoEditActivo === "Agua" ? pantallaProyectosGuardados.entradaEditTemporal + "|" : datosEdicion.agua); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "Agua"; pantallaProyectosGuardados.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                                // 5. Luz
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "Luz" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Nivel luz %:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (pantallaProyectosGuardados.campoEditActivo === "Luz" ? pantallaProyectosGuardados.entradaEditTemporal + "|" : datosEdicion.luz); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "Luz"; pantallaProyectosGuardados.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                                // 6. Tiempo
                                Rectangle {
                                    width: parent.width; height: parent.height * 0.13; radius: height/2; color: pantallaProyectosGuardados.campoEditActivo === "Tiempo" ? "#A5D6A7" : "#8DBB5A"
                                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Duración (h):"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: (pantallaProyectosGuardados.campoEditActivo === "Tiempo" ? pantallaProyectosGuardados.entradaEditTemporal + "|" : datosEdicion.tiempo); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                    MouseArea { anchors.fill: parent; onClicked: { pantallaProyectosGuardados.campoEditActivo = "Tiempo"; pantallaProyectosGuardados.entradaEditTemporal = ""; popupEdicionDatosRoot.forceActiveFocus(); } }
                                }
                            }

                            // --- COLUMNA DERECHA: Teclado Númerico Visual ---
                            TecladoNumerico {
                                width: parent.width * 0.45 - 15
                                height: parent.height * 0.95
                                anchors.verticalCenter: parent.verticalCenter
                                visible: pantallaProyectosGuardados.campoEditActivo !== "" && pantallaProyectosGuardados.campoEditActivo !== "Nombre"
                                onDigitoPresionado: function(d) { pantallaProyectosGuardados.entradaEditTemporal = pantallaProyectosGuardados.entradaEditTemporal === "0" ? d : pantallaProyectosGuardados.entradaEditTemporal + d }
                                onPuntoPresionado:  { if (pantallaProyectosGuardados.entradaEditTemporal.indexOf(".") === -1) pantallaProyectosGuardados.entradaEditTemporal += pantallaProyectosGuardados.entradaEditTemporal === "" ? "0." : "." }
                                onBorrarPresionado: { if (pantallaProyectosGuardados.entradaEditTemporal.length > 0) pantallaProyectosGuardados.entradaEditTemporal = pantallaProyectosGuardados.entradaEditTemporal.slice(0, -1) }
                                onOkPresionado: {
                                    let val = parseFloat(pantallaProyectosGuardados.entradaEditTemporal);
                                    if (!isNaN(val)) {
                                        if (pantallaProyectosGuardados.campoEditActivo === "Tem") {
                                            let minT = mainWindow.unidadTemperatura === "C" ? 20 : 68;
                                            let maxT = mainWindow.unidadTemperatura === "C" ? 100 : 212;
                                            datosEdicion.temp = Math.max(minT, Math.min(maxT, val));
                                        }
                                        else if (pantallaProyectosGuardados.campoEditActivo === "pH") datosEdicion.ph = Math.max(1, Math.min(14, val));
                                        else if (pantallaProyectosGuardados.campoEditActivo === "Agua") datosEdicion.agua = Math.max(30, Math.min(100, val));
                                        else if (pantallaProyectosGuardados.campoEditActivo === "Luz") datosEdicion.luz = Math.max(0, Math.min(100, val));
                                        else if (pantallaProyectosGuardados.campoEditActivo === "Tiempo") datosEdicion.tiempo = Math.max(6, val).toString();
                                    }
                                    pantallaProyectosGuardados.campoEditActivo = "";
                                    pantallaProyectosGuardados.entradaEditTemporal = "";
                                }
                            }
                        }

                        // Botón Estático OK
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 30
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.15
                            color: areaOkEdit.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            MouseArea {
                                id: areaOkEdit;
                                anchors.fill: parent;
                                enabled: pantallaProyectosGuardados.campoEditActivo === ""
                                onClicked: {
                                    pantallaProyectosGuardados.mostrarPopupEdicionProyecto = false;
                                    pantallaProyectosGuardados.mostrarPopupConfirmarEdicion = true;
                                }
                            }
                        }

                        // Botón Estático ATRÁS
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 30
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.15
                            color: areaAtrasEdit.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                            MouseArea {
                                id: areaAtrasEdit;
                                anchors.fill: parent;
                                enabled: pantallaProyectosGuardados.campoEditActivo === ""
                                onClicked: {
                                    pantallaProyectosGuardados.campoEditActivo = "";
                                    pantallaProyectosGuardados.mostrarPopupEdicionProyecto = false;
                                }
                            }
                        }

                        // --- TECLADO QWERTY RETRAÍBLE ---
                        TecladoQwerty {
                            id: tecladoQwertyEdit
                            z: 100
                            width: parent.width * 0.95
                            height: parent.height * 0.35
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: pantallaProyectosGuardados.campoEditActivo === "Nombre" ? 10 : parent.height * -0.50
                            Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            onTeclaPresionada:  function(t) { datosEdicion.nombre += t }
                            onBorrarPresionado: { if (datosEdicion.nombre.length > 0) datosEdicion.nombre = datosEdicion.nombre.slice(0, -1) }
                            onIntroPresionado:  { pantallaProyectosGuardados.campoEditActivo = "" }
                            onCerrarPresionado: { pantallaProyectosGuardados.campoEditActivo = "" }
                        }
                    }
                }

                // --- POPUP CONFIRMACIÓN EDICIÓN FINAL ---
                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaProyectosGuardados.mostrarPopupConfirmarEdicion
                    MouseArea { anchors.fill: parent; hoverEnabled: true }

                    Rectangle {
                        id: cajaConfirmarEdicion
                        width: parent.width * 0.85
                        height: parent.height * 0.65
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: cajaConfirmarEdicion.height * 0.05
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.9
                            text: qsTr("¿Estás seguro que quieres guardar los cambios hechos al proyecto?")
                            font.pixelSize: cajaConfirmarEdicion.height * 0.06
                            font.bold: false
                            color: "#cc0000"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Column {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: cajaConfirmarEdicion.height * 0.02
                                            width: parent.width * 0.90
                                            spacing: cajaConfirmarEdicion.height * 0.03

                                            // Fila 1: Proyecto
                                            Text {
                                                textFormat: Text.RichText
                                                text: qsTr("Proyecto: <b>%1</b>").arg(datosEdicion.nombre)
                                                font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                color: "black"
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                            }

                                            // Fila 2: Temp y pH
                                            Row {
                                                width: parent.width
                                                spacing: parent.width * 0.02
                                                Text {
                                                    width: (parent.width/2)-(parent.width*0.01)
                                                    textFormat: Text.RichText
                                                    text: qsTr("Temperatura: <b>%1 °%2</b>").arg(datosEdicion.temp.toFixed(1)).arg(mainWindow.unidadTemperatura)
                                                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                    color: "black"
                                                    wrapMode: Text.WordWrap
                                                }
                                                Text {
                                                    width: (parent.width/2)-(parent.width*0.01)
                                                    textFormat: Text.RichText
                                                    text: qsTr("Nivel de pH: <b>%1</b>").arg(datosEdicion.ph.toFixed(1))
                                                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                    color: "black"
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            // Fila 3: Agua y Luz
                                            Row {
                                                width: parent.width
                                                spacing: parent.width * 0.02
                                                Text {
                                                    width: (parent.width/2)-(parent.width*0.01)
                                                    textFormat: Text.RichText
                                                    text: qsTr("Nivel de agua: <b>%1 %</b>").arg(datosEdicion.agua.toFixed(1))
                                                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                    color: "black"
                                                    wrapMode: Text.WordWrap
                                                }
                                                Text {
                                                    width: (parent.width/2)-(parent.width*0.01)
                                                    textFormat: Text.RichText
                                                    text: qsTr("Nivel de luz: <b>%1 %</b>").arg(datosEdicion.luz.toFixed(1))
                                                    font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                    color: "black"
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            // Fila 4: Tiempo
                                            Text {
                                                textFormat: Text.RichText
                                                property int t_total: parseFloat(datosEdicion.tiempo) || 0
                                                property int t_semanas: Math.floor(t_total / 168)
                                                property int t_dias: Math.floor((t_total % 168) / 24)
                                                property int t_horas: Math.floor(t_total % 24)
                                                property int t_minutos: Math.round((t_total - Math.floor(t_total)) * 60)

                                                text: qsTr("Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)").arg(t_semanas).arg(t_dias).arg(t_horas).arg(t_minutos).arg(t_total.toFixed(1))
                                                font.pixelSize: cajaConfirmarEdicion.height * 0.055
                                                color: "black"
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                            }
                                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: mainWindow.width * 0.05
                            anchors.bottomMargin: cajaConfirmarEdicion.height * 0.05
                            width: mainWindow.width * 0.20
                            height: mainWindow.height * 0.10
                            color: areaOkConfirmEdit.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            MouseArea {
                                id: areaOkConfirmEdit;
                                anchors.fill: parent;
                                onClicked: {
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "nombre", datosEdicion.nombre);
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "temp", datosEdicion.temp);
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "ph", datosEdicion.ph);
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "agua", datosEdicion.agua);
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "luz", datosEdicion.luz);
                                    datos_guardados.setProperty(pantallaProyectosGuardados.indexEditando, "tiempo", datosEdicion.tiempo);
                                    pantallaProyectosGuardados.mostrarPopupConfirmarEdicion = false;
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: mainWindow.width * 0.05
                            anchors.bottomMargin: cajaConfirmarEdicion.height * 0.05
                            width: mainWindow.width * 0.12
                            height: mainWindow.height * 0.10
                            color: areaAtrasConfirmEdit.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                            MouseArea { id: areaAtrasConfirmEdit; anchors.fill: parent; onClicked: pantallaProyectosGuardados.mostrarPopupConfirmarEdicion = false }
                        }
                    }
                }
            }

            // 10. CONFIGURACIÓN DE GRÁFICAS
            Item {
                id: pantallaConfigGraficas
                anchors.fill: parent
                visible: estadoActual === "pantalla_configuracion_graficas"

                Text {
                    text: qsTr("Selecciona la gráfica deseada")
                    font.pixelSize: mainWindow.height * 0.08
                    font.bold: true
                    color: "black"
                    anchors.top: parent.top
                    anchors.topMargin: mainWindow.height * 0.15
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Grid {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: mainWindow.height * 0.05
                    columns: 2
                    spacing: mainWindow.width * 0.05
                    rowSpacing: mainWindow.height * 0.05

                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.12
                        radius: height / 2
                        color: var_seleccion_grafica === 1 ? "#7da84c" : "#8DBB5A"
                        border.width: var_seleccion_grafica === 1 ? 4 : 0
                        border.color: "#4a6b4a"
                        Text { anchors.centerIn: parent; text: qsTr("Temperatura °%1").arg(mainWindow.unidadTemperatura); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: var_seleccion_grafica = 1 }
                    }
                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.12
                        radius: height / 2
                        color: var_seleccion_grafica === 2 ? "#7da84c" : "#8DBB5A"
                        border.width: var_seleccion_grafica === 2 ? 4 : 0
                        border.color: "#4a6b4a"
                        Text { anchors.centerIn: parent; text: qsTr("Nivel Agua"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: var_seleccion_grafica = 2 }
                    }
                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.12
                        radius: height / 2
                        color: var_seleccion_grafica === 3 ? "#7da84c" : "#8DBB5A"
                        border.width: var_seleccion_grafica === 3 ? 4 : 0
                        border.color: "#4a6b4a"
                        Text { anchors.centerIn: parent; text: qsTr("Nivel de pH"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: var_seleccion_grafica = 3 }
                    }
                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.12
                        radius: height / 2
                        color: var_seleccion_grafica === 4 ? "#7da84c" : "#8DBB5A"
                        border.width: var_seleccion_grafica === 4 ? 4 : 0
                        border.color: "#4a6b4a"
                        Text { anchors.centerIn: parent; text: qsTr("Nivel de Luz"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                        MouseArea { anchors.fill: parent; onClicked: var_seleccion_grafica = 4 }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: parent.width * 0.05
                    width: parent.width * 0.12
                    height: parent.height * 0.10
                    color: areaAtrasGraficas.pressed ? "#cc1e1e" : "#FF2D2D"
                    radius: height / 2
                    Text {
                        anchors.centerIn: parent
                        text: "↶"
                        color: "black"
                        font.pixelSize: parent.height * 0.70
                        font.bold: true
                    }
                    MouseArea {
                        id: areaAtrasGraficas
                        anchors.fill: parent
                        onClicked: estadoActual = "pantalla_procesos"
                    }
                }
            }

            // 11. POST-PROCESO
            Item {
                id: pantallaPostProceso
                anchors.fill: parent
                visible: estadoActual === "pantalla_11"

                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: mainWindow.height * 0.05
                    spacing: mainWindow.width * 0.05

                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.45
                        radius: 20
                        color: areaNuevaConfig.pressed ? "#7da84c" : "#8DBB5A"
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Nueva\nconfiguración")
                            font.pixelSize: parent.height * 0.15
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: areaNuevaConfig
                            anchors.fill: parent
                            onClicked: {
                                estadoPrevioPantalla6 = "pantalla_11";
                                omitirPedirNombre = true;
                                mainWindow.limpiarDatos(true);
                                estadoActual = "pantalla_6";
                            }
                        }
                    }

                    Rectangle {
                        width: mainWindow.width * 0.35
                        height: mainWindow.height * 0.45
                        radius: 20
                        color: areaComenzarExtraccion.pressed ? "#5a8282" : "#6E9C9C"
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Comenzar\nextracción")
                            font.pixelSize: parent.height * 0.15
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: areaComenzarExtraccion
                            anchors.fill: parent
                            onClicked: estadoActual = "pantalla_12"
                        }
                    }
                }
            }

            // 12. EXTRACCIÓN (Vaciado)
            Item {
                id: pantallaExtraccion
                anchors.fill: parent
                visible: estadoActual === "pantalla_12"

                property bool nivel1Completado: false
                property bool mostrarConfirmacion1: false
                property bool mostrarProceso1: false
                property bool mostrarConfirmacion2: false
                property bool mostrarProceso2: false
                property bool mostrarPopupFinalizado: false

                onVisibleChanged: {
                    if (visible) {
                        nivel1Completado = false;
                        mostrarConfirmacion1 = false;
                        mostrarProceso1 = false;
                        mostrarConfirmacion2 = false;
                        mostrarProceso2 = false;
                        mostrarPopupFinalizado = false;
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: mainWindow.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: mainWindow.height * 0.05
                    spacing: mainWindow.height * 0.05

                    Rectangle {
                        width: mainWindow.width * 0.50
                        height: mainWindow.height * 0.15
                        radius: height / 2
                        color: pantallaExtraccion.nivel1Completado ? "#A9B29B" : (areaVaciadoNivel1.pressed ? "#7da84c" : "#8DBB5A")
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Vaciado de nivel 1")
                            font.pixelSize: parent.height * 0.45
                            font.bold: true
                            color: pantallaExtraccion.nivel1Completado ? "#707070" : "black"
                        }
                        MouseArea {
                            id: areaVaciadoNivel1
                            anchors.fill: parent
                            enabled: !pantallaExtraccion.nivel1Completado
                            onClicked: pantallaExtraccion.mostrarConfirmacion1 = true
                        }
                    }

                    Rectangle {
                        width: mainWindow.width * 0.50
                        height: mainWindow.height * 0.15
                        radius: height / 2
                        color: !pantallaExtraccion.nivel1Completado ? "#A9B29B" : (areaVaciadoNivel2.pressed ? "#7da84c" : "#8DBB5A")
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Vaciado de nivel 2")
                            font.pixelSize: parent.height * 0.45
                            font.bold: true
                            color: !pantallaExtraccion.nivel1Completado ? "#707070" : "black"
                        }
                        MouseArea {
                            id: areaVaciadoNivel2
                            anchors.fill: parent
                            enabled: pantallaExtraccion.nivel1Completado
                            onClicked: pantallaExtraccion.mostrarConfirmacion2 = true
                        }
                    }
                }

                Image {
                    source: "Hongo_7.png"
                    anchors.right: parent.right
                    anchors.rightMargin: mainWindow.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: mainWindow.height * 0.05
                    width: mainWindow.width * 0.30
                    fillMode: Image.PreserveAspectFit
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaExtraccion.mostrarConfirmacion1
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.60
                        height: parent.height * 0.40
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20
                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("¿Iniciar vaciado de nivel 1?")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            color: areaOkConfirmar1.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkConfirmar1
                                anchors.fill: parent
                                onClicked: {
                                    pantallaExtraccion.mostrarConfirmacion1 = false;
                                    pantallaExtraccion.mostrarProceso1 = true;
                                }
                            }
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            color: areaAtrasConfirmar1.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: "↶"
                                font.pixelSize: parent.height * 0.70
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaAtrasConfirmar1
                                anchors.fill: parent
                                onClicked: pantallaExtraccion.mostrarConfirmacion1 = false
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaExtraccion.mostrarProceso1
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height * 0.55
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Vaciado de nivel 1 en proceso,\nespere un momento por favor :)")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.9
                            wrapMode: Text.WordWrap
                        }
                    }
                    Timer {
                        interval: var_vaciado_nivel_1
                        running: pantallaExtraccion.mostrarProceso1
                        onTriggered: {
                            pantallaExtraccion.mostrarProceso1 = false;
                            pantallaExtraccion.nivel1Completado = true;
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaExtraccion.mostrarConfirmacion2
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.60
                        height: parent.height * 0.40
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20
                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("¿Iniciar vaciado de nivel 2?")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            color: areaOkConfirmar2.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkConfirmar2
                                anchors.fill: parent
                                onClicked: {
                                    pantallaExtraccion.mostrarConfirmacion2 = false;
                                    pantallaExtraccion.mostrarProceso2 = true;
                                }
                            }
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            color: areaAtrasConfirmar2.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: "↶"
                                font.pixelSize: parent.height * 0.70
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaAtrasConfirmar2
                                anchors.fill: parent
                                onClicked: pantallaExtraccion.mostrarConfirmacion2 = false
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaExtraccion.mostrarProceso2
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height * 0.55
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Vaciado de nivel 2 en proceso,\nespere un momento por favor :)")
                            font.pixelSize: parent.height * 0.10
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.9
                            wrapMode: Text.WordWrap
                        }
                    }
                    Timer {
                        interval: var_vaciado_nivel_2
                        running: pantallaExtraccion.mostrarProceso2
                        onTriggered: {
                            pantallaExtraccion.mostrarProceso2 = false;
                            pantallaExtraccion.mostrarPopupFinalizado = true;
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaExtraccion.mostrarPopupFinalizado
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height * 0.55
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -parent.height * 0.10
                            text: qsTr("Proceso de cultivo\nfinalizado")
                            font.pixelSize: parent.height * 0.18
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: mainWindow.width * 0.20
                            height: mainWindow.height * 0.10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.10
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: areaOkFinalCosecha.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkFinalCosecha
                                anchors.fill: parent
                                onClicked: {
                                    pantallaExtraccion.mostrarPopupFinalizado = false;
                                    estadoActual = "pantalla_13";
                                }
                            }
                        }
                    }
                }
            }

            // 13. GUARDADO DE CONFIGURACIÓN
            Item {
                id: pantallaGuardarConfig
                anchors.fill: parent
                visible: estadoActual === "pantalla_13"

                property bool mostrarPopupNoConfirmar: false
                property bool mostrarPopupIngresoNombre: false
                property bool mostrarPopupConfirmarDatos: false
                property bool mostrarPopupGuardado: false

                onVisibleChanged: {
                    if (visible) {
                        mostrarPopupNoConfirmar = false;
                        mostrarPopupIngresoNombre = false;
                        mostrarPopupConfirmarDatos = false;
                        mostrarPopupGuardado = false;
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: mainWindow.height * 0.10

                    Text {
                        text: qsTr("¿Desea guardar la\nconfiguración?")
                        font.pixelSize: mainWindow.height * 0.12
                        font.bold: true
                        color: "black"
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        spacing: mainWindow.width * 0.10
                        anchors.horizontalCenter: parent.horizontalCenter

                        Rectangle {
                            width: mainWindow.width * 0.25
                            height: mainWindow.height * 0.15
                            radius: 30
                            color: areaBtnSi.pressed ? "#6b42b5" : "#8b5cf6"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Si")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaBtnSi
                                anchors.fill: parent
                                onClicked: pantallaGuardarConfig.mostrarPopupIngresoNombre = true
                            }
                        }

                        Rectangle {
                            width: mainWindow.width * 0.25
                            height: mainWindow.height * 0.15
                            radius: 30
                            color: areaBtnNo.pressed ? "#cc1e1e" : "#FF2D2D"
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("No")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaBtnNo
                                anchors.fill: parent
                                onClicked: pantallaGuardarConfig.mostrarPopupNoConfirmar = true
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaGuardarConfig.mostrarPopupNoConfirmar
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.60
                        height: parent.height * 0.40
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20
                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("¿Seguro que no deseas guardar la configuración?")
                            font.pixelSize: parent.height * 0.08
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.9
                            wrapMode: Text.WordWrap
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            color: areaOkNoConfirmado.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkNoConfirmado
                                anchors.fill: parent
                                onClicked: {
                                    pantallaGuardarConfig.mostrarPopupNoConfirmar = false;
                                    estadoActual = "pantalla_14";
                                }
                            }
                        }
                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            color: areaAtrasNoConfirmado.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: "↶"
                                font.pixelSize: parent.height * 0.70
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaAtrasNoConfirmado
                                anchors.fill: parent
                                onClicked: pantallaGuardarConfig.mostrarPopupNoConfirmar = false
                            }
                        }
                    }
                }

                PopupIngresoNombre {
                    id: popupGuardadoProyecto13
                    visible: pantallaGuardarConfig.mostrarPopupIngresoNombre
                    tituloPopup: qsTr("Ingrese el nombre del proyecto")
                    nombrePorDefecto: ""
                    onAceptado: function(name) {
                        var nombreFinal = name.trim();
                        if (nombreFinal === "") {
                            var d = new Date();
                            nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
                        }
                        var_nombre_proyecto = nombreFinal;
                        pantallaGuardarConfig.mostrarPopupIngresoNombre = false;
                        pantallaGuardarConfig.mostrarPopupConfirmarDatos = true;
                    }
                    onCancelado: {
                        pantallaGuardarConfig.mostrarPopupIngresoNombre = false;
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaGuardarConfig.mostrarPopupConfirmarDatos
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        id: cajaPopupGuardar13
                        width: parent.width * 0.85
                        height: parent.height * 0.65
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: cajaPopupGuardar13.height * 0.05
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.9
                            text: qsTr("El proyecto se guardará como:")
                            font.pixelSize: cajaPopupGuardar13.height * 0.06
                            font.bold: false
                            color: "#cc0000"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cajaPopupGuardar13.height * 0.02
                            width: parent.width * 0.90
                            spacing: cajaPopupGuardar13.height * 0.03

                            Text {
                                textFormat: Text.RichText
                                text: qsTr("Proyecto: <b>%1</b>").arg(var_nombre_proyecto)
                                font.pixelSize: cajaPopupGuardar13.height * 0.055
                                color: "black"
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                            Row {
                                width: parent.width
                                spacing: parent.width * 0.02
                                Text {
                                    width: (parent.width/2)-(parent.width*0.01)
                                    textFormat: Text.RichText
                                    text: qsTr("Temperatura: <b>%1 °%2</b>").arg(var_deseada_Tem).arg(mainWindow.unidadTemperatura)
                                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                                    color: "black"
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: (parent.width/2)-(parent.width*0.01)
                                    textFormat: Text.RichText
                                    text: qsTr("Nivel de pH: <b>%1</b>").arg(var_deseada_pH)
                                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                                    color: "black"
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: parent.width * 0.02
                                Text {
                                    width: (parent.width/2)-(parent.width*0.01)
                                    textFormat: Text.RichText
                                    text: qsTr("Nivel de agua: <b>%1 %</b>").arg(var_deseada_Agua)
                                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                                    color: "black"
                                    wrapMode: Text.WordWrap
                                }
                                Text {
                                    width: (parent.width/2)-(parent.width*0.01)
                                    textFormat: Text.RichText
                                    text: qsTr("Nivel de luz: <b>%1 %</b>").arg(var_deseada_Luz)
                                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                                    color: "black"
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Text {
                                textFormat: Text.RichText
                                text: qsTr("Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)").arg(var_deseada_tiempo_semanas).arg(var_deseada_tiempo_dias).arg(var_deseada_tiempo_horas).arg(var_deseada_tiempo_minutos).arg(var_deseada_tiempo_total_horas.toFixed(1))
                                font.pixelSize: cajaPopupGuardar13.height * 0.055
                                color: "black"
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: mainWindow.width * 0.05
                            anchors.bottomMargin: parent.height * 0.05
                            width: mainWindow.width * 0.20
                            height: mainWindow.height * 0.10
                            color: areaOkGuardarFinal.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                color: "black"
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                            }
                            MouseArea {
                                id: areaOkGuardarFinal
                                anchors.fill: parent
                                onClicked: {
                                    let lastIdx = registro_experimentos.count - 1;
                                    if (lastIdx >= 0) {
                                        registro_experimentos.setProperty(lastIdx, "proyecto", var_nombre_proyecto);
                                    }
                                    datos_guardados.append({
                                        nombre: var_nombre_proyecto,
                                        temp: var_deseada_Tem,
                                        ph: var_deseada_pH,
                                        agua: var_deseada_Agua,
                                        luz: var_deseada_Luz,
                                        tiempo: var_deseada_tiempo_total_horas.toFixed(1)
                                    });
                                    pantallaGuardarConfig.mostrarPopupConfirmarDatos = false;
                                    pantallaGuardarConfig.mostrarPopupGuardado = true;
                                }
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: mainWindow.width * 0.05
                            anchors.bottomMargin: parent.height * 0.05
                            width: mainWindow.width * 0.12
                            height: mainWindow.height * 0.10
                            color: areaAtrasGuardarFinal.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: "↶"
                                color: "black"
                                font.pixelSize: parent.height * 0.70
                                font.bold: true
                            }
                            MouseArea {
                                id: areaAtrasGuardarFinal
                                anchors.fill: parent
                                onClicked: {
                                    pantallaGuardarConfig.mostrarPopupConfirmarDatos = false;
                                    pantallaGuardarConfig.mostrarPopupIngresoNombre = true;
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaGuardarConfig.mostrarPopupGuardado
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height * 0.55
                        anchors.centerIn: parent
                        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
                        radius: 20
                        Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -parent.height * 0.10
                            text: qsTr("Guardado :D")
                            font.pixelSize: parent.height * 0.25
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Rectangle {
                            width: mainWindow.width * 0.20
                            height: mainWindow.height * 0.10
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.10
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: areaOkPopGuardado.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkPopGuardado
                                anchors.fill: parent
                                onClicked: {
                                    pantallaGuardarConfig.mostrarPopupGuardado = false;
                                    estadoActual = "pantalla_14";
                                }
                            }
                        }
                    }
                }
            }

            // 14. RECORDATORIO DE LIMPIEZA
            Item {
                id: pantallaLimpieza
                anchors.fill: parent
                visible: estadoActual === "pantalla_14"

                Text {
                    text: qsTr("Recuerda limpiar el\nbiorreactor ;)")
                    font.pixelSize: mainWindow.height * 0.12
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    anchors.top: parent.top
                    anchors.topMargin: mainWindow.height * 0.20
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Image {
                    source: "Hongo_8.png"
                    anchors.left: parent.left
                    anchors.leftMargin: mainWindow.width * 0.05
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: mainWindow.height * 0.05
                    height: mainWindow.height * 0.315
                    fillMode: Image.PreserveAspectFit
                }

                Image {
                    source: "Hongo_9.png"
                    anchors.right: parent.right
                    anchors.rightMargin: mainWindow.width * 0.05
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: mainWindow.height * 0.05
                    height: mainWindow.height * 0.315
                    fillMode: Image.PreserveAspectFit
                }

                Rectangle {
                    width: mainWindow.width * 0.20
                    height: mainWindow.height * 0.12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: mainWindow.height * 0.15
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: areaOkLimpieza.pressed ? "#6b42b5" : "#8b5cf6"
                    radius: height / 2
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Okay")
                        font.pixelSize: parent.height * 0.40
                        font.bold: true
                        color: "black"
                    }
                    MouseArea {
                        id: areaOkLimpieza
                        anchors.fill: parent
                        onClicked: {
                            mainWindow.limpiarDatos(false);
                            omitirPedirNombre = false;
                            estadoActual = "pantalla_principal";
                        }
                    }
                }
            }

            // ==========================================
            // 15. PANTALLA DE REGISTRO / HISTORIAL
            // ==========================================
            Item {
                id: pantallaRegistro
                anchors.fill: parent
                visible: estadoActual === "pantalla_15"

                property bool modoBorrar: false
                property int itemsSeleccionados: 0
                property bool mostrarPopupConfirmarBorrado: false

                // Cabecera superior
                Rectangle {
                    id: cabeceraRegistro
                    width: parent.width * 0.95
                    height: mainWindow.height * 0.08
                    anchors.top: parent.top
                    anchors.topMargin: mainWindow.height * 0.18
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#6E9C9C"
                    radius: height / 2

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: parent.width * 0.02
                        anchors.rightMargin: parent.width * 0.02
                        spacing: parent.width * 0.01

                        Item { width: parent.width * 0.04; height: parent.height }

                        Item {
                            width: parent.width * 0.18
                            height: parent.height
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Proyecto"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
                        }
                        Item {
                            width: parent.width * 0.18
                            height: parent.height
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Experimento"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
                        }
                        Item {
                            width: parent.width * 0.14
                            height: parent.height
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Fecha"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
                        }
                        Item {
                            width: parent.width * 0.18
                            height: parent.height
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Tiempo"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
                        }
                        Item {
                            width: parent.width * 0.12
                            height: parent.height
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Tamaño"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
                        }
                        Item { width: parent.width * 0.10; height: parent.height }
                    }
                }

                // Lista de experimentos
                ListView {
                    id: listaRegistro
                    width: parent.width * 0.95
                    anchors.top: cabeceraRegistro.bottom
                    anchors.topMargin: mainWindow.height * 0.02
                    anchors.bottom: filaControlesInferiores.top
                    anchors.bottomMargin: mainWindow.height * 0.02
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true
                    spacing: mainWindow.height * 0.02
                    model: registro_experimentos

                    delegate: Rectangle {
                        width: parent.width
                        height: mainWindow.height * 0.08
                        color: "#8DBB5A"
                        radius: height / 2

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: parent.width * 0.02
                            anchors.rightMargin: parent.width * 0.02
                            spacing: parent.width * 0.01

                            // Checkbox de borrado
                            Item {
                                width: parent.width * 0.04
                                height: parent.height
                                Rectangle {
                                    visible: pantallaRegistro.modoBorrar
                                    width: parent.height * 0.4
                                    height: width
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    border.color: "black"
                                    border.width: 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: "X"
                                        font.pixelSize: parent.height * 0.8
                                        font.bold: true
                                        color: "black"
                                        visible: model.seleccionado
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            registro_experimentos.setProperty(index, "seleccionado", !model.seleccionado)
                                            pantallaRegistro.itemsSeleccionados += model.seleccionado ? 1 : -1
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width * 0.18
                                height: parent.height
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: model.proyecto
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true
                                    color: "black"
                                    elide: Text.ElideRight
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                            Item {
                                width: parent.width * 0.18
                                height: parent.height
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: model.experimento
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true
                                    color: "black"
                                    elide: Text.ElideRight
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                            Item {
                                width: parent.width * 0.14
                                height: parent.height
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: model.fecha
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                            Item {
                                width: parent.width * 0.18
                                height: parent.height
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: model.tiempo
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                            Item {
                                width: parent.width * 0.12
                                height: parent.height
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: model.peso
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true
                                    color: "black"
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }

                            Item {
                                width: parent.width * 0.10
                                height: parent.height
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.90
                                    height: parent.height * 0.6
                                    radius: height / 2
                                    color: areaBotonExportar.pressed ? "#b5b5b5" : "#E0E0E0"
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Exportar")
                                        font.pixelSize: parent.height * 0.35
                                        font.bold: true
                                        color: "black"
                                    }
                                    MouseArea {
                                        id: areaBotonExportar
                                        anchors.fill: parent
                                        onClicked: console.log("Exportar presionado para " + model.proyecto)
                                    }
                                }
                            }
                        }
                    }
                }

                // Controles inferiores
                Row {
                    id: filaControlesInferiores
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: parent.width * 0.05
                    spacing: 20

                    // Botón Basura
                    Rectangle {
                        width: mainWindow.height * 0.10
                        height: mainWindow.height * 0.10
                        radius: height / 2
                        color: areaMouseBasura.pressed ? "#d1d5db" : "#F3F4F6"
                        border.color: "black"
                        border.width: 1
                        Image {
                            source: "Basura.png"
                            anchors.centerIn: parent
                            width: parent.width * 0.6
                            height: parent.height * 0.6
                            fillMode: Image.PreserveAspectFit
                        }
                        MouseArea {
                            id: areaMouseBasura
                            anchors.fill: parent
                            onClicked: {
                                pantallaRegistro.modoBorrar = !pantallaRegistro.modoBorrar;
                                if (!pantallaRegistro.modoBorrar) {
                                    for (let i = 0; i < registro_experimentos.count; i++) {
                                        registro_experimentos.setProperty(i, "seleccionado", false);
                                    }
                                    pantallaRegistro.itemsSeleccionados = 0;
                                }
                            }
                        }
                    }

                    // Botón Borrar (Aparece al seleccionar items)
                    Rectangle {
                        width: mainWindow.width * 0.15
                        height: mainWindow.height * 0.10
                        radius: height / 2
                        color: areaMouseEliminar.pressed ? "#a02020" : "#FF2D2D"
                        visible: pantallaRegistro.modoBorrar && pantallaRegistro.itemsSeleccionados > 0
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Borrar")
                            color: "white"
                            font.pixelSize: parent.height * 0.40
                            font.bold: true
                        }
                        MouseArea {
                            id: areaMouseEliminar
                            anchors.fill: parent
                            onClicked: {
                                pantallaRegistro.mostrarPopupConfirmarBorrado = true;
                            }
                        }
                    }
                }

                Rectangle {
                    id: botonAtras15
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: parent.width * 0.05
                    width: parent.width * 0.12
                    height: parent.height * 0.10
                    color: areaMouseAtras15.pressed ? "#cc1e1e" : "#FF2D2D"
                    radius: height / 2

                    Text {
                        anchors.centerIn: parent
                        text: "↶"
                        color: "black"
                        font.pixelSize: parent.height * 0.70
                        font.bold: true
                    }
                    MouseArea {
                        id: areaMouseAtras15
                        anchors.fill: parent
                        onClicked: estadoActual = "pantalla_principal"
                    }
                }

                // Ventana de Confirmación de Borrado
                Item {
                    anchors.fill: parent
                    z: 200
                    visible: pantallaRegistro.mostrarPopupConfirmarBorrado
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Rectangle {
                        width: parent.width * 0.60
                        height: parent.height * 0.40
                        anchors.centerIn: parent
                        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
                        radius: 20

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: parent.height * 0.15
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("¿Seguro que deseas borrar los documentos seleccionados?")
                            font.pixelSize: parent.height * 0.08
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.9
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.left: parent.left
                            anchors.leftMargin: parent.width * 0.10
                            color: areaOkConfirmarBorrado.pressed ? "#6b42b5" : "#8b5cf6"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Okay")
                                font.pixelSize: parent.height * 0.40
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaOkConfirmarBorrado
                                anchors.fill: parent
                                onClicked: {
                                    for (let i = registro_experimentos.count - 1; i >= 0; i--) {
                                        if (registro_experimentos.get(i).seleccionado) {
                                            registro_experimentos.remove(i);
                                        }
                                    }
                                    pantallaRegistro.itemsSeleccionados = 0;
                                    pantallaRegistro.modoBorrar = false;
                                    pantallaRegistro.mostrarPopupConfirmarBorrado = false;
                                }
                            }
                        }

                        Rectangle {
                            width: mainWindow.width * 0.15
                            height: mainWindow.height * 0.08
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: parent.height * 0.15
                            anchors.right: parent.right
                            anchors.rightMargin: parent.width * 0.10
                            color: areaAtrasConfirmarBorrado.pressed ? "#cc1e1e" : "#FF2D2D"
                            radius: height / 2
                            Text {
                                anchors.centerIn: parent
                                text: "↶"
                                font.pixelSize: parent.height * 0.70
                                font.bold: true
                                color: "black"
                            }
                            MouseArea {
                                id: areaAtrasConfirmarBorrado
                                anchors.fill: parent
                                onClicked: pantallaRegistro.mostrarPopupConfirmarBorrado = false
                            }
                        }
                    }
                }
            }
        }