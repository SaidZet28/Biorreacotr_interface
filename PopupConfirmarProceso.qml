import QtQuick 2.15
import QtQuick.Window 2.15

Item {
    id: raizConfirmacion
    anchors.fill: parent
    z: 200
    visible: false

    property string nombreProyecto: ""
    property string nombreExperimento: ""
    property real temp: 0.0
    property real ph: 0.0
    property real agua: 0.0
    property real luz: 0.0
    property real tiempoSemanas: 0.0
    property real tiempoDias: 0.0
    property real tiempoHoras: 0.0
    property real tiempoMinutos: 0.0
    property real tiempoTotal: 0.0
    property string unidadTemperatura: "C"

    signal confirmado()
    signal cancelado()

    MouseArea { anchors.fill: parent }

    Rectangle {
        id: cajaConfirmacion
        width: parent.width * 0.85
        height: parent.height * 0.65
        anchors.centerIn: parent
        color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
        radius: 20

        Text {
            id: tituloConfirmacion
            anchors.top: parent.top
            anchors.topMargin: cajaConfirmacion.height * 0.05
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.9
            text: qsTranslate("Main", "¿Estás seguro de que quieres iniciar el proceso de cultivo?")
            font.pixelSize: cajaConfirmacion.height * 0.06
            font.bold: false
            color: "#cc0000"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cajaConfirmacion.height * 0.02
            width: parent.width * 0.90
            spacing: cajaConfirmacion.height * 0.03

            Text {
                textFormat: Text.RichText
                text: qsTranslate("Main", "Proyecto: <b>%1</b>").arg(raizConfirmacion.nombreProyecto) +
                      (raizConfirmacion.nombreExperimento !== "" ? qsTranslate("Main", " | Experimento: <b>%1</b>").arg(raizConfirmacion.nombreExperimento) : "")
                font.pixelSize: cajaConfirmacion.height * 0.055
                color: "black"
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: parent.width * 0.02
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Temperatura: <b>%1 °%2</b>").arg(raizConfirmacion.temp).arg(raizConfirmacion.unidadTemperatura)
                    font.pixelSize: cajaConfirmacion.height * 0.055
                    color: "black"
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de pH: <b>%1</b>").arg(raizConfirmacion.ph)
                    font.pixelSize: cajaConfirmacion.height * 0.055
                    color: "black"
                    wrapMode: Text.WordWrap
                }
            }

            Row {
                width: parent.width
                spacing: parent.width * 0.02
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de agua: <b>%1 %</b>").arg(raizConfirmacion.agua)
                    font.pixelSize: cajaConfirmacion.height * 0.055
                    color: "black"
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: (parent.width / 2) - (parent.width * 0.01)
                    textFormat: Text.RichText
                    text: qsTranslate("Main", "Nivel de luz: <b>%1 %</b>").arg(raizConfirmacion.luz)
                    font.pixelSize: cajaConfirmacion.height * 0.055
                    color: "black"
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                textFormat: Text.RichText
                text: qsTranslate("Main", "Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)")
                      .arg(raizConfirmacion.tiempoSemanas)
                      .arg(raizConfirmacion.tiempoDias)
                      .arg(raizConfirmacion.tiempoHoras)
                      .arg(raizConfirmacion.tiempoMinutos)
                      .arg(raizConfirmacion.tiempoTotal.toFixed(1))
                font.pixelSize: cajaConfirmacion.height * 0.055
                color: "black"
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Window.window ? Window.window.width * 0.05 : 64
            anchors.bottomMargin: cajaConfirmacion.height * 0.05
            width: Window.window ? Window.window.width * 0.20 : 256
            height: Window.window ? Window.window.height * 0.10 : 80
            color: areaOkConfirmar.pressed ? "#6b42b5" : "#8b5cf6"
            radius: height / 2
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); color: "black"; font.pixelSize: parent.height * 0.40; font.bold: true }
            MouseArea {
                id: areaOkConfirmar
                anchors.fill: parent
                onClicked: raizConfirmacion.confirmado()
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Window.window ? Window.window.width * 0.05 : 64
            anchors.bottomMargin: cajaConfirmacion.height * 0.05
            width: Window.window ? Window.window.width * 0.12 : 154
            height: Window.window ? Window.window.height * 0.10 : 80
            color: areaAtrasConfirmar.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2
            Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
            MouseArea {
                id: areaAtrasConfirmar
                anchors.fill: parent
                onClicked: raizConfirmacion.cancelado()
            }
        }
    }
}
