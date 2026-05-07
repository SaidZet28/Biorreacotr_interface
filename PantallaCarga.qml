import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_de_carga"

    Column {
        anchors.centerIn: parent
        spacing: 20
        Text {
            text: qsTranslate("Main", "Cargando")
            font.pixelSize: 64
            font.bold: true
        }
        BusyIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            running: root.visible
        }
    }

    Timer {
        interval: 3000
        running: root.visible
        onTriggered: {
            if (appWindow.sensor_estado_primero === 1) {
                appWindow.estadoActual = "pantalla_principal"
            } else {
                appWindow.estado_sensor_retorno_error = "pantalla_de_carga"
                appWindow.textoMensajeError = qsTranslate("Main", "Falla en sensor")
                appWindow.estadoActual = "pantalla_de_error"
            }
        }
    }
}
