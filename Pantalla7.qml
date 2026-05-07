import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_7"

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: appWindow.height * 0.05
        spacing: appWindow.height * 0.05

        Text {
            text: qsTr("Calibración rápida")
            font.pixelSize: appWindow.height * 0.10
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: qsTr("Espere un momento por favor")
            font.pixelSize: appWindow.height * 0.05
            font.bold: true
            color: "black"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Image {
            id: hongoCalibracion
            source: "Hongo_5.png"
            width: appWindow.width * 0.20
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter

            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: root.visible
                NumberAnimation {
                    from: 0
                    to: 360
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation {
                    duration: 600
                }
            }
        }
    }
    Timer {
        interval: 3500
        running: root.visible
        onTriggered: {
            if (appWindow.sensor_estado_calibracion === 1) {
                appWindow.estadoActual = "pantalla_procesos"
            } else {
                appWindow.estado_sensor_retorno_error = "pantalla_7"
                appWindow.textoMensajeError = qsTr("Error en calibración rápida")
                appWindow.estadoActual = "pantalla_de_error"
            }
        }
    }
}
