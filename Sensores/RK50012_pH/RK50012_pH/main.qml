
import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 400; height: 500
    title: "Sensor pH"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Button {
            text: "Iniciar Estabilización pH 7"
            onClicked: phHandler.startStabilization(7)
        }
        Button {
            text: "Iniciar Estabilización pH 4"
            onClicked: phHandler.startStabilization(4)
        }
        Button {
            text: "Iniciar Estabilización pH 10"
            onClicked: phHandler.startStabilization(10)
        }
        Text {
            text: "Tiempo de estabilización: " + phHandler.remainingTime + "s"
            font.pixelSize: 20
            color: phHandler.remainingTime > 0 ? "red" : "green"
        }


        Button {
            text: "CALIBRAR AHORA"
            enabled: phHandler.remainingTime <= 0
            onClicked: phHandler.calibrateNow()
        }

        Button {
            text: "Leer sensor"
            onClicked: phHandler.requestValue()
        }

        // Consola de tramas
        ScrollView {
            width: 350; height: 200
            TextArea {
                id: consoleLog
                text: ""
                readOnly: true
            }
        }
    }

    // Conectar señales de C++ a QML para ver los logs
    Connections {
        target: phHandler
        function onLogMessage(msg) {
            consoleLog.append(msg)
        }
    }
}
