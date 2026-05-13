import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    visible: appWindow.estadoActual === "pantalla_7"

    // Duración del ciclo de calibración en ms. Cambiar a 182000 para producción.
    readonly property int duracionCal: 182000

    // ── Estado pH (3 puntos) ───────────────────
    property bool expandidoPH:  false
    property bool phCalibrado:  false
    property int  puntos_pH:    0
    property int  stPH4:  0   // 0=idle  1=midiendo  2=ok  3=error
    property int  stPH7:  0
    property int  stPH10: 0

    // ── Estado DO ─────────────────────────────
    property bool expandidoDO: false
    property bool doCalibrado:  false
    property int  stDO: 0

    // ── Estado Nivel ──────────────────────────
    property bool expandidoNivel: false
    property bool nivelCalibrado:  false
    property int  stNivel: 0

    // true mientras cualquier temporizador de calibración esté activo
    readonly property bool calibracionEnCurso: stPH4 === 1 || stPH7 === 1 || stPH10 === 1 || stDO === 1 || stNivel === 1

    // ── Popup advertencia ─────────────────────
    property bool mostrarAdvertencia: false

    onVisibleChanged: {
        if (!visible) return
        expandidoPH = false; expandidoDO = false; expandidoNivel = false
        phCalibrado = false; doCalibrado = false; nivelCalibrado = false
        puntos_pH = 0
        stPH4 = 0; stPH7 = 0; stPH10 = 0
        stDO = 0; stNivel = 0
        mostrarAdvertencia = false
    }

    // ── Timers ────────────────────────────────
    Timer {
        id: tPH4; interval: root.duracionCal
        onTriggered: {
            if (appWindow.sensor_estado_calibracion === 1) { root.stPH4 = 2; root.puntos_pH++ }
            else { root.stPH4 = 3 }
        }
    }
    Timer {
        id: tPH7; interval: root.duracionCal
        onTriggered: {
            if (appWindow.sensor_estado_calibracion === 1) { root.stPH7 = 2; root.puntos_pH++ }
            else { root.stPH7 = 3 }
        }
    }
    Timer {
        id: tPH10; interval: root.duracionCal
        onTriggered: {
            if (appWindow.sensor_estado_calibracion === 1) { root.stPH10 = 2; root.puntos_pH++ }
            else { root.stPH10 = 3 }
        }
    }
    Timer {
        id: tDO; interval: root.duracionCal
        onTriggered: { root.stDO = (appWindow.sensor_estado_calibracion === 1) ? 2 : 3 }
    }
    Timer {
        id: tNivel; interval: root.duracionCal
        onTriggered: { root.stNivel = (appWindow.sensor_estado_calibracion === 1) ? 2 : 3 }
    }

    // ════════════════════════════════════════════
    // LAYOUT PRINCIPAL
    // ════════════════════════════════════════════

    Flickable {
        id: flickArea
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.17
        anchors.bottom: botonOkPrincipal.top
        anchors.bottomMargin: appWindow.height * 0.01
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: parent.width * 0.05
        anchors.rightMargin: parent.width * 0.05
        contentHeight: colContenido.implicitHeight
        clip: true

        Column {
            id: colContenido
            width: flickArea.width
            spacing: appWindow.height * 0.018

            // Título
            Text {
                text: qsTranslate("Main", "CALIBRACIÓN")
                font.pixelSize: appWindow.height * 0.065
                font.bold: true
                color: "black"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Lecturas en tiempo real
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: appWindow.width * 0.025

                BarraDisplaySensor {
                    width: colContenido.width * 0.30
                    textoEtiqueta: "pH"
                    textoValor: backend.sensorPH.toFixed(1)
                }
                BarraDisplaySensor {
                    width: colContenido.width * 0.30
                    textoEtiqueta: "DO"
                    textoValor: backend.sensorDO.toFixed(1) + " mg/L"
                }
                BarraDisplaySensor {
                    width: colContenido.width * 0.30
                    textoEtiqueta: qsTranslate("Main", "Nivel")
                    textoValor: backend.sensorNivel.toFixed(1) + " %"
                }
            }

            // ─── ACCORDION pH ─────────────────────────────
            Column {
                width: parent.width
                spacing: 0

                Rectangle {
                    id: headerPH
                    width: parent.width
                    height: appWindow.height * 0.075
                    radius: height / 2
                    color: "#6E9C9C"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: appWindow.width * 0.025
                        text: qsTranslate("Main", "Calibrar Sensor pH")
                        font.pixelSize: parent.height * 0.40
                        font.bold: true
                        color: "black"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: flechaPH.left
                        anchors.rightMargin: appWindow.width * 0.015
                        visible: root.phCalibrado
                        text: "✓ " + qsTranslate("Main", "Calibrado")
                        font.pixelSize: parent.height * 0.38
                        font.bold: true
                        color: "#1a8a1a"
                    }
                    Text {
                        id: flechaPH
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: appWindow.width * 0.025
                        text: root.expandidoPH ? "▲" : "▼"
                        font.pixelSize: parent.height * 0.40
                        color: "black"
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.expandidoPH = !root.expandidoPH }
                }

                Rectangle {
                    width: parent.width
                    height: root.expandidoPH ? contenidoPH.implicitHeight + appWindow.height * 0.05 : 0
                    color: "#EFF8F8"
                    radius: 10
                    clip: true
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                    Column {
                        id: contenidoPH
                        width: parent.width
                        anchors.top: parent.top
                        anchors.topMargin: appWindow.height * 0.025
                        spacing: appWindow.height * 0.02

                        // 3 botones de punto de calibración
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: appWindow.width * 0.04

                            // ── pH 4 ──
                            Rectangle {
                                id: btnPH4
                                width: appWindow.width * 0.19
                                height: appWindow.height * 0.10
                                radius: height / 2
                                color: stPH4 === 0 ? (maPH4.pressed ? "#2d6a9a" : "#3B82C4")
                                     : stPH4 === 1 ? "#999999"
                                     : stPH4 === 2 ? "#4CAF50"
                                     :               "#FF5252"

                                Text {
                                    anchors.centerIn: parent
                                    visible: root.stPH4 === 0
                                    text: "pH 4"
                                    font.pixelSize: parent.height * 0.35
                                    font.bold: true; color: "white"
                                }
                                Image {
                                    visible: root.stPH4 === 1
                                    source: "Hongo_5.png"
                                    anchors.centerIn: parent
                                    width: parent.height * 0.60; height: width
                                    fillMode: Image.PreserveAspectFit
                                    SequentialAnimation on rotation {
                                        loops: Animation.Infinite
                                        running: root.stPH4 === 1
                                        NumberAnimation { from: 0; to: 360; duration: 600 }
                                        PauseAnimation { duration: 200 }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: root.stPH4 === 2; text: "✓"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                Text { anchors.centerIn: parent; visible: root.stPH4 === 3; text: "✗"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                MouseArea {
                                    id: maPH4; anchors.fill: parent
                                    enabled: (root.stPH4 === 0 || root.stPH4 === 3) && !root.calibracionEnCurso
                                    onClicked: { root.stPH4 = 1; tPH4.restart() }
                                }
                            }

                            // ── pH 7 ──
                            Rectangle {
                                width: appWindow.width * 0.19; height: appWindow.height * 0.10; radius: height / 2
                                color: stPH7 === 0 ? (maPH7.pressed ? "#2d6a9a" : "#3B82C4") : stPH7 === 1 ? "#999999" : stPH7 === 2 ? "#4CAF50" : "#FF5252"
                                Text { anchors.centerIn: parent; visible: root.stPH7 === 0; text: "pH 7"; font.pixelSize: parent.height * 0.35; font.bold: true; color: "white" }
                                Image {
                                    visible: root.stPH7 === 1; source: "Hongo_5.png"; anchors.centerIn: parent; width: parent.height * 0.60; height: width; fillMode: Image.PreserveAspectFit
                                    SequentialAnimation on rotation {
                                        loops: Animation.Infinite; running: root.stPH7 === 1
                                        NumberAnimation { from: 0; to: 360; duration: 600 }
                                        PauseAnimation { duration: 200 }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: root.stPH7 === 2; text: "✓"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                Text { anchors.centerIn: parent; visible: root.stPH7 === 3; text: "✗"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                MouseArea { id: maPH7; anchors.fill: parent; enabled: (root.stPH7 === 0 || root.stPH7 === 3) && !root.calibracionEnCurso; onClicked: { root.stPH7 = 1; tPH7.restart() } }
                            }

                            // ── pH 10 ──
                            Rectangle {
                                width: appWindow.width * 0.19; height: appWindow.height * 0.10; radius: height / 2
                                color: stPH10 === 0 ? (maPH10.pressed ? "#2d6a9a" : "#3B82C4") : stPH10 === 1 ? "#999999" : stPH10 === 2 ? "#4CAF50" : "#FF5252"
                                Text { anchors.centerIn: parent; visible: root.stPH10 === 0; text: "pH 10"; font.pixelSize: parent.height * 0.35; font.bold: true; color: "white" }
                                Image {
                                    visible: root.stPH10 === 1; source: "Hongo_5.png"; anchors.centerIn: parent; width: parent.height * 0.60; height: width; fillMode: Image.PreserveAspectFit
                                    SequentialAnimation on rotation {
                                        loops: Animation.Infinite; running: root.stPH10 === 1
                                        NumberAnimation { from: 0; to: 360; duration: 600 }
                                        PauseAnimation { duration: 200 }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: root.stPH10 === 2; text: "✓"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                Text { anchors.centerIn: parent; visible: root.stPH10 === 3; text: "✗"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                MouseArea { id: maPH10; anchors.fill: parent; enabled: (root.stPH10 === 0 || root.stPH10 === 3) && !root.calibracionEnCurso; onClicked: { root.stPH10 = 1; tPH10.restart() } }
                            }
                        }

                        // Puntos medidos + botón OK pestaña
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: appWindow.width * 0.03

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTranslate("Main", "Puntos medidos: %1").arg(root.puntos_pH)
                                font.pixelSize: appWindow.height * 0.033
                                color: "black"
                            }
                            Rectangle {
                                width: appWindow.width * 0.12; height: appWindow.height * 0.08; radius: height / 2
                                color: root.puntos_pH >= 1 ? (maOkPH.pressed ? "#6b42b5" : "#8b5cf6") : "#cccccc"
                                opacity: root.puntos_pH >= 1 ? 1.0 : 0.5
                                Text { anchors.centerIn: parent; text: qsTranslate("Main", "OK"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                MouseArea { id: maOkPH; anchors.fill: parent; enabled: root.puntos_pH >= 1; onClicked: { root.phCalibrado = true; root.expandidoPH = false } }
                            }
                        }

                        Item { width: 1; height: 1 } // bottom padding handled by parent margin
                    }
                }
            }

            // ─── ACCORDION DO ─────────────────────────────
            Column {
                width: parent.width
                spacing: 0

                Rectangle {
                    id: headerDO
                    width: parent.width; height: appWindow.height * 0.075; radius: height / 2; color: "#6E9C9C"
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: appWindow.width * 0.025; text: qsTranslate("Main", "Calibrar Sensor DO"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: flechaDO.left; anchors.rightMargin: appWindow.width * 0.015; visible: root.doCalibrado; text: "✓ " + qsTranslate("Main", "Calibrado"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "#1a8a1a" }
                    Text { id: flechaDO; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: appWindow.width * 0.025; text: root.expandidoDO ? "▲" : "▼"; font.pixelSize: parent.height * 0.40; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: root.expandidoDO = !root.expandidoDO }
                }

                Rectangle {
                    width: parent.width
                    height: root.expandidoDO ? contenidoDO.implicitHeight + appWindow.height * 0.05 : 0
                    color: "#EFF8F8"; radius: 10; clip: true
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                    Column {
                        id: contenidoDO
                        width: parent.width
                        anchors.top: parent.top
                        anchors.topMargin: appWindow.height * 0.025
                        spacing: appWindow.height * 0.02

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTranslate("Main", "Asegúrate de que el sensor se encuentre seco")
                            font.pixelSize: appWindow.height * 0.032
                            font.italic: true
                            color: "#555555"
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: appWindow.width * 0.04

                            Rectangle {
                                width: appWindow.width * 0.19; height: appWindow.height * 0.10; radius: height / 2
                                color: stDO === 0 ? (maCalDO.pressed ? "#2d6a9a" : "#3B82C4") : stDO === 1 ? "#999999" : stDO === 2 ? "#4CAF50" : "#FF5252"
                                Text { anchors.centerIn: parent; visible: root.stDO === 0; text: qsTranslate("Main", "Calibrar"); font.pixelSize: parent.height * 0.33; font.bold: true; color: "white" }
                                Image {
                                    visible: root.stDO === 1; source: "Hongo_5.png"; anchors.centerIn: parent; width: parent.height * 0.60; height: width; fillMode: Image.PreserveAspectFit
                                    SequentialAnimation on rotation {
                                        loops: Animation.Infinite; running: root.stDO === 1
                                        NumberAnimation { from: 0; to: 360; duration: 600 }
                                        PauseAnimation { duration: 200 }
                                    }
                                }
                                Text { anchors.centerIn: parent; visible: root.stDO === 2; text: "✓"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                Text { anchors.centerIn: parent; visible: root.stDO === 3; text: "✗"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                                MouseArea { id: maCalDO; anchors.fill: parent; enabled: (root.stDO === 0 || root.stDO === 3) && !root.calibracionEnCurso; onClicked: { root.stDO = 1; tDO.restart() } }
                            }
                            Rectangle {
                                width: appWindow.width * 0.12; height: appWindow.height * 0.10; radius: height / 2
                                color: root.stDO === 2 ? (maOkDO.pressed ? "#6b42b5" : "#8b5cf6") : "#cccccc"
                                opacity: root.stDO === 2 ? 1.0 : 0.5
                                Text { anchors.centerIn: parent; text: qsTranslate("Main", "OK"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                                MouseArea { id: maOkDO; anchors.fill: parent; enabled: root.stDO === 2; onClicked: { root.doCalibrado = true; root.expandidoDO = false } }
                            }
                        }

                        Item { width: 1; height: 1 }
                    }
                }
            }

            // ─── ACCORDION NIVEL ───────────────────────────
            Column {
                width: parent.width
                spacing: 0

                Rectangle {
                    id: headerNivel
                    width: parent.width; height: appWindow.height * 0.075; radius: height / 2; color: "#6E9C9C"
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: appWindow.width * 0.025; text: qsTranslate("Main", "Calibrar Sensor Nivel"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: flechaNivel.left; anchors.rightMargin: appWindow.width * 0.015; visible: root.nivelCalibrado; text: "✓ " + qsTranslate("Main", "Calibrado"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "#1a8a1a" }
                    Text { id: flechaNivel; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: appWindow.width * 0.025; text: root.expandidoNivel ? "▲" : "▼"; font.pixelSize: parent.height * 0.40; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: root.expandidoNivel = !root.expandidoNivel }
                }

                Rectangle {
                    width: parent.width
                    height: root.expandidoNivel ? appWindow.height * 0.18 : 0
                    color: "#EFF8F8"; radius: 10; clip: true
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                    Row {
                        anchors.centerIn: parent
                        spacing: appWindow.width * 0.04

                        Rectangle {
                            width: appWindow.width * 0.19; height: appWindow.height * 0.10; radius: height / 2
                            color: stNivel === 0 ? (maCalNivel.pressed ? "#2d6a9a" : "#3B82C4") : stNivel === 1 ? "#999999" : stNivel === 2 ? "#4CAF50" : "#FF5252"
                            Text { anchors.centerIn: parent; visible: root.stNivel === 0; text: qsTranslate("Main", "Calibrar"); font.pixelSize: parent.height * 0.33; font.bold: true; color: "white" }
                            Image {
                                visible: root.stNivel === 1; source: "Hongo_5.png"; anchors.centerIn: parent; width: parent.height * 0.60; height: width; fillMode: Image.PreserveAspectFit
                                SequentialAnimation on rotation {
                                        loops: Animation.Infinite; running: root.stNivel === 1
                                        NumberAnimation { from: 0; to: 360; duration: 600 }
                                        PauseAnimation { duration: 200 }
                                    }
                            }
                            Text { anchors.centerIn: parent; visible: root.stNivel === 2; text: "✓"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                            Text { anchors.centerIn: parent; visible: root.stNivel === 3; text: "✗"; font.pixelSize: parent.height * 0.55; font.bold: true; color: "white" }
                            MouseArea { id: maCalNivel; anchors.fill: parent; enabled: (root.stNivel === 0 || root.stNivel === 3) && !root.calibracionEnCurso; onClicked: { root.stNivel = 1; tNivel.restart() } }
                        }
                        Rectangle {
                            width: appWindow.width * 0.12; height: appWindow.height * 0.10; radius: height / 2
                            color: root.stNivel === 2 ? (maOkNivel.pressed ? "#6b42b5" : "#8b5cf6") : "#cccccc"
                            opacity: root.stNivel === 2 ? 1.0 : 0.5
                            Text { anchors.centerIn: parent; text: qsTranslate("Main", "OK"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                            MouseArea { id: maOkNivel; anchors.fill: parent; enabled: root.stNivel === 2; onClicked: { root.nivelCalibrado = true; root.expandidoNivel = false } }
                        }
                    }
                }
            }

            // Espacio para que el botón OK no tape el contenido
            Item { width: 1; height: appWindow.height * 0.02 }
        }
    }

    // ── Botón OK Principal ────────────────────
    Rectangle {
        id: botonOkPrincipal
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        anchors.bottomMargin: parent.height * 0.03
        width: parent.width * 0.12
        height: parent.height * 0.10
        radius: height / 2
        color: maOkPrincipal.pressed ? "#6b42b5" : "#8b5cf6"

        Text { anchors.centerIn: parent; text: qsTranslate("Main", "OK"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
        MouseArea {
            id: maOkPrincipal
            anchors.fill: parent
            onClicked: {
                if (root.phCalibrado && root.doCalibrado && root.nivelCalibrado)
                    appWindow.estadoActual = "pantalla_procesos"
                else
                    root.mostrarAdvertencia = true
            }
        }
    }

    // ── Popup Advertencia ─────────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarAdvertencia
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
                width: parent.width * 0.80
                text: qsTranslate("Main", "Hay sensores sin calibrar.\n¿Desea continuar de todas formas?")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Rectangle {
                width: appWindow.width * 0.16; height: appWindow.height * 0.09; radius: height / 2
                anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.12
                anchors.left: parent.left; anchors.leftMargin: parent.width * 0.10
                color: maContinuar.pressed ? "#6b42b5" : "#8b5cf6"
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Continuar"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "black" }
                MouseArea { id: maContinuar; anchors.fill: parent; onClicked: { root.mostrarAdvertencia = false; appWindow.estadoActual = "pantalla_procesos" } }
            }

            Rectangle {
                width: appWindow.width * 0.16; height: appWindow.height * 0.09; radius: height / 2
                anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.12
                anchors.right: parent.right; anchors.rightMargin: parent.width * 0.10
                color: maRegresar.pressed ? "#cc1e1e" : "#FF2D2D"
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Regresar"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "black" }
                MouseArea { id: maRegresar; anchors.fill: parent; onClicked: root.mostrarAdvertencia = false }
            }
        }
    }
}
