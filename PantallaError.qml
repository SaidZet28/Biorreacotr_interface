import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_de_error"

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -appWindow.height * 0.05
        spacing: appWindow.height * 0.04

        Image {
            source: "Alerta.png"
            height: appWindow.height * 0.35
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: qsTr("Se detectó un error :(")
            font.pixelSize: appWindow.height * 0.08
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15
            Text {
                text: qsTr("Error:")
                font.pixelSize: appWindow.height * 0.06
                font.bold: true
                color: "black"
            }
            Text {
                text: appWindow.textoMensajeError
                font.pixelSize: appWindow.height * 0.06
                color: "black"
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: appWindow.width * 0.08
        anchors.bottomMargin: appWindow.height * 0.08
        width: appWindow.width * 0.20
        height: appWindow.height * 0.10
        color: areaOkError.pressed ? "#7b3ce6" : "#8b5cf6"
        radius: height / 2

        Text {
            anchors.centerIn: parent
            text: qsTr("Okay")
            color: "black"
            font.pixelSize: parent.height * 0.40
            font.bold: true
        }
        MouseArea {
            id: areaOkError
            anchors.fill: parent
            onClicked: appWindow.estadoActual = appWindow.estado_sensor_retorno_error
        }
    }
}
