import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    visible: appWindow.estadoActual === "pantalla_preparacion"

    onVisibleChanged: {
        if (visible) backend.iniciarPreparacion()
    }

    Connections {
        target: backend
        function onPreparacionCancelada() { appWindow.procesoListoParaIniciar = false }
    }

    // ── 4 fases visibles que agrupan los 7 estados internos ──────────────────
    readonly property int faseVisual: {
        let s = backend.estadoPreparacion
        if (s <= 0)  return 0
        if (s <= 2)  return 1
        if (s <= 5)  return 2
        return 3
    }

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
                color: "white"
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
                    text: backend.textoDetallePreparacion
                    font.pixelSize: appWindow.height * 0.029
                    color: "#1a1a1a"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.28
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

        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Temperatura")
            textoValor: backend.sensorTem.toFixed(1) + " °C"
        }

        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: "pH"
            // Ocultar valor en estados 0-1 en hardware (sensor no está en contacto)
            textoValor: (backend.estadoPreparacion <= 1 && !backend.modoSimulacion)
                        ? "---"
                        : backend.sensorPH.toFixed(2)
        }

        BarraDisplaySensor {
            width: parent.width
            textoEtiqueta: qsTranslate("Main", "Nivel")
            textoValor: backend.sensorNivel.toFixed(1) + " %"
        }

        // Setpoints como referencia
        Rectangle {
            width: parent.width
            height: colObjetivos.implicitHeight + appWindow.height * 0.036
            color: "#EFF8F8"
            radius: 10

            Column {
                id: colObjetivos
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: appWindow.height * 0.018
                anchors.leftMargin: appWindow.height * 0.018
                anchors.rightMargin: appWindow.height * 0.018
                spacing: appWindow.height * 0.014

                Text {
                    text: qsTranslate("Main", "Objetivos configurados")
                    font.pixelSize: appWindow.height * 0.026
                    font.bold: true
                    color: "#2a6060"
                }
                Text {
                    text: qsTranslate("Main", "pH: %1  ±0.5").arg(backend.setpointPH.toFixed(1))
                    font.pixelSize: appWindow.height * 0.026
                    color: "#333333"
                }
                Text {
                    text: qsTranslate("Main", "Temp: %1 °C  ±1.0").arg(backend.setpointTem.toFixed(1))
                    font.pixelSize: appWindow.height * 0.026
                    color: "#333333"
                }
                Text {
                    text: qsTranslate("Main", "Nivel: %1 %").arg(backend.setpointNivel.toFixed(0))
                    font.pixelSize: appWindow.height * 0.026
                    color: "#333333"
                }
            }
        }
    }

    // ── Botón Atrás (solo mientras no ha comenzado o en estado 0) ────────────
    Rectangle {
        visible: backend.estadoPreparacion <= 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.03
        width: appWindow.width * 0.12
        height: appWindow.height * 0.10
        radius: height / 2
        color: maAtras.pressed ? "#cc1e1e" : "#FF2D2D"

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
                    text: qsTranslate("Main", "pH: %1   |   Temperatura: %2 °C   |   Nivel: %3 %")
                              .arg(backend.sensorPH.toFixed(2))
                              .arg(backend.sensorTem.toFixed(1))
                              .arg(backend.sensorNivel.toFixed(1))
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

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
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
            }
        }
    }
}
