import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

// Mantenimiento: prueba manual de actuadores, prueba del flotador de nivel (PCF8574),
// vaciado manual y herramientas del radar (con PIN). Solo con el equipo en reposo.
// Al entrar el backend pausa el lazo de nivel; al salir apaga todo y deja OE HIGH.
Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_mantenimiento"

    // 0 = actuadores, 1 = sensor de nivel, 2 = vaciado manual, 3 = herramientas radar
    property int seccion: 0

    property bool mostrarConfirmarCalentador: false

    // PIN para las herramientas del radar: accionan válvulas y bombas sin protecciones.
    readonly property string pinTecnico: "1234"
    property bool mostrarPopupPin: false
    property string entradaPin: ""
    property bool pinIncorrecto: false
    property string destinoPin: ""

    onVisibleChanged: {
        if (visible) {
            backend.entrarMantenimiento()
        } else {
            backend.salirMantenimiento()
            backend.cerrarVaciadoManual()
            root.mostrarConfirmarCalentador = false
            root.mostrarPopupPin = false
            root.entradaPin = ""
        }
    }

    // Al cambiar de sección se apaga lo que estuviera encendido en la anterior,
    // para que las válvulas de "Actuadores" y de "Vaciado manual" no se pisen.
    function cambiarSeccion(s) {
        if (s === root.seccion) return
        backend.mantApagarTodo()
        backend.cerrarVaciadoManual()
        root.seccion = s
    }

    function bitFlotador(i) {
        return backend.flotadorPuerto < 0 ? -1 : ((backend.flotadorPuerto >> i) & 1)
    }

    function hex2(v) {
        var s = v.toString(16).toUpperCase()
        return "0x" + (s.length < 2 ? "0" + s : s)
    }

    Text {
        id: tituloMant
        text: qsTranslate("Main", "Mantenimiento")
        font.pixelSize: appWindow.height * 0.07
        font.bold: true
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.15
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // ── Menú lateral ──────────────────────────────────────────────────────────
    Column {
        id: menuLateral
        anchors.top: tituloMant.bottom
        anchors.topMargin: appWindow.height * 0.04
        anchors.left: parent.left
        anchors.leftMargin: appWindow.width * 0.04
        width: appWindow.width * 0.24
        spacing: appWindow.height * 0.025

        Repeater {
            model: [
                qsTranslate("Main", "Actuadores"),
                qsTranslate("Main", "Sensor de nivel"),
                qsTranslate("Main", "Vaciado manual"),
                qsTranslate("Main", "Herramientas radar")
            ]
            Rectangle {
                width: menuLateral.width
                height: appWindow.height * 0.10
                radius: height / 2
                color: root.seccion === index ? "#2E90AE"
                     : areaSeccion.pressed     ? "#5a8282" : "#6E9C9C"
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: parent.height * 0.3
                    anchors.rightMargin: parent.height * 0.3
                    text: modelData
                    color: root.seccion === index ? "white" : "black"
                    font.pixelSize: parent.height * 0.34
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 12
                }
                MouseArea { id: areaSeccion; anchors.fill: parent; onClicked: root.cambiarSeccion(index) }
            }
        }
    }

    // ── Panel de contenido ────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.top: tituloMant.bottom
        anchors.topMargin: appWindow.height * 0.04
        anchors.left: menuLateral.right
        anchors.leftMargin: appWindow.width * 0.03
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.04
        anchors.bottom: botonAtras.top
        anchors.bottomMargin: appWindow.height * 0.03
        radius: 20
        color: Qt.rgba(0.90, 0.94, 0.98, 0.97)

        // Aviso: con proceso activo nada de esto funciona
        Text {
            visible: backend.procesoActivo && root.seccion !== 3
            anchors.centerIn: parent
            width: parent.width * 0.85
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTranslate("Main", "No disponible: hay un proceso activo. Mantenimiento solo funciona con el equipo en reposo.")
            font.pixelSize: appWindow.height * 0.04
            font.bold: true
            color: "#b00000"
        }

        // ── 0. ACTUADORES ────────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            anchors.margins: parent.height * 0.05
            visible: root.seccion === 0 && !backend.procesoActivo

            Text {
                id: ayudaActuadores
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTranslate("Main", "Toca un actuador para encenderlo. Se apaga solo después de unos segundos.")
                font.pixelSize: appWindow.height * 0.032
                color: "#333333"
            }

            Grid {
                anchors.top: ayudaActuadores.bottom
                anchors.topMargin: appWindow.height * 0.025
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                columnSpacing: appWindow.width * 0.02
                rowSpacing: appWindow.height * 0.018

                Repeater {
                    model: [
                        { nombre: qsTranslate("Main", "Bombas de llenado"), id: 0 },
                        { nombre: qsTranslate("Main", "Burbujeo"),          id: 1 },
                        { nombre: qsTranslate("Main", "Electroválvula 1"),  id: 2 },
                        { nombre: qsTranslate("Main", "Electroválvula 2"),  id: 3 },
                        { nombre: qsTranslate("Main", "Electroválvula 3"),  id: 4 },
                        { nombre: qsTranslate("Main", "Tira LED"),          id: 5 },
                        { nombre: qsTranslate("Main", "Calentador"),        id: 6 }
                    ]
                    Rectangle {
                        property int restantes: backend.mantRestantes[modelData.id] || 0
                        property bool encendido: restantes > 0
                        width: appWindow.width * 0.30
                        height: appWindow.height * 0.085
                        radius: height / 2
                        color: encendido ? "#2E90AE" : "#cfd8d8"
                        border.color: encendido ? "#1f6f86" : "#9bb3b3"
                        border.width: 2
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: parent.height * 0.3
                            anchors.rightMargin: parent.height * 0.3
                            text: (encendido ? "● " : "○ ") + modelData.nombre
                                  + (encendido ? "  ·  " + restantes + " s" : "")
                            color: encendido ? "white" : "#333"
                            font.pixelSize: parent.height * 0.34
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 10
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // El calentador pide confirmar que hay líquido (manta en seco)
                                if (modelData.id === 6 && !parent.encendido)
                                    root.mostrarConfirmarCalentador = true
                                else
                                    backend.mantToggleActuador(modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // ── 1. SENSOR DE NIVEL (flotador doble + PCF8574) ────────────────────
        Item {
            anchors.fill: parent
            anchors.margins: parent.height * 0.05
            visible: root.seccion === 1 && !backend.procesoActivo

            Row {
                id: filaEstadoPcf
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.width * 0.02
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: backend.flotadorDireccion >= 0
                          ? qsTranslate("Main", "PCF8574 encontrado en %1").arg(root.hex2(backend.flotadorDireccion))
                          : qsTranslate("Main", "PCF8574 no encontrado")
                    font.pixelSize: appWindow.height * 0.038
                    font.bold: true
                    color: backend.flotadorDireccion >= 0 ? "#1a8a1a" : "#b00000"
                }
                Rectangle {
                    width: appWindow.width * 0.14
                    height: appWindow.height * 0.065
                    radius: height / 2
                    color: areaBuscar.pressed ? "#5a8282" : "#6E9C9C"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Buscar"); font.pixelSize: parent.height * 0.42; font.bold: true; color: "black" }
                    MouseArea { id: areaBuscar; anchors.fill: parent; onClicked: backend.flotadorBuscar() }
                }
            }

            // 8 pines: verde = 0 (contacto cerrado a GND), gris = 1 (abierto)
            Row {
                id: filaPines
                anchors.top: filaEstadoPcf.bottom
                anchors.topMargin: appWindow.height * 0.035
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.width * 0.012
                Repeater {
                    model: 8
                    Column {
                        spacing: appWindow.height * 0.008
                        Rectangle {
                            property int bit: root.bitFlotador(index)
                            width: appWindow.width * 0.055
                            height: width
                            radius: width / 2
                            color: bit === 0 ? "#3bb54a" : bit === 1 ? "#cfd8d8" : "#eeeeee"
                            border.color: "#555"
                            border.width: 2
                            Text {
                                anchors.centerIn: parent
                                text: parent.bit < 0 ? "-" : parent.bit
                                font.pixelSize: parent.height * 0.45
                                font.bold: true
                                color: parent.bit === 0 ? "white" : "#333"
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "P" + index
                            font.pixelSize: appWindow.height * 0.03
                            font.bold: true
                            color: "black"
                        }
                    }
                }
            }

            Text {
                id: ayudaFlotador
                anchors.top: filaPines.bottom
                anchors.topMargin: appWindow.height * 0.02
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: (backend.flotadorPuerto >= 0
                       ? qsTranslate("Main", "Byte crudo: %1").arg(root.hex2(backend.flotadorPuerto)) + "\n"
                       : "")
                      + qsTranslate("Main", "Sube y baja cada bola con la mano: el pin que cambia es el de esa bola. Verde = contacto cerrado.")
                font.pixelSize: appWindow.height * 0.03
                color: "#333333"
            }

            // Prueba cruzada con agua: llenar / drenar unos segundos y ver qué pin cambia
            Row {
                anchors.top: ayudaFlotador.bottom
                anchors.topMargin: appWindow.height * 0.025
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.width * 0.02
                Repeater {
                    model: [
                        { nombre: qsTranslate("Main", "Llenar"), id: 0 },
                        { nombre: qsTranslate("Main", "Drenar (EV1)"), id: 2 }
                    ]
                    Rectangle {
                        property int restantes: backend.mantRestantes[modelData.id] || 0
                        property bool encendido: restantes > 0
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.08
                        radius: height / 2
                        color: encendido ? "#2E90AE" : "#cfd8d8"
                        border.color: encendido ? "#1f6f86" : "#9bb3b3"
                        border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: modelData.nombre + (parent.encendido ? "  ·  " + parent.restantes + " s" : "")
                            color: parent.encendido ? "white" : "#333"
                            font.pixelSize: parent.height * 0.36
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: backend.mantToggleActuador(modelData.id) }
                    }
                }
            }
        }

        // ── 2. VACIADO MANUAL (sin apagado automático) ───────────────────────
        Item {
            anchors.fill: parent
            anchors.margins: parent.height * 0.05
            visible: root.seccion === 2 && !backend.procesoActivo

            Text {
                id: ayudaVaciado
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTranslate("Main", "Toca cada electroválvula para abrirla o cerrarla. Se cierran todas al salir.")
                font.pixelSize: appWindow.height * 0.032
                color: "#333333"
            }

            Column {
                anchors.top: ayudaVaciado.bottom
                anchors.topMargin: appWindow.height * 0.04
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.height * 0.028

                Repeater {
                    model: [
                        { etiqueta: qsTranslate("Main", "EV inferior (CH8)"),   idx: 0 },
                        { etiqueta: qsTranslate("Main", "EV superior (CH10)"),  idx: 1 },
                        { etiqueta: qsTranslate("Main", "EV vaciado 3 (CH11)"), idx: 2 }
                    ]
                    Rectangle {
                        property bool encendido: modelData.idx === 0 ? backend.vaciadoManualInf
                                               : modelData.idx === 1 ? backend.vaciadoManualSup
                                                                     : backend.vaciadoManualAux
                        width: appWindow.width * 0.42
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: encendido ? "#2E90AE" : "#cfd8d8"
                        border.color: encendido ? "#1f6f86" : "#9bb3b3"
                        border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: (parent.encendido ? "● " : "○ ") + modelData.etiqueta
                            color: parent.encendido ? "white" : "#333"
                            font.pixelSize: parent.height * 0.30
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: backend.toggleVaciadoManual(modelData.idx) }
                    }
                }
            }
        }

        // ── 3. HERRAMIENTAS DEL RADAR (con PIN) ──────────────────────────────
        Item {
            anchors.fill: parent
            anchors.margins: parent.height * 0.05
            visible: root.seccion === 3

            Text {
                id: ayudaRadar
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTranslate("Main", "Herramientas del radar XM125. Solo personal técnico.")
                font.pixelSize: appWindow.height * 0.032
                color: "#333333"
            }

            Column {
                anchors.top: ayudaRadar.bottom
                anchors.topMargin: appWindow.height * 0.05
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.height * 0.035

                BotonAccionVerde {
                    width: appWindow.width * 0.40
                    textoBoton: qsTranslate("Main", "Calibrar tanque (PIN)")
                    onClicado: {
                        root.destinoPin = "pantalla_calibracion_tanque"
                        root.entradaPin = ""
                        root.pinIncorrecto = false
                        root.mostrarPopupPin = true
                    }
                }
                BotonAccionVerde {
                    width: appWindow.width * 0.40
                    textoBoton: qsTranslate("Main", "Caracterizar nivel (PIN)")
                    onClicado: {
                        root.destinoPin = "pantalla_caracterizacion_nivel"
                        root.entradaPin = ""
                        root.pinIncorrecto = false
                        root.mostrarPopupPin = true
                    }
                }
            }
        }
    }

    // ── Atrás → Configuraciones ──────────────────────────────────────────────
    Rectangle {
        id: botonAtras
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.04
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaAtrasMant.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2
        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: areaAtrasMant
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_configuraciones"
        }
    }

    // --- POPUP: CONFIRMAR CALENTADOR ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarConfirmarCalentador
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.55
            height: parent.height * 0.42
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.12
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.85
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTranslate("Main", "¿El tanque tiene líquido?\nLa manta se enciende 5 s.")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: parent.width * 0.06

                Rectangle {
                    width: appWindow.width * 0.16
                    height: appWindow.height * 0.09
                    radius: height / 2
                    color: areaSiCalentador.pressed ? "#6b42b5" : "#8b5cf6"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Sí, encender"); font.pixelSize: parent.height * 0.34; font.bold: true; color: "black" }
                    MouseArea {
                        id: areaSiCalentador
                        anchors.fill: parent
                        onClicked: {
                            root.mostrarConfirmarCalentador = false
                            backend.mantToggleActuador(6)
                        }
                    }
                }
                Rectangle {
                    width: appWindow.width * 0.16
                    height: appWindow.height * 0.09
                    radius: height / 2
                    color: areaNoCalentador.pressed ? "#cc1e1e" : "#FF2D2D"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cancelar"); font.pixelSize: parent.height * 0.34; font.bold: true; color: "black" }
                    MouseArea { id: areaNoCalentador; anchors.fill: parent; onClicked: root.mostrarConfirmarCalentador = false }
                }
            }
        }
    }

    // --- POPUP: PIN TÉCNICO ---
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupPin
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.45
            height: parent.height * 0.85
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            Column {
                anchors.fill: parent
                anchors.margins: parent.height * 0.05
                spacing: appWindow.height * 0.02

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.pinIncorrecto ? qsTranslate("Main", "PIN incorrecto")
                                             : qsTranslate("Main", "Ingrese el PIN técnico")
                    font.pixelSize: appWindow.height * 0.05
                    font.bold: true
                    color: root.pinIncorrecto ? "#cc1e1e" : "black"
                }

                Rectangle {
                    width: parent.width
                    height: appWindow.height * 0.09
                    radius: 10
                    color: "white"
                    border.color: "black"
                    Text {
                        anchors.centerIn: parent
                        text: "●".repeat(root.entradaPin.length)
                        font.pixelSize: parent.height * 0.50
                        color: "#333333"
                    }
                }

                TecladoNumerico {
                    width: parent.width
                    height: appWindow.height * 0.40

                    onDigitoPresionado: function(d) {
                        if (root.entradaPin.length < 6) {
                            root.entradaPin += d
                            root.pinIncorrecto = false
                        }
                    }
                    onBorrarPresionado: root.entradaPin = root.entradaPin.slice(0, -1)
                    onOkPresionado: {
                        if (root.entradaPin === root.pinTecnico) {
                            root.mostrarPopupPin = false
                            appWindow.estadoActual = root.destinoPin
                        } else {
                            root.pinIncorrecto = true
                        }
                        root.entradaPin = ""
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.40
                    height: appWindow.height * 0.08
                    radius: height / 2
                    color: areaCancelarPin.pressed ? "#cc1e1e" : "#FF2D2D"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cancelar"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    MouseArea {
                        id: areaCancelarPin
                        anchors.fill: parent
                        onClicked: {
                            root.mostrarPopupPin = false
                            root.entradaPin = ""
                        }
                    }
                }
            }
        }
    }
}
