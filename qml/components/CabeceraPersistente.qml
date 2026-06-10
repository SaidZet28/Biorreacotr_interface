import QtQuick 2.15
import Prototipo
import QtQuick.Window 2.15

Item {
    width: parent ? parent.width : 1280
    height: Window.window ? Window.window.height * 0.15 : 120
    anchors.top: parent ? parent.top : undefined
    z: 100

    property real logoH: height

    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: parent.width * 0.02
        spacing: parent.width * 0.02
        Image { source: "../../Logo_UPIIZ.png"; height: logoH; fillMode: Image.PreserveAspectFit }
        Image { source: "../../Logo_ENCB.png";  height: logoH; fillMode: Image.PreserveAspectFit }
    }
    Image {
        source: "../../Logo_IPN.png"
        height: logoH
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: parent.width * 0.02
        fillMode: Image.PreserveAspectFit
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
