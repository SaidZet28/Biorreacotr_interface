import QtQuick 2.15
import Prototipo
import QtQuick.Window 2.15

Rectangle {
    property string textoEtiqueta: ""
    property string textoValor: ""

    width: Window.window ? Window.window.width * 0.35 : 448
    height: Window.window ? Window.window.height * 0.08 : 64
    color: "#8DBB5A"
    radius: height / 2

    Text {
        anchors.left: parent.left
        anchors.leftMargin: parent.height * 0.40
        anchors.right: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        text: textoEtiqueta
        font.pixelSize: parent.height * 0.40
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.55
        anchors.right: parent.right
        anchors.rightMargin: parent.height * 0.20
        anchors.verticalCenter: parent.verticalCenter
        text: textoValor
        font.pixelSize: parent.height * 0.40
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
    }
}
