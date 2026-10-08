import QtQuick 2.15
import Prototipo
import QtQuick.Window 2.15

Item {
    id: cabecera
    width: parent ? parent.width : 1280
    height: Window.window ? Window.window.height * 0.15 : 120
    anchors.top: parent ? parent.top : undefined
    z: 100

    property real logoH: height

    // Reloj: hora del sistema (respaldada por el RTC DS3231 en el arranque).
    property var horaAhora: new Date()
    Timer { interval: 1000; running: true; repeat: true
            onTriggered: cabecera.horaAhora = new Date() }

    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: parent.width * 0.02
        spacing: parent.width * 0.02
        Image { source: "../../Logo_UPIIZ.png"; height: logoH; fillMode: Image.PreserveAspectFit }
        Image { source: "../../Logo_ENCB.png";  height: logoH; fillMode: Image.PreserveAspectFit }
    }
    Image {
        id: logoIPN
        source: "../../Logo_IPN.png"
        height: logoH
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: parent.width * 0.02
        fillMode: Image.PreserveAspectFit
    }

    // ── Indicador esquina superior: reloj + temperatura del gabinete (RTC) ─────
    Row {
        anchors.verticalCenter: logoIPN.verticalCenter
        anchors.right: logoIPN.left
        anchors.rightMargin: parent.width * 0.02
        spacing: parent.width * 0.012

        // Reloj
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(cabecera.horaAhora, "HH:mm:ss")
            font.pixelSize: cabecera.height * 0.22
            font.bold: true
            color: "#1C1917"
        }

        // Píldora de temperatura de la HMI (verde ≤25, ámbar 25–30, rojo >30 °C).
        // Oculta si no hay lectura del sensor (tempHmi < 0).
        Rectangle {
            visible: backend.tempHmi >= 0
            anchors.verticalCenter: parent.verticalCenter
            width: tempLabel.implicitWidth + cabecera.height * 0.22
            height: tempLabel.implicitHeight + cabecera.height * 0.10
            radius: height / 2
            color: backend.tempHmi > 30 ? "#EF4444"
                 : backend.tempHmi > 25 ? "#F59E0B"
                 :                        "#16A34A"

            Text {
                id: tempLabel
                anchors.centerIn: parent
                text: "HMI " + backend.tempHmi.toFixed(1) + " °C"
                font.pixelSize: cabecera.height * 0.20
                font.bold: true
                color: "white"
            }
        }
    }

    // Banner de simulación — visible solo cuando SIMULACION_ACTIVA está definido
    Rectangle {
        visible: backend.modoSimulacion
        anchors.centerIn: parent
        width: labelSim.implicitWidth + 32
        height: labelSim.implicitHeight + 10
        radius: 6
        color: "#F59E0B"

        SequentialAnimation on opacity {
            running: backend.modoSimulacion
            loops: Animation.Infinite
            NumberAnimation { to: 0.55; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.00; duration: 800; easing.type: Easing.InOutSine }
        }

        Text {
            id: labelSim
            anchors.centerIn: parent
            text: "?  MODO SIMULACIÓN — SIN HARDWARE REAL"
            font.pixelSize: parent.parent.height * 0.11
            font.bold: true
            color: "#1C1917"
        }
    }
}
