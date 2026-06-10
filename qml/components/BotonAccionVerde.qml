import QtQuick 2.15
import Prototipo
import QtQuick.Window 2.15

Rectangle {
    id: raizBoton
    property string textoBoton: ""
    signal clicado()

    width: Window.window ? Window.window.width * 0.45 : 576
    height: Window.window ? Window.window.height * 0.12 : 96
    color: areaMouseBoton.pressed ? "#5a8282" : "#6E9C9C"
    radius: height / 2

    Text {
        anchors.fill: parent
        anchors.leftMargin: parent.height * 0.40
        anchors.rightMargin: parent.height * 0.40
        text: raizBoton.textoBoton
        color: "black"
        font.pixelSize: parent.height * 0.40
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
    }
    MouseArea {
        id: areaMouseBoton
        anchors.fill: parent
        onClicked: raizBoton.clicado()
    }
}
