import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_configuracion_graficas"

    Text {
        text: qsTr("Selecciona la gráfica deseada")
        font.pixelSize: appWindow.height * 0.08
        font.bold: true
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.15
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Grid {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: appWindow.height * 0.05
        columns: 2
        spacing: appWindow.width * 0.05
        rowSpacing: appWindow.height * 0.05

        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.12
            radius: height / 2
            color: appWindow.var_seleccion_grafica === 1 ? "#7da84c" : "#8DBB5A"
            border.width: appWindow.var_seleccion_grafica === 1 ? 4 : 0
            border.color: "#4a6b4a"
            Text { anchors.centerIn: parent; text: qsTr("Temperatura °%1").arg(appWindow.unidadTemperatura); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { anchors.fill: parent; onClicked: appWindow.var_seleccion_grafica = 1 }
        }
        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.12
            radius: height / 2
            color: appWindow.var_seleccion_grafica === 2 ? "#7da84c" : "#8DBB5A"
            border.width: appWindow.var_seleccion_grafica === 2 ? 4 : 0
            border.color: "#4a6b4a"
            Text { anchors.centerIn: parent; text: qsTr("Nivel Agua"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { anchors.fill: parent; onClicked: appWindow.var_seleccion_grafica = 2 }
        }
        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.12
            radius: height / 2
            color: appWindow.var_seleccion_grafica === 3 ? "#7da84c" : "#8DBB5A"
            border.width: appWindow.var_seleccion_grafica === 3 ? 4 : 0
            border.color: "#4a6b4a"
            Text { anchors.centerIn: parent; text: qsTr("Nivel de pH"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { anchors.fill: parent; onClicked: appWindow.var_seleccion_grafica = 3 }
        }
        Rectangle {
            width: appWindow.width * 0.35
            height: appWindow.height * 0.12
            radius: height / 2
            color: appWindow.var_seleccion_grafica === 4 ? "#7da84c" : "#8DBB5A"
            border.width: appWindow.var_seleccion_grafica === 4 ? 4 : 0
            border.color: "#4a6b4a"
            Text { anchors.centerIn: parent; text: qsTr("Nivel de Luz"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { anchors.fill: parent; onClicked: appWindow.var_seleccion_grafica = 4 }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaAtrasGraficas.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2
        Text {
            anchors.centerIn: parent
            text: "↶"
            color: "black"
            font.pixelSize: parent.height * 0.70
            font.bold: true
        }
        MouseArea {
            id: areaAtrasGraficas
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_procesos"
        }
    }
}
