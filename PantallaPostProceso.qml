import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_11"

    Row {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: appWindow.height * 0.05
        spacing: appWindow.width * 0.05

        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.45
            radius: 20
            color: areaNuevaConfig.pressed ? "#7da84c" : "#8DBB5A"
            Text {
                anchors.centerIn: parent
                text: qsTr("Nueva\nconfiguración")
                font.pixelSize: parent.height * 0.15
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: areaNuevaConfig
                anchors.fill: parent
                onClicked: {
                    appWindow.estadoPrevioPantalla6 = "pantalla_11";
                    appWindow.omitirPedirNombre = true;
                    appWindow.limpiarDatos(true);
                    appWindow.estadoActual = "pantalla_6";
                }
            }
        }

        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.45
            radius: 20
            color: areaComenzarExtraccion.pressed ? "#5a8282" : "#6E9C9C"
            Text {
                anchors.centerIn: parent
                text: qsTr("Comenzar\nextracción")
                font.pixelSize: parent.height * 0.15
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            MouseArea {
                id: areaComenzarExtraccion
                anchors.fill: parent
                onClicked: appWindow.estadoActual = "pantalla_12"
            }
        }
    }
}
