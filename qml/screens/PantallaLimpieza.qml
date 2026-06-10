import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_14"

    Text {
        text: qsTranslate("Main", "Recuerda limpiar el\nbiorreactor ;)")
        font.pixelSize: appWindow.height * 0.12
        font.bold: true
        color: "black"
        horizontalAlignment: Text.AlignHCenter
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.20
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Image {
        source: "../../Hongo_8.png"
        anchors.left: parent.left
        anchors.leftMargin: appWindow.width * 0.05
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.05
        height: appWindow.height * 0.315
        fillMode: Image.PreserveAspectFit
    }

    Image {
        source: "../../Hongo_9.png"
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.05
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.05
        height: appWindow.height * 0.315
        fillMode: Image.PreserveAspectFit
    }

    Rectangle {
        width: appWindow.width * 0.20
        height: appWindow.height * 0.12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: appWindow.height * 0.15
        anchors.horizontalCenter: parent.horizontalCenter
        color: areaOkLimpieza.pressed ? "#6b42b5" : "#8b5cf6"
        radius: height / 2
        Text {
            anchors.centerIn: parent
            text: qsTranslate("Main", "Okay")
            font.pixelSize: parent.height * 0.40
            font.bold: true
            color: "black"
        }
        MouseArea {
            id: areaOkLimpieza
            anchors.fill: parent
            onClicked: {
                appWindow.limpiarDatos(false);
                appWindow.omitirPedirNombre = false;
                appWindow.estadoActual = "pantalla_principal";
            }
        }
    }
}
