import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Rectangle {
    id: root
    property ApplicationWindow appWindow
    property int    indice: 0
    property string nombre: ""
    property real   temp:   0.0
    property real   ph:     0.0
    property real   agua:   0.0
    property real   luz:    0.0
    property string tiempo: ""

    signal opcionesClicked()
    signal tarjetaClicked(string nombre, real temp, real ph, real agua, real luz, string tiempo)

    radius: 20

    Image {
        source: "Engrane.png"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: width
        fillMode: Image.PreserveAspectFit
        z: 10
        MouseArea {
            anchors.fill: parent
            onClicked: root.opcionesClicked()
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: parent.width * 0.08
        spacing: parent.height * 0.015

        Text { text: qsTranslate("Main", "Proyecto %1:").arg(root.indice + 1); font.pixelSize: parent.height * 0.08; font.bold: true; color: "black" }
        Text { text: root.nombre; font.pixelSize: parent.height * 0.07; font.bold: true; color: "black"; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
        Item { height: parent.height * 0.01; width: 1 }
        Text {
            text: qsTranslate("Main", "Temp °%1: %2").arg(appWindow.unidadTemperatura).arg(appWindow.unidadTemperatura === "C" ? root.temp : (root.temp * 9/5 + 32).toFixed(1))
            font.pixelSize: parent.height * 0.06; font.bold: true; color: "black"
        }
        Text { text: qsTranslate("Main", "Nivel pH: %1").arg(root.ph);        font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
        Text { text: qsTranslate("Main", "Nivel luz: %1 %").arg(root.luz);    font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
        Text { text: qsTranslate("Main", "Tiempo: %1 hrs").arg(root.tiempo);  font.pixelSize: parent.height * 0.06; font.bold: true; color: "black" }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.tarjetaClicked(root.nombre, root.temp, root.ph, root.agua, root.luz, root.tiempo)
    }
}
