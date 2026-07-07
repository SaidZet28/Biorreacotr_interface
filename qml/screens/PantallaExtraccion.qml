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
            // Detener timers de vaciado si el usuario navega fuera a mitad del proceso
            mostrarProceso1 = false;
            mostrarProceso2 = false;
        }
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
                    onClicked: { root.mostrarConfirmacion1 = false; root.mostrarProceso1 = true; }
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
                Text { anchors.centerIn: parent; text: "?"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmar1; anchors.fill: parent; onClicked: root.mostrarConfirmacion1 = false }
            }
        }
    }

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
            Text {
                anchors.centerIn: parent
                text: qsTranslate("Main", "Vaciado de nivel 1 en proceso,\nespere un momento por favor :)")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.9
                wrapMode: Text.WordWrap
            }
        }
        Timer {
            interval: appWindow.var_vaciado_nivel_1
            running: root.mostrarProceso1
            onTriggered: { root.mostrarProceso1 = false; root.nivel1Completado = true; audio.reproducirExito() }
        }
    }

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
                    onClicked: { root.mostrarConfirmacion2 = false; root.mostrarProceso2 = true; }
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
                Text { anchors.centerIn: parent; text: "?"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmar2; anchors.fill: parent; onClicked: root.mostrarConfirmacion2 = false }
            }
        }
    }

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
            Text {
                anchors.centerIn: parent
                text: qsTranslate("Main", "Vaciado de nivel 2 en proceso,\nespere un momento por favor :)")
                font.pixelSize: parent.height * 0.10
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.9
                wrapMode: Text.WordWrap
            }
        }
        Timer {
            interval: appWindow.var_vaciado_nivel_2
            running: root.mostrarProceso2
            onTriggered: { root.mostrarProceso2 = false; root.mostrarPopupFinalizado = true; audio.reproducirExito() }
        }
    }

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
                    onClicked: { root.mostrarPopupFinalizado = false; appWindow.estadoActual = "pantalla_13"; }
                }
            }
        }
    }
}
