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

    onVisibleChanged: {
        if (visible) backend.buscarYConectar()
    }

    Timer {
        interval: 3000
        running: root.visible
        onTriggered: {
            if (backend.puertoConectado) {
                appWindow.estadoActual = "pantalla_principal"
            } else {
                appWindow.estado_sensor_retorno_error = "pantalla_de_carga"
                appWindow.textoMensajeError = qsTranslate("Main", "No se detectó hardware")
                appWindow.estadoActual = "pantalla_de_error"
            }
        }
    }
}
