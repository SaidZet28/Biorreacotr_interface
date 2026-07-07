import QtQuick 2.15
import QtQuick.Controls 2.15
import Prototipo

// ═══════════════════════════════════════════════════════════════════════════════
//  PantallaPruebaPH — Validación visual del controlador difuso pH
//  Permite:
//    · Preparar el tanque (→ PantallaPreparacion)
//    · Ajustar setpoint pH y umbrales de histéresis de nivel
//    · Habilitar/deshabilitar el lazo difuso y la histéresis de nivel
//    · Monitorear en tiempo real pH, nivel, ciclo y estado de la bomba
// ═══════════════════════════════════════════════════════════════════════════════

Item {
    id: root
    property ApplicationWindow appWindow
    visible: appWindow.estadoActual === "pantalla_prueba_ph"

    // ── Estado interno del teclado ────────────────────────────────────────────
    property string campoActivo:    ""   // "sp_ph" | "nivel_max" | "nivel_hist"
    property string entradaTemporal: ""

    readonly property double _sp    : backend.setpointPH
    readonly property double _ph    : backend.sensorPH
    readonly property double _nivel : backend.sensorNivel
    readonly property double _temp  : backend.sensorTem
    readonly property double _tPulso: backend.salidaBombaEtanol   // t_pulso [s]
    readonly property bool   _bombaOn: backend.pulsoNeutralizadorActivo
    readonly property int    _ciclo  : backend.segundoProximoCiclo

    // ────────────────────────────────────────────────────────────────────────
    // LAYOUT PRINCIPAL: dos columnas + barra inferior
    // ────────────────────────────────────────────────────────────────────────

    // ── Columna izquierda ──────────────────────────────────────────────────
    Column {
        id: colIzq
        anchors.top:        parent.top
        anchors.topMargin:  appWindow.height * 0.17
        anchors.left:       parent.left
        anchors.leftMargin: appWindow.width  * 0.04
        width:  appWindow.width  * 0.55
        spacing: appWindow.height * 0.022

        // Título
        Text {
            text: "PRUEBA — Control pH"
            font.pixelSize: appWindow.height * 0.052
            font.bold: true
            color: "black"
        }

        // ── Tarjeta: estado del lazo difuso ─────────────────────────────────
        Rectangle {
            width:  parent.width
            height: appWindow.height * 0.38
            color:  "#EFF8F8"
            radius: 14

            Column {
                anchors.fill:    parent
                anchors.margins: appWindow.height * 0.025
                spacing:         appWindow.height * 0.018

                Text {
                    text: "Lazo difuso pH   (Ts = 30 s)"
                    font.pixelSize: appWindow.height * 0.030
                    font.bold: true
                    color: "#2a6060"
                }

                // Setpoint pH — clic para editar
                BarraInputConfig {
                    id: barraSP
                    width:         parent.width
                    idCampo:       "sp_ph"
                    textoEtiqueta: "Setpoint pH"
                    valorMostrado: root._sp.toFixed(2) + "  [4.0 – 7.5]"
                    campoActivo:   root.campoActivo
                    onBarraClicada: {
                        root.entradaTemporal = root._sp.toFixed(2)
                        root.campoActivo     = "sp_ph"
                        teclado.visible      = true
                    }
                }

                // Filas de monitoreo
                Row {
                    spacing: appWindow.width * 0.03
                    BarraDisplaySensor {
                        width:          colIzq.width * 0.47
                        textoEtiqueta:  "pH actual"
                        textoValor:     root._ph.toFixed(3)
                    }
                    BarraDisplaySensor {
                        width:          colIzq.width * 0.47
                        textoEtiqueta:  "Error"
                        textoValor:     (root._sp - root._ph).toFixed(3)
                    }
                }

                Row {
                    spacing: appWindow.width * 0.03
                    BarraDisplaySensor {
                        width:          colIzq.width * 0.47
                        textoEtiqueta:  "t_pulso calc."
                        textoValor:     root._tPulso.toFixed(2) + " s"
                    }
                    BarraDisplaySensor {
                        width:          colIzq.width * 0.47
                        textoEtiqueta:  "Próximo ciclo"
                        textoValor:     root._ciclo + " s"
                    }
                }

                // Indicador bomba + habilitación
                Row {
                    spacing: appWindow.width * 0.025

                    // Indicador bomba
                    Rectangle {
                        width:  appWindow.height * 0.055
                        height: appWindow.height * 0.055
                        radius: height / 2
                        color:  root._bombaOn ? "#4CAF50" : "#CCCCCC"
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Text {
                            anchors.centerIn: parent
                            text: root._bombaOn ? "ON" : "OFF"
                            font.pixelSize: parent.height * 0.32
                            font.bold: true
                            color: "white"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bomba CH3+CH4"
                        font.pixelSize: appWindow.height * 0.026
                        color: "#333333"
                    }

                    // Botón habilitar/deshabilitar fuzzy
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:  appWindow.height * 0.155
                        height: appWindow.height * 0.055
                        radius: height / 2
                        color: backend.fuzzyPHHabilitado
                               ? (maFuzzy.pressed ? "#cc1e1e" : "#FF2D2D")
                               : (maFuzzy.pressed ? "#388E3C" : "#4CAF50")
                        Text {
                            anchors.centerIn: parent
                            text: backend.fuzzyPHHabilitado ? "Deshabilitar" : "Habilitar"
                            font.pixelSize: parent.height * 0.36
                            font.bold: true
                            color: "black"
                        }
                        MouseArea {
                            id: maFuzzy
                            anchors.fill: parent
                            onClicked: backend.habilitarFuzzyPH(!backend.fuzzyPHHabilitado)
                        }
                    }
                }
            }
        }

        // ── Tarjeta: histéresis de nivel ──────────────────────────────────────
        Rectangle {
            width:  parent.width
            height: appWindow.height * 0.275
            color:  "#FFF8EE"
            radius: 14

            Column {
                anchors.fill:    parent
                anchors.margins: appWindow.height * 0.025
                spacing:         appWindow.height * 0.016

                Text {
                    text: "Histéresis de nivel"
                    font.pixelSize: appWindow.height * 0.030
                    font.bold: true
                    color: "#7a4400"
                }

                Row {
                    spacing: appWindow.width * 0.025

                    // Umbral superior
                    BarraInputConfig {
                        width:         colIzq.width * 0.46
                        idCampo:       "nivel_max"
                        textoEtiqueta: "Máx. (corte)"
                        valorMostrado: backend.nivelMaxPct.toFixed(1) + " %"
                        campoActivo:   root.campoActivo
                        onBarraClicada: {
                            root.entradaTemporal = backend.nivelMaxPct.toFixed(1)
                            root.campoActivo     = "nivel_max"
                            teclado.visible      = true
                        }
                    }

                    // Umbral inferior
                    BarraInputConfig {
                        width:         colIzq.width * 0.46
                        idCampo:       "nivel_hist"
                        textoEtiqueta: "Mín. (hist.)"
                        valorMostrado: backend.nivelHistPct.toFixed(1) + " %"
                        campoActivo:   root.campoActivo
                        onBarraClicada: {
                            root.entradaTemporal = backend.nivelHistPct.toFixed(1)
                            root.campoActivo     = "nivel_hist"
                            teclado.visible      = true
                        }
                    }
                }

                // Barra visual del nivel con marcas de umbral
                Item {
                    width:  parent.width
                    height: appWindow.height * 0.052

                    // Fondo
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: "#DDDDDD"
                    }
                    // Nivel actual (relleno)
                    Rectangle {
                        width: parent.width * Math.min(1.0, root._nivel / 100.0)
                        height: parent.height
                        radius: parent.children[0].radius
                        color: root._nivel >= backend.nivelMaxPct ? "#FF5252"
                             : root._nivel >= backend.nivelHistPct ? "#FFA726"
                             : "#6E9C9C"
                        Behavior on width  { NumberAnimation { duration: 400 } }
                        Behavior on color  { ColorAnimation  { duration: 300 } }
                    }
                    // Marca umbral superior
                    Rectangle {
                        x: parent.width * (backend.nivelMaxPct / 100.0) - width / 2
                        width: 3; height: parent.height
                        color: "#c62828"
                        radius: 2
                    }
                    // Marca umbral inferior
                    Rectangle {
                        x: parent.width * (backend.nivelHistPct / 100.0) - width / 2
                        width: 3; height: parent.height
                        color: "#e65100"
                        radius: 2
                    }
                    // Etiqueta nivel
                    Text {
                        anchors.centerIn: parent
                        text: root._nivel.toFixed(1) + " %"
                        font.pixelSize: parent.height * 0.50
                        font.bold: true
                        color: "black"
                    }
                }

                // Botón histéresis nivel
                Rectangle {
                    width:  appWindow.height * 0.28
                    height: appWindow.height * 0.055
                    radius: height / 2
                    color: backend.histeresisNivelHabilitado
                           ? (maHist.pressed ? "#cc1e1e" : "#FF2D2D")
                           : (maHist.pressed ? "#388E3C" : "#4CAF50")
                    Text {
                        anchors.centerIn: parent
                        text: backend.histeresisNivelHabilitado
                              ? "Deshabilitar histéresis nivel"
                              : "Habilitar histéresis nivel"
                        font.pixelSize: parent.height * 0.36
                        font.bold: true
                        color: "black"
                    }
                    MouseArea {
                        id: maHist
                        anchors.fill: parent
                        onClicked: backend.habilitarHisteresisNivel(!backend.histeresisNivelHabilitado)
                    }
                }
            }
        }
    }

    // ── Columna derecha ─────────────────────────────────────────────────────
    Column {
        anchors.top:         parent.top
        anchors.topMargin:   appWindow.height * 0.17
        anchors.right:       parent.right
        anchors.rightMargin: appWindow.width * 0.04
        width:   appWindow.width * 0.35
        spacing: appWindow.height * 0.022

        Text {
            text: "Lecturas en tiempo real"
            font.pixelSize: appWindow.height * 0.030
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        BarraDisplaySensor {
            width:          parent.width
            textoEtiqueta:  "pH"
            textoValor:     root._ph.toFixed(3)
        }
        BarraDisplaySensor {
            width:          parent.width
            textoEtiqueta:  "Nivel"
            textoValor:     root._nivel.toFixed(1) + " %"
        }
        BarraDisplaySensor {
            width:          parent.width
            textoEtiqueta:  "Temperatura"
            textoValor:     root._temp.toFixed(1) + " °C"
        }

        // Estado sensor
        Text {
            width: parent.width
            text: backend.puertoConectado
                  ? ("Puerto: " + backend.nombrePuerto)
                  : "Sin conexión serial"
            font.pixelSize: appWindow.height * 0.022
            color: backend.puertoConectado ? "#2a6060" : "#b71c1c"
            horizontalAlignment: Text.AlignHCenter
        }

        // Separador
        Rectangle { width: parent.width; height: 2; color: "#DDDDDD" }

        // ── Preparar tanque ──────────────────────────────────────────────────
        Rectangle {
            width:  parent.width
            height: appWindow.height * 0.115
            radius: 14
            color:  backend.preparacionCompletada ? "#C8E6C9" : "#DFF0F8"

            Column {
                anchors.centerIn: parent
                spacing: appWindow.height * 0.010

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: backend.preparacionCompletada ? "Tanque listo ✓"
                        : backend.estadoPreparacion >= 0 ? "Preparando… (" + backend.textoTareaPreparacion + ")"
                        : "Sin preparar"
                    font.pixelSize: appWindow.height * 0.026
                    font.bold: true
                    color: backend.preparacionCompletada ? "#1b5e20" : "#1a5070"
                    width: parent.parent.width * 0.85
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width:  parent.parent.parent.width * 0.75
                    height: appWindow.height * 0.052
                    radius: height / 2
                    color: maPrep.pressed ? "#1565C0" : "#1976D2"
                    visible: !backend.preparacionCompletada

                    Text {
                        anchors.centerIn: parent
                        text: backend.estadoPreparacion >= 0 ? "Ver preparación" : "Preparar tanque"
                        font.pixelSize: parent.height * 0.36
                        font.bold: true
                        color: "white"
                    }
                    MouseArea {
                        id: maPrep
                        anchors.fill: parent
                        onClicked: {
                            if (backend.estadoPreparacion < 0)
                                backend.iniciarPreparacion()
                            appWindow.estadoActual = "pantalla_preparacion"
                        }
                    }
                }
            }
        }

        // ── Pulso manual ─────────────────────────────────────────────────────
        Rectangle {
            width:  parent.width
            height: appWindow.height * 0.090
            radius: 14
            color: maPulso.pressed ? "#4a148c" : "#7B1FA2"

            Text {
                anchors.centerIn: parent
                text: "Pulso manual\n(prueba bomba CH3+CH4)"
                font.pixelSize: parent.height * 0.24
                font.bold: true
                color: "white"
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: maPulso
                anchors.fill: parent
                onClicked: dialogPulso.open()
            }
        }
    }

    // ── Botón Atrás ──────────────────────────────────────────────────────────
    Rectangle {
        anchors.bottom:      parent.bottom
        anchors.left:        parent.left
        anchors.margins:     appWindow.width  * 0.04
        anchors.bottomMargin: appWindow.height * 0.03
        width:  appWindow.width  * 0.12
        height: appWindow.height * 0.10
        radius: height / 2
        color: maAtras.pressed ? "#cc1e1e" : "#FF2D2D"

        Text { anchors.centerIn: parent; text: "↶"; color: "black";
               font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: maAtras
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_configuraciones"
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP TECLADO NUMÉRICO
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        id: teclado
        anchors.fill: parent
        z: 500
        visible: false

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.40)
            MouseArea { anchors.fill: parent }
        }

        Rectangle {
            width:  appWindow.width  * 0.42
            height: appWindow.height * 0.58
            anchors.centerIn: parent
            color:  "#FAFAFA"
            radius: 20

            Column {
                anchors.fill:    parent
                anchors.margins: appWindow.height * 0.025
                spacing:         appWindow.height * 0.020

                Text {
                    text: {
                        if (root.campoActivo === "sp_ph")      return "Setpoint pH  [4.0 – 7.5]"
                        if (root.campoActivo === "nivel_max")  return "Umbral máximo de nivel  [50 – 100 %]"
                        if (root.campoActivo === "nivel_hist") return "Umbral mínimo de nivel  [10 – " + (backend.nivelMaxPct - 5).toFixed(0) + " %]"
                        return ""
                    }
                    font.pixelSize: appWindow.height * 0.028
                    font.bold: true
                    color: "#2a6060"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                // Visor
                Rectangle {
                    width: parent.width
                    height: appWindow.height * 0.075
                    color: "#EEEEEE"
                    radius: 10
                    Text {
                        anchors.centerIn: parent
                        text: root.entradaTemporal || "0"
                        font.pixelSize: parent.height * 0.55
                        font.bold: true
                        color: "#333333"
                    }
                }

                // Teclado
                TecladoNumerico {
                    id: tecladoNum
                    width:  parent.width
                    height: appWindow.height * 0.35

                    onDigitoPresionado: function(d) {
                        if (root.entradaTemporal.length < 6)
                            root.entradaTemporal += d
                    }
                    onPuntoPresionado: {
                        if (!root.entradaTemporal.includes("."))
                            root.entradaTemporal += "."
                    }
                    onBorrarPresionado: {
                        root.entradaTemporal = root.entradaTemporal.slice(0, -1)
                    }
                    onOkPresionado: {
                        let val = parseFloat(root.entradaTemporal)
                        if (!isNaN(val)) {
                            if (root.campoActivo === "sp_ph") {
                                val = Math.max(4.0, Math.min(7.5, val))
                                backend.setpointPH = val
                            } else if (root.campoActivo === "nivel_max") {
                                val = Math.max(50.0, Math.min(100.0, val))
                                backend.nivelMaxPct = val
                            } else if (root.campoActivo === "nivel_hist") {
                                let maxAllow = backend.nivelMaxPct - 5.0
                                val = Math.max(10.0, Math.min(maxAllow, val))
                                backend.nivelHistPct = val
                            }
                        }
                        teclado.visible      = false
                        root.campoActivo     = ""
                        root.entradaTemporal = ""
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // DIALOG — Pulso manual de bomba
    // ════════════════════════════════════════════════════════════════════════════
    Dialog {
        id: dialogPulso
        title: "Pulso manual — Bomba CH3+CH4"
        modal: true
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        Column {
            spacing: appWindow.height * 0.018
            padding: appWindow.height * 0.02

            Text {
                text: "Duración del pulso (1 – 7 s):"
                font.pixelSize: appWindow.height * 0.028
                color: "#333333"
            }

            Row {
                spacing: appWindow.width * 0.015
                Repeater {
                    model: [1, 2, 3, 4, 5, 6, 7]
                    delegate: Rectangle {
                        width:  appWindow.height * 0.075
                        height: appWindow.height * 0.075
                        radius: height / 2
                        color: spPulso === modelData
                               ? "#1976D2"
                               : (maSeg.pressed ? "#BBDEFB" : "#E3F2FD")
                        property int spPulso: dialogPulso.selectedSec
                        Text {
                            anchors.centerIn: parent
                            text: modelData + "s"
                            font.pixelSize: parent.height * 0.36
                            font.bold: true
                            color: parent.spPulso === modelData ? "white" : "#1976D2"
                        }
                        MouseArea {
                            id: maSeg
                            anchors.fill: parent
                            onClicked: dialogPulso.selectedSec = modelData
                        }
                    }
                }
            }
        }

        property int selectedSec: 2

        onAccepted: {
            backend.dispararPulsoManual(selectedSec)
        }
    }
}
