import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    property ApplicationWindow appWindow

    signal confirmado()
    signal cancelado()

    anchors.fill: parent
    z: 200

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
            text: qsTranslate("Main", "¿Desea borrar este proyecto guardado?")
            font.pixelSize: parent.height * 0.10
            font.bold: true
            color: "black"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.9
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: appWindow.width * 0.12
            height: appWindow.height * 0.08
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.15
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.10
            color: areaOk.pressed ? "#6b42b5" : "#8b5cf6"
            radius: height / 2
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { id: areaOk; anchors.fill: parent; onClicked: confirmado() }
        }

        Rectangle {
            width: appWindow.width * 0.12
            height: appWindow.height * 0.08
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.15
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.10
            color: areaAtras.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2
            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
            MouseArea { id: areaAtras; anchors.fill: parent; onClicked: cancelado() }
        }
    }
}
