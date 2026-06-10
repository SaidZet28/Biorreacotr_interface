import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    property ApplicationWindow appWindow

    signal editarSolicitado()
    signal borrarSolicitado()
    signal cerrado()

    anchors.fill: parent
    z: 200

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
            text: qsTranslate("Main", "Opciones del proyecto")
            font.pixelSize: parent.height * 0.10
            font.bold: true
            color: "black"
        }

        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -10
            spacing: appWindow.width * 0.05

            Rectangle {
                width: appWindow.width * 0.12
                height: width
                radius: 20
                color: areaLapiz.pressed ? "#d1d5db" : "#F3F4F6"
                Image { source: "../../Lapiz.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                MouseArea { id: areaLapiz; anchors.fill: parent; onClicked: editarSolicitado() }
            }

            Rectangle {
                width: appWindow.width * 0.12
                height: width
                radius: 20
                color: areaPapelera.pressed ? "#d1d5db" : "#F3F4F6"
                Image { source: "../../Basura.png"; anchors.centerIn: parent; width: parent.width * 0.6; fillMode: Image.PreserveAspectFit }
                MouseArea { id: areaPapelera; anchors.fill: parent; onClicked: borrarSolicitado() }
            }
        }

        Rectangle {
            width: appWindow.width * 0.12
            height: appWindow.height * 0.08
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            anchors.horizontalCenter: parent.horizontalCenter
            color: areaAtras.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2
            Text { anchors.centerIn: parent; text: "?"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
            MouseArea { id: areaAtras; anchors.fill: parent; onClicked: cerrado() }
        }
    }
}
