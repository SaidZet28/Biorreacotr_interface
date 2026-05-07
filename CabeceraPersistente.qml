import QtQuick 2.15
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
        Image { source: "Logo_UPIIZ.png"; height: logoH; fillMode: Image.PreserveAspectFit }
        Image { source: "Logo_ENCB.png";  height: logoH; fillMode: Image.PreserveAspectFit }
    }
    Image {
        source: "Logo_IPN.png"
        height: logoH
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: parent.width * 0.02
        fillMode: Image.PreserveAspectFit
    }
}
