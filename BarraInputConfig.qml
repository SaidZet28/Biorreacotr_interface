import QtQuick 2.15
import QtQuick.Window 2.15

Rectangle {
    property string idCampo: ""
    property string textoEtiqueta: ""
    property string valorMostrado: ""
    property string campoActivo: ""
    signal barraClicada()

    width: Window.window ? Window.window.width * 0.45 : 576
    height: Window.window ? Window.window.height * 0.08 : 64
    color: campoActivo === idCampo ? "#A5D6A7" : "#8DBB5A"
    radius: height / 2

    MouseArea {
        anchors.fill: parent
        onClicked: barraClicada()
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: parent.height * 0.40
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.38
        text: textoEtiqueta
        font.pixelSize: parent.height * 0.40
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.45
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * 0.50
        text: valorMostrado
        font.pixelSize: parent.height * 0.40
        font.bold: true
        horizontalAlignment: Text.AlignLeft
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
    }
}
