import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_12"

    property bool nivel1Completado: false
    property bool mostrarConfirmacion1: false
    property bool mostrarProceso1: false
    property bool mostrarConfirmacion2: false
    property bool mostrarProceso2: false
    property bool mostrarPopupFinalizado: false

    onVisibleChanged: {
        if (visible) {
            nivel1Completado     = false;
            mostrarConfirmacion1 = false;
            mostrarProceso1      = false;
            mostrarConfirmacion2 = false;
            mostrarProceso2      = false;
            mostrarPopupFinalizado = false;
        } else {
            // Seguridad: si el usuario sale a media purga, cerrar válvulas y OE HIGH.
            mostrarProceso1 = false;
            mostrarProceso2 = false;
            backend.finalizarVaciado();
        }
    }

    property string textoAborto: ""

    // Auto-avance del vaciado por etapas: el backend cierra la válvula al llegar a la
    // referencia y emite la señal; aquí solo avanzamos de pantalla.
    Connections {
        target: backend
        function onVaciadoEtapaCompletada(etapa) {
            if (etapa === 1) { root.mostrarProceso1 = false; root.nivel1Completado = true; audio.reproducirExito() }
            else if (etapa === 2) { root.mostrarProceso2 = false; root.mostrarPopupFinalizado = true; audio.reproducirExito() }
        }
        function onVaciadoAbortado(motivo) {
            root.mostrarProceso1 = false; root.mostrarProceso2 = false;
            root.textoAborto = motivo;
        }
    }

    // Texto de nivel en vivo (distancia mm — más confiable — y %).
    function textoNivelVivo() {
        var d = backend.distanciaNivelMm;
        var dist = (d >= 0) ? (Math.round(d) + " mm") : "--- mm";
        var pct  = backend.sensorNivelValido ? (backend.sensorNivel.toFixed(1) + " %") : "--- %";
        return qsTranslate("Main", "Nivel: %1   ·   Distancia: %2").arg(pct).arg(dist);
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: appWindow.width * 0.05
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: appWindow.height * 0.05
        spacing: appWindow.height * 0.05

        Rectangle {
            width: appWindow.width * 0.50
            height: appWindow.height * 0.15
            radius: height / 2
            color: root.nivel1Completado ? "#A9B29B" : (areaVaciadoNivel1.pressed ? "#7da84c" : "#8DBB5A")
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                text: qsTranslate("Main", "Vaciado de nivel 1")
                font.pixelSize: parent.height * 0.45
                font.bold: true
                color: root.nivel1Completado ? "#707070" : "black"
            }
            MouseArea {
                id: areaVaciadoNivel1
                anchors.fill: parent
                enabled: !root.nivel1Completado
                onClicked: root.mostrarConfirmacion1 = true
            }
        }

        Rectangle {
            width: appWindow.width * 0.50
            height: appWindow.height * 0.15
            radius: height / 2
            color: !root.nivel1Completado ? "#A9B29B" : (areaVaciadoNivel2.pressed ? "#7da84c" : "#8DBB5A")
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 40
                anchors.verticalCenter: parent.verticalCenter
                text: qsTranslate("Main", "Vaciado de nivel 2")
                font.pixelSize: parent.height * 0.45
                font.bold: true
                color: !root.nivel1Completado ? "#707070" : "black"
            }
            MouseArea {
                id: areaVaciadoNivel2
                anchors.fill: parent
                enabled: root.nivel1Completado
                onClicked: root.mostrarConfirmacion2 = true
            }
        }
    }

    Image {
        source: "../../Hongo_7.png"
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.05
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: appWindow.height * 0.05
        width: appWindow.width * 0.30
        fillMode: Image.PreserveAspectFit
    }

    // ── Confirmar vaciado 1 ───────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarConfirmacion1
        MouseArea { anchors.fill: parent; hoverEnabled: true }
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
                text: qsTranslate("Main", "¿Iniciar vaciado de nivel 1?")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                color: areaOkConfirmar1.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkConfirmar1
                    anchors.fill: parent
                    onClicked: {
                        root.mostrarConfirmacion1 = false;
                        backend.iniciarVaciado(1);   // abre CH8 + CH10
                        root.mostrarProceso1 = true;
                    }
                }
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasConfirmar1.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmar1; anchors.fill: parent; onClicked: root.mostrarConfirmacion1 = false }
            }
        }
    }

    // ── Vaciado 1 en proceso (real) — nivel en vivo + Detener ─────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarProceso1
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.88
                spacing: appWindow.height * 0.03

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Vaciado de nivel 1 en proceso\n(EV superior — CH10). Se detiene solo al llegar al nivel.")
                    font.pixelSize: parent.parent.height * 0.075
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: root.textoNivelVivo()
                    font.pixelSize: parent.parent.height * 0.085
                    color: "#1a1a1a"
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: appWindow.width * 0.30
                    height: appWindow.height * 0.10
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: height / 2
                    color: areaDetener1.pressed ? "#a03030" : "#D64545"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Detener (emergencia)"); font.pixelSize: parent.height * 0.30; font.bold: true; color: "white" }
                    MouseArea {
                        id: areaDetener1
                        anchors.fill: parent
                        onClicked: {
                            backend.detenerVaciado();     // paro de emergencia (cierra válvula, cancela)
                            root.mostrarProceso1 = false;
                        }
                    }
                }
            }
        }
    }

    // ── Confirmar vaciado 2 ───────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarConfirmacion2
        MouseArea { anchors.fill: parent; hoverEnabled: true }
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
                text: qsTranslate("Main", "¿Iniciar vaciado de nivel 2?")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                color: areaOkConfirmar2.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkConfirmar2
                    anchors.fill: parent
                    onClicked: {
                        root.mostrarConfirmacion2 = false;
                        backend.iniciarVaciado(2);   // abre solo CH8
                        root.mostrarProceso2 = true;
                    }
                }
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasConfirmar2.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmar2; anchors.fill: parent; onClicked: root.mostrarConfirmacion2 = false }
            }
        }
    }

    // ── Vaciado 2 en proceso (real) — nivel en vivo + Detener ─────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarProceso2
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.88
                spacing: appWindow.height * 0.03

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "Vaciado de nivel 2 en proceso\n(EV inferior — CH8). Se detiene solo al llegar al nivel.")
                    font.pixelSize: parent.parent.height * 0.075
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: root.textoNivelVivo()
                    font.pixelSize: parent.parent.height * 0.085
                    color: "#1a1a1a"
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: appWindow.width * 0.30
                    height: appWindow.height * 0.10
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: height / 2
                    color: areaDetener2.pressed ? "#a03030" : "#D64545"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Detener (emergencia)"); font.pixelSize: parent.height * 0.30; font.bold: true; color: "white" }
                    MouseArea {
                        id: areaDetener2
                        anchors.fill: parent
                        onClicked: {
                            backend.detenerVaciado();     // paro de emergencia (cierra válvula, cancela)
                            root.mostrarProceso2 = false;
                        }
                    }
                }
            }
        }
    }

    // ── Finalizado ────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupFinalizado
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.10
                text: qsTranslate("Main", "Proceso de cultivo\nfinalizado")
                font.pixelSize: parent.height * 0.18
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaOkFinalCosecha.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkFinalCosecha
                    anchors.fill: parent
                    onClicked: {
                        backend.finalizarVaciado();   // válvulas off + OE HIGH (seguro)
                        root.mostrarPopupFinalizado = false;
                        appWindow.estadoActual = "pantalla_13";
                    }
                }
            }
        }
    }

    // ── Aviso de aborto (tope de tiempo del vaciado) ──────────────────────────
    Item {
        anchors.fill: parent
        z: 210
        visible: root.textoAborto !== ""
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.62
            height: parent.height * 0.42
            anchors.centerIn: parent
            color: Qt.rgba(0.96, 0.90, 0.90, 0.97)
            radius: 20
            Column {
                anchors.centerIn: parent
                width: parent.width * 0.86
                spacing: appWindow.height * 0.04
                Text {
                    width: parent.width
                    text: root.textoAborto
                    font.pixelSize: parent.parent.height * 0.10
                    font.bold: true
                    color: "#b00000"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    width: appWindow.width * 0.18
                    height: appWindow.height * 0.10
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: height / 2
                    color: areaOkAborto.pressed ? "#5a8282" : "#6E9C9C"
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Entendido"); font.pixelSize: parent.height * 0.32; font.bold: true; color: "white" }
                    MouseArea { id: areaOkAborto; anchors.fill: parent; onClicked: root.textoAborto = "" }
                }
            }
        }
    }
}
