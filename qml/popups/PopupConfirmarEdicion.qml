import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    property string nombre: ""
    property real   temp:   0.0
    property real   ph:     0.0
    property real   agua:   0.0
    property real   luz:    0.0
    property string tiempo: ""

    signal confirmado()
    signal cancelado()

    anchors.fill: parent
    z: 200

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    Rectangle {
        id: caja
        width: parent.width * 0.85
        height: parent.height * 0.65
        anchors.centerIn: parent
        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
        radius: 20

        Text {
            anchors.top: parent.top
            anchors.topMargin: caja.height * 0.05
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.9
            text: qsTranslate("Main", "¿Estás seguro que quieres guardar los cambios hechos al proyecto?")
            font.pixelSize: caja.height * 0.06
            color: "#cc0000"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: caja.height * 0.02
            width: parent.width * 0.90
            spacing: caja.height * 0.03

            Text {
                textFormat: Text.RichText
                text: qsTranslate("Main", "Proyecto: <b>%1</b>").arg(root.nombre)
                font.pixelSize: caja.height * 0.055
                color: "black"; width: parent.width; wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: parent.width * 0.02
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Temperatura: <b>%1 °%2</b>").arg(appWindow.tempMostrada(root.temp).toFixed(1)).arg(appWindow.unidadTemperatura)
                    font.pixelSize: caja.height * 0.055; color: "black"; wrapMode: Text.WordWrap
                }
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de pH: <b>%1</b>").arg(root.ph.toFixed(1))
                    font.pixelSize: caja.height * 0.055; color: "black"; wrapMode: Text.WordWrap
                }
            }

            Row {
                width: parent.width
                spacing: parent.width * 0.02
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de llenado: <b>fijo por hardware</b>")
                    font.pixelSize: caja.height * 0.055; color: "black"; wrapMode: Text.WordWrap
                }
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de luz: <b>%1 %</b>").arg(root.luz.toFixed(1))
                    font.pixelSize: caja.height * 0.055; color: "black"; wrapMode: Text.WordWrap
                }
            }

            Text {
                textFormat: Text.RichText
                property int t_total:   parseFloat(root.tiempo) || 0
                property int t_semanas: Math.floor(t_total / 168)
                property int t_dias:    Math.floor((t_total % 168) / 24)
                property int t_horas:   Math.floor(t_total % 24)
                property int t_minutos: Math.round((t_total - Math.floor(t_total)) * 60)
                text: qsTranslate("Main", "Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)").arg(t_semanas).arg(t_dias).arg(t_horas).arg(t_minutos).arg(t_total.toFixed(1))
                font.pixelSize: caja.height * 0.055; color: "black"; width: parent.width; wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: appWindow.width * 0.05
            anchors.bottomMargin: caja.height * 0.05
            width: appWindow.width * 0.20
            height: appWindow.height * 0.10
            color: areaOk.pressed ? "#6b42b5" : "#8b5cf6"
            radius: height / 2
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea { id: areaOk; anchors.fill: parent; onClicked: root.confirmado() }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: appWindow.width * 0.05
            anchors.bottomMargin: caja.height * 0.05
            width: appWindow.width * 0.12
            height: appWindow.height * 0.10
            color: areaAtras.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2
            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
            MouseArea { id: areaAtras; anchors.fill: parent; onClicked: root.cancelado() }
        }
    }
}
