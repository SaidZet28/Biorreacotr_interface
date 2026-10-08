import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

// Herramienta de diagnóstico del sensor de nivel XM125.
// Al entrar reinicia el sensor como xm125_distance.py (reset + 100-2000 mm) y
// muestra TODOS los picos crudos, sin filtro. Permite accionar actuadores a mano
// (EV1=CH8, EV2=CH10, burbujeo=CH2, bombas=CH3+CH4) y grabar un CSV con la línea
// de tiempo (muestras + eventos de actuador). El backend maneja OE y el paro seguro.
Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_caracterizacion_nivel"

    property string ultimaRuta: ""

    // ── Ciclo de vida: entra/sale del modo caracterización en el backend ──────
    // entrarCaracterizacion() bloquea ~5 s (reset + calibración del XM125, igual que
    // xm125_distance.py). Se difiere un tick con un Timer para que la pantalla pinte
    // el overlay "Inicializando…" antes de congelarse durante la calibración.
    onVisibleChanged: {
        if (visible) {
            root.ultimaRuta = "";
            timerEntrar.start();
        } else {
            backend.salirCaracterizacion();   // apaga actuadores + OE HIGH + restaura sensor
        }
    }

    Timer {
        id: timerEntrar
        interval: 120; repeat: false
        onTriggered: backend.entrarCaracterizacion()
    }

    // ── Título ────────────────────────────────────────────────────────────────
    Text {
        id: titulo
        text: qsTranslate("Main", "Caracterización de nivel")
        font.pixelSize: appWindow.height * 0.055
        font.bold: true
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.13
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // ── Barra de estado (temp, near_edge, muestras) ───────────────────────────
    Row {
        id: estado
        anchors.top: titulo.bottom
        anchors.topMargin: appWindow.height * 0.015
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: appWindow.width * 0.04

        Text {
            text: qsTranslate("Main", "Temp sensor: %1 °C").arg(backend.caractTempSensor.toFixed(1))
            font.pixelSize: appWindow.height * 0.026; color: "#555"
        }
        Text {
            text: backend.caractNearEdge ? "⚠ near_edge" : ""
            font.pixelSize: appWindow.height * 0.026; color: "#d29922"; font.bold: true
        }
        Text {
            visible: backend.caractGrabando
            text: qsTranslate("Main", "● grabando — %1 filas").arg(backend.caractNumMuestras)
            font.pixelSize: appWindow.height * 0.026; color: "#D64545"; font.bold: true
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Cuerpo: tabla de picos (izq) + controles (der)
    // ══════════════════════════════════════════════════════════════════════════
    Row {
        anchors.top: estado.bottom
        anchors.topMargin: appWindow.height * 0.02
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.14
        anchors.horizontalCenter: parent.horizontalCenter
        width: appWindow.width * 0.90
        spacing: appWindow.width * 0.03

        // ── Tabla de picos crudos ─────────────────────────────────────────────
        Rectangle {
            width: parent.width * 0.58
            height: parent.height
            radius: 14
            color: "#161b22"
            border.color: "#30363d"; border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: appWindow.height * 0.02
                spacing: appWindow.height * 0.008

                Text {
                    text: qsTranslate("Main", "OBJETOS DETECTADOS (orden del firmware, sin filtro)")
                    color: "#8b949e"; font.pixelSize: appWindow.height * 0.024
                }

                // Encabezado
                Row {
                    width: parent.width
                    Text { width: parent.width * 0.10; text: "#";       color: "#8b949e"; font.pixelSize: appWindow.height * 0.024 }
                    Text { width: parent.width * 0.24; text: qsTranslate("Main", "Dist (mm)"); color: "#8b949e"; font.pixelSize: appWindow.height * 0.024 }
                    Text { width: parent.width * 0.22; text: qsTranslate("Main", "F. cruda");  color: "#8b949e"; font.pixelSize: appWindow.height * 0.024 }
                    Text { width: parent.width * 0.22; text: "Q16";      color: "#8b949e"; font.pixelSize: appWindow.height * 0.024 }
                    Text { width: parent.width * 0.22; text: "dB";       color: "#8b949e"; font.pixelSize: appWindow.height * 0.024 }
                }

                Rectangle { width: parent.width; height: 1; color: "#30363d" }

                // Filas de picos (bind directo a la lista del backend)
                Repeater {
                    model: backend.caractPicos
                    Row {
                        width: parent ? parent.width : 0
                        // el pico de mayor fuerza cruda se resalta en verde
                        property bool esFuerte: {
                            var picos = backend.caractPicos;
                            if (!picos || picos.length === 0) return false;
                            var maxRaw = -1e12, idx = -1;
                            for (var i = 0; i < picos.length; ++i)
                                if (picos[i].raw > maxRaw) { maxRaw = picos[i].raw; idx = i; }
                            return idx === index;
                        }
                        Text { width: parent.width * 0.10; text: (index + 1); color: esFuerte ? "#3fb950" : "#e6edf3"; font.pixelSize: appWindow.height * 0.030; font.bold: esFuerte }
                        Text { width: parent.width * 0.24; text: Math.round(modelData.dist); color: esFuerte ? "#3fb950" : "#58a6ff"; font.pixelSize: appWindow.height * 0.032; font.bold: true }
                        Text { width: parent.width * 0.22; text: Math.round(modelData.raw); color: "#e6edf3"; font.pixelSize: appWindow.height * 0.026 }
                        Text { width: parent.width * 0.22; text: modelData.q16.toFixed(3); color: "#d29922"; font.pixelSize: appWindow.height * 0.026 }
                        Text { width: parent.width * 0.22; text: modelData.db.toFixed(1);  color: "#d29922"; font.pixelSize: appWindow.height * 0.026 }
                    }
                }

                Text {
                    visible: !backend.caractPicos || backend.caractPicos.length === 0
                    text: qsTranslate("Main", "(sin detecciones)")
                    color: "#8b949e"; font.pixelSize: appWindow.height * 0.028
                }
            }
        }

        // ── Columna de controles ──────────────────────────────────────────────
        Column {
            id: controles
            width: parent.width * 0.39
            height: parent.height
            spacing: appWindow.height * 0.022

            // Electroválvula 1 (CH8)
            Rectangle {
                width: controles.width; height: appWindow.height * 0.115; radius: 14
                color: maEV1.pressed ? "#2a6a2e" : (backend.caractEV1 ? "#3fb950" : "#30363d")
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Electroválvula 1 (CH8)") + "  " + (backend.caractEV1 ? "ON" : "OFF")
                    color: backend.caractEV1 ? "black" : "#e6edf3"; font.pixelSize: parent.height * 0.26; font.bold: true
                }
                MouseArea { id: maEV1; anchors.fill: parent; onClicked: backend.caractToggleEV1() }
            }
            // Electroválvula 2 (CH10)
            Rectangle {
                width: controles.width; height: appWindow.height * 0.115; radius: 14
                color: maEV2.pressed ? "#2a6a2e" : (backend.caractEV2 ? "#3fb950" : "#30363d")
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Electroválvula 2 (CH10)") + "  " + (backend.caractEV2 ? "ON" : "OFF")
                    color: backend.caractEV2 ? "black" : "#e6edf3"; font.pixelSize: parent.height * 0.26; font.bold: true
                }
                MouseArea { id: maEV2; anchors.fill: parent; onClicked: backend.caractToggleEV2() }
            }
            // Burbujeador (CH2)
            Rectangle {
                width: controles.width; height: appWindow.height * 0.115; radius: 14
                color: maBurb.pressed ? "#2a6a2e" : (backend.caractBurbujeo ? "#3fb950" : "#30363d")
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Burbujeador (CH2)") + "  " + (backend.caractBurbujeo ? "ON" : "OFF")
                    color: backend.caractBurbujeo ? "black" : "#e6edf3"; font.pixelSize: parent.height * 0.26; font.bold: true
                }
                MouseArea { id: maBurb; anchors.fill: parent; onClicked: backend.caractToggleBurbujeo() }
            }
            // Bombas de llenado (CH3+CH4, en serie)
            Rectangle {
                width: controles.width; height: appWindow.height * 0.115; radius: 14
                color: maBom.pressed ? "#2a6a2e" : (backend.caractBombas ? "#3fb950" : "#30363d")
                Text {
                    anchors.centerIn: parent
                    text: qsTranslate("Main", "Bombas llenado (CH3+CH4)") + "  " + (backend.caractBombas ? "ON" : "OFF")
                    color: backend.caractBombas ? "black" : "#e6edf3"; font.pixelSize: parent.height * 0.26; font.bold: true
                }
                MouseArea { id: maBom; anchors.fill: parent; onClicked: backend.caractToggleBombas() }
            }

            Rectangle { width: controles.width; height: 1; color: "#30363d" }

            // Grabar / Detener
            Rectangle {
                width: parent.width
                height: appWindow.height * 0.13
                radius: 14
                color: maGrab.pressed ? "#a03030"
                       : (backend.caractGrabando ? "#D64545" : "#8b5cf6")
                Text {
                    anchors.centerIn: parent
                    text: backend.caractGrabando ? qsTranslate("Main", "■ Detener y guardar")
                                                 : qsTranslate("Main", "● Grabar datos")
                    color: "white"; font.pixelSize: parent.height * 0.26; font.bold: true
                }
                MouseArea {
                    id: maGrab; anchors.fill: parent
                    onClicked: {
                        if (backend.caractGrabando)
                            root.ultimaRuta = backend.caractDetenerGrabacion();
                        else {
                            root.ultimaRuta = "";
                            backend.caractIniciarGrabacion();
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.ultimaRuta !== ""
                wrapMode: Text.WrapAnywhere
                text: qsTranslate("Main", "Guardado en:\n%1").arg(root.ultimaRuta)
                color: "#3fb950"; font.pixelSize: appWindow.height * 0.022
            }
        }
    }

    // ── Botón salir/atrás (salir dispara el paro seguro en onVisibleChanged) ──
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: appWindow.width * 0.04
        anchors.bottomMargin: appWindow.height * 0.04
        width: appWindow.width * 0.11; height: appWindow.height * 0.10; radius: height / 2
        color: maSalir.pressed ? "#cc1e1e" : "#FF2D2D"
        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: maSalir; anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_configuraciones"
        }
    }

    // ── Overlay de inicialización (mientras el XM125 hace reset + calibración) ──
    Rectangle {
        anchors.fill: parent
        z: 500
        visible: root.visible && !backend.caractActiva
        color: Qt.rgba(0.05, 0.06, 0.09, 0.92)
        Column {
            anchors.centerIn: parent
            spacing: appWindow.height * 0.03
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Inicializando sensor…")
                color: "#e6edf3"; font.pixelSize: appWindow.height * 0.05; font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTranslate("Main", "Reset + calibración (~5 s)")
                color: "#8b949e"; font.pixelSize: appWindow.height * 0.03
            }
        }
    }
}
