import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    visible: appWindow.estadoActual === "pantalla_preparacion"

    onVisibleChanged: {
        if (visible) {
            root._estadoPrevio = -1
            backend.iniciarPreparacion()
        }
    }

    property int _estadoPrevio: -1

    Connections {
        target: backend
        function onPreparacionCancelada() { appWindow.procesoListoParaIniciar = false }
        function onEstadoPreparacionChanged() {
            let s = backend.estadoPreparacion
            // Sonido de éxito cada vez que la preparación avanza a un estado nuevo (0→1, 1→2 … 5→6)
            if (s > 0 && s > root._estadoPrevio) audio.reproducirExito()
            root._estadoPrevio = s
        }
    }

    // ── 4 fases visibles que agrupan los 7 estados internos ──────────────────
    // Los 4 estados internos (0-3) corresponden 1:1 con las 4 fases visibles
    readonly property int faseVisual: Math.max(0, backend.estadoPreparacion)

    readonly property var nombreFase: [
        qsTranslate("Main", "Verificación"),
        qsTranslate("Main", "Llenado"),
        qsTranslate("Main", "Acondicionamiento"),
        qsTranslate("Main", "Listo")
    ]

    // ════════════════════════════════════════════════════════════════════════════
    // LAYOUT PRINCIPAL
    // ════════════════════════════════════════════════════════════════════════════

    // ── Panel izquierdo — estado y progreso ───────────────────────────────────
    Column {
        id: panelIzq
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.17
        anchors.left: parent.left
        anchors.leftMargin: appWindow.width * 0.05
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.13
        width: appWindow.width * 0.54
        spacing: appWindow.height * 0.025

        // Título
        Text {
            text: qsTranslate("Main", "PREPARACIÓN DEL TANQUE")
            font.pixelSize: appWindow.height * 0.055
            font.bold: true
            color: "black"
        }

        // Indicador de 4 fases
        Row {
            width: parent.width
            spacing: 0

            Repeater {
                model: 4
                delegate: Item {
                    width: panelIzq.width / 4
                    height: appWindow.height * 0.090

                    // Línea conectora entre fases
                    Rectangle {
                        visible: index < 3
                        anchors.left: parent.horizontalCenter
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3
                        color: index < root.faseVisual ? "#4CAF50" : "#CCCCCC"
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Rectangle {
                            id: bola
                            anchors.horizontalCenter: parent.horizontalCenter
                            width:  appWindow.height * 0.065
                            height: appWindow.height * 0.065
                            radius: height / 2
                            color: index < root.faseVisual  ? "#4CAF50"
                                 : index === root.faseVisual ? "#6E9C9C"
                                 :                             "#CCCCCC"
                            Behavior on color { ColorAnimation { duration: 300 } }

                            Text {
                                anchors.centerIn: parent
                                text: index < root.faseVisual ? "✓" : (index + 1)
                                font.pixelSize: parent.height * 0.42
                                font.bold: true
                                color: index <= root.faseVisual ? "white" : "#888888"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.nombreFase[index]
                            font.pixelSize: appWindow.height * 0.024
                            color: index === root.faseVisual ? "#2a6060" : "#888888"
                            font.bold: index === root.faseVisual
                        }
                    }
                }
            }
        }

        // Barra de progreso global
        Item {
            width: parent.width
            height: appWindow.height * 0.040

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#DDDDDD"

                Rectangle {
                    width: parent.width * backend.progresoPreparacion
                    height: parent.height
                    radius: parent.radius
                    color: "#6E9C9C"
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Math.round(backend.progresoPreparacion * 100) + " %"
                font.pixelSize: parent.height * 0.55
                font.bold: true
                color: "black"
            }
        }

        // Tarjeta plan de llenado — solo visible en estado 0 (Verificación)
        Rectangle {
            visible: backend.estadoPreparacion === 0
            width: parent.width
            color: "#DFF0F8"
            radius: 10
            implicitHeight: colPlan.implicitHeight + appWindow.height * 0.028

            Column {
                id: colPlan
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: appWindow.height * 0.014
                anchors.leftMargin: appWindow.height * 0.016
                anchors.rightMargin: appWindow.height * 0.016
                spacing: appWindow.height * 0.010

                Text {
                    text: qsTranslate("Main", "Plan de llenado calculado")
                    font.pixelSize: appWindow.height * 0.025
                    font.bold: true
                    color: "#1a5070"
                }

                Row {
                    spacing: appWindow.width * 0.05

                    Text {
                        text: qsTranslate("Main", "Sustancia B:  %1 mL")
                                  .arg(backend.mlSustanciaB.toFixed(1))
                        font.pixelSize: appWindow.height * 0.025
                        color: "#333333"
                    }

                    Text {
                        text: qsTranslate("Main", "Agua:  %1 L")
                                  .arg(backend.litrosAgua.toFixed(2))
                        font.pixelSize: appWindow.height * 0.025
                        color: "#333333"
                    }
                }
            }
        }

        // Tarjeta con tarea actual y descripción
        Rectangle {
            width: parent.width
            height: appWindow.height * 0.34
            color: "#6E9C9C"
            radius: 14

            Column {
                anchors.fill: parent
                anchors.margins: appWindow.height * 0.030
                spacing: appWindow.height * 0.018

                Text {
                    text: backend.textoTareaPreparacion
                    font.pixelSize: appWindow.height * 0.040
                    font.bold: true
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    Behavior on text { }
                }

                Rectangle { width: parent.width; height: 2; color: Qt.rgba(0,0,0,0.15) }

                Text {
                    width: parent.width
                    height: parent.height - parent.spacing - parent.children[0].implicitHeight - parent.children[1].height - parent.spacing
                    text: backend.textoDetallePreparacion
                    font.pixelSize: appWindow.height * 0.029
                    minimumPixelSize: appWindow.height * 0.018
                    fontSizeMode: Text.Fit
                    color: "#1a1a1a"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.20
                    clip: true
                }
            }
        }
    }

    // ── Panel derecho — lecturas en tiempo real ───────────────────────────────
    Column {
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.17
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.04
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.13
        width: appWindow.width * 0.34
        spacing: appWindow.height * 0.025

        Text {
            text: qsTranslate("Main", "Lecturas en tiempo real")
            font.pixelSize: appWindow.height * 0.030
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Temperatura: medido → objetivo
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Temperatura")
            textoValor: (backend.sensorSerialValido ? appWindow.tempMostrada(backend.sensorTem).toFixed(1) : "---") + " → " + appWindow.tempMostrada(backend.setpointTem).toFixed(1) + " °" + appWindow.unidadTemperatura
        }

        // pH: medido → objetivo (en estados 0-1 el sensor aún no toca el líquido)
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: "pH"
            textoValor: (backend.estadoPreparacion <= 1 && !backend.modoSimulacion)
                        ? "--- → " + backend.setpointPH.toFixed(1)
                        : (backend.sensorSerialValido ? backend.sensorPH.toFixed(2) : "---") + " → " + backend.setpointPH.toFixed(1)
        }

        // Nivel: solo en el primer paso (fase de llenado)
        BarraDisplaySensor {
            width: parent.width
            visible: backend.estadoPreparacion <= 1
            textoEtiqueta: qsTranslate("Main", "Nivel")
            textoValor: (backend.sensorNivelValido ? backend.sensorNivel.toFixed(1) : "---") + " %"
        }

        // Tiempo esperado para esta etapa (ETA al setpoint, modelo FOPDT)
        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Tiempo estimado")
            textoValor: {
                var e = backend.etaCalentamientoSeg
                if (e < 0) return "—"
                if (e < 3600) return "~" + Math.round(e / 60) + " min"
                return "~" + Math.floor(e / 3600) + "h " +
                       ("0" + Math.floor((e % 3600) / 60)).slice(-2) + "m"
            }
        }
    }

    // ── Botón Cancelar/Atrás — disponible durante toda la preparación ─────────
    // (oculto solo cuando hay un popup modal encima: escalación o "tanque listo")
    Rectangle {
        visible: backend.estadoPreparacion <= 2 && !backend.alertaEscalacion && !backend.preparacionCompletada
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.12
        height: appWindow.height * 0.10
        radius: height / 2
        color: maAtras.pressed ? "#cc1e1e" : "#FF2D2D"
        z: 160

        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: maAtras
            anchors.fill: parent
            onClicked: {
                appWindow.procesoListoParaIniciar = false
                backend.cancelarPreparacion()
                appWindow.estadoActual = "pantalla_7"
            }
        }
    }

    // ── Aviso: sensores desconectados / sobre-temperatura / bombas sin efecto ──
    Rectangle {
        readonly property bool sensoresCaidos: backend.estadoPreparacion === 0
                                            && (!backend.sensorSerialValido || !backend.sensorNivelValido)
        visible: backend.alertaSobreTemp || backend.alertaBombas || sensoresCaidos
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.60
        height: appWindow.height * 0.09
        radius: height / 2
        color: "#FF4444"
        z: 150
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.92
            text: backend.alertaSobreTemp
                  ? qsTranslate("Main", "⚠ Sobre-temperatura: calentamiento cortado")
                  : backend.alertaBombas
                    ? qsTranslate("Main", "⚠ Bombas activas sin cambio de nivel — verifica las bombas")
                    : qsTranslate("Main", "⚠ Sensores sin respuesta — revise las conexiones")
            font.pixelSize: parent.height * 0.28
            font.bold: true
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Escalación (demasiado tiempo en acondicionamiento)
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 200
        visible: backend.alertaEscalacion
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.60
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.97, 0.95, 0.85, 0.97)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.025

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El ajuste está tomando más tiempo del esperado")
                    font.pixelSize: appWindow.height * 0.036
                    font.bold: true
                    color: "#7a4400"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El sistema lleva más de 2 minutos intentando alcanzar las condiciones objetivo sin lograrlo. Puede deberse a una composición muy alejada del valor deseado.\n\nSe recomienda considerar un drenaje parcial y reposición con líquido fresco antes de continuar.")
                    font.pixelSize: appWindow.height * 0.027
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.22
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.088
                        radius: height / 2
                        color: maContinuar.pressed ? "#6b42b5" : "#8b5cf6"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Continuar\nde todas formas")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: maContinuar
                            anchors.fill: parent
                            onClicked: backend.continuarDesdeEscalacion()
                        }
                    }

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.088
                        radius: height / 2
                        color: maDetener.pressed ? "#cc1e1e" : "#FF2D2D"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Detener\npreparación")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: maDetener
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = false
                                backend.cancelarPreparacion()
                                appWindow.estadoActual = "pantalla_7"
                            }
                        }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════════
    // POPUP — Tanque listo: introducir organismo
    // ════════════════════════════════════════════════════════════════════════════
    Item {
        anchors.fill: parent
        z: 200
        visible: backend.preparacionCompletada
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.58
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.88, 0.97, 0.88, 0.97)
            radius: 20

            Column {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.10
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: parent.width * 0.08
                anchors.rightMargin: parent.width * 0.08
                spacing: appWindow.height * 0.025

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "El tanque está listo")
                    font.pixelSize: appWindow.height * 0.050
                    font.bold: true
                    color: "#1a5c1a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "pH: %1   |   Temperatura: %2 °%4   |   Nivel: %3 %")
                              .arg(backend.sensorSerialValido ? backend.sensorPH.toFixed(2) : "---")
                              .arg(backend.sensorSerialValido ? appWindow.tempMostrada(backend.sensorTem).toFixed(1) : "---")
                              .arg(backend.sensorNivelValido ? backend.sensorNivel.toFixed(1) : "---")
                              .arg(appWindow.unidadTemperatura)
                    font.pixelSize: appWindow.height * 0.030
                    color: "#1a5c1a"
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Introduzca el organismo en el tanque y confirme para iniciar el proceso de cultivo.")
                    font.pixelSize: appWindow.height * 0.028
                    color: "#333333"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.28
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.03

                    Rectangle {
                        width: appWindow.width * 0.26
                        height: appWindow.height * 0.090
                        radius: height / 2
                        color: maConfirmar.pressed ? "#6b42b5" : "#8b5cf6"

                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Organismo introducido — Iniciar proceso")
                            font.pixelSize: parent.height * 0.28
                            font.bold: true
                            color: "black"
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width * 0.88
                            wrapMode: Text.WordWrap
                        }
                        MouseArea {
                            id: maConfirmar
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = true
                                appWindow.estadoActual = "pantalla_procesos"
                            }
                        }
                    }

                    Rectangle {
                        width: appWindow.width * 0.16
                        height: appWindow.height * 0.090
                        radius: height / 2
                        color: maCancelarListo.pressed ? "#cc1e1e" : "#FF2D2D"
                        Text {
                            anchors.centerIn: parent
                            text: qsTranslate("Main", "Cancelar")
                            font.pixelSize: parent.height * 0.30
                            font.bold: true
                            color: "black"
                        }
                        MouseArea {
                            id: maCancelarListo
                            anchors.fill: parent
                            onClicked: {
                                appWindow.procesoListoParaIniciar = false
                                backend.cancelarPreparacion()
                                appWindow.estadoActual = "pantalla_7"
                            }
                        }
                    }
                }
            }
        }
    }
}
