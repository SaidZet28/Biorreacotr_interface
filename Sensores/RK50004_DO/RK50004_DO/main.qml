import QtQuick 2.15
import QtQuick.Controls 2.15

ApplicationWindow {
    visible: true
    width: 420; height: 560
    title: "Sensor DO — RK500-04"

    Column {
        anchors.centerIn: parent
        spacing: 14

        // ── Valores actuales ──────────────────────────────────────────────
        Text {
            text: "DO: " + doHandler.valueDO.toFixed(2) + " mg/L"
            font.pixelSize: 22; font.bold: true
        }
        Text {
            text: "Saturación: " + doHandler.saturation.toFixed(1) + " %"
            font.pixelSize: 18
        }
        Text {
            text: "Temperatura: " + doHandler.temperature.toFixed(2) + " °C"
            font.pixelSize: 18
        }

        Button {
            text: "Leer sensor"
            onClicked: doHandler.requestValue()
        }

        Rectangle { width: 380; height: 1; color: "#cccccc" }

        // ── Calibración ───────────────────────────────────────────────────
        Text {
            text: "Tiempo restante: " + doHandler.remainingTime + " s"
            font.pixelSize: 18
            color: doHandler.remainingTime > 0 ? "red" : "green"
        }

        Button {
            text: "Calibrar en Aire (normal)"
            onClicked: doHandler.startStabilizationAir()
        }
        Button {
            text: "Calibrar Cero O₂ (avanzado)"
            onClicked: doHandler.startStabilizationZero()
        }
        Button {
            text: "CALIBRAR AHORA"
            enabled: doHandler.remainingTime <= 0
            onClicked: doHandler.calibrateNow()
        }

        Rectangle { width: 380; height: 1; color: "#cccccc" }

        // ── Consola de tramas ─────────────────────────────────────────────
        ScrollView {
            width: 380; height: 200
            TextArea {
                id: consoleLog
                readOnly: true
                font.family: "Courier New"
                font.pixelSize: 12
            }
        }
    }

    Connections {
        target: doHandler
        function onLogMessage(msg) { consoleLog.append(msg) }
        function onCalibrationFinished() { consoleLog.append("✓ Lista para calibrar.") }
    }
}
