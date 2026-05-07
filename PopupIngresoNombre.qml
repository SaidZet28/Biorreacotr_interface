import QtQuick 2.15
import QtQuick.Window 2.15

Item {
    id: raizPopup
    anchors.fill: parent
    z: 100
    visible: false

    property string tituloPopup: qsTranslate("Main", "Ingrese nombre")
    property string nombrePorDefecto: ""
    property bool tecladoVisible: false

    signal aceptado(string nombre)
    signal cancelado()

    onVisibleChanged: {
        if (visible) {
            entradaNombre.text = nombrePorDefecto;
            tecladoVisible = false;
            entradaNombre.focus = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (raizPopup.tecladoVisible) {
                raizPopup.tecladoVisible = false;
                entradaNombre.focus = false;
            }
        }
    }

    Rectangle {
        id: cajaPopup
        width: parent.width * 0.75
        height: parent.height * 0.55
        anchors.horizontalCenter: parent.horizontalCenter
        y: raizPopup.tecladoVisible ? parent.height * 0.05 : parent.height * 0.225
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
        color: Qt.rgba(0.7, 0.7, 0.7, 0.9)
        radius: 20

        Text {
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.15
            anchors.horizontalCenter: parent.horizontalCenter
            text: raizPopup.tituloPopup
            font.pixelSize: parent.height * 0.08
            font.bold: true
            color: "black"
        }

        Item {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.height * 0.05
            width: parent.width * 0.85
            height: parent.height * 0.15

            TextInput {
                id: entradaNombre
                anchors.fill: parent
                font.pixelSize: parent.height * 0.50
                color: "black"
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignBottom
                bottomPadding: parent.height * 0.10
                maximumLength: 100
                activeFocusOnPress: true

                onActiveFocusChanged: {
                    if (activeFocus) raizPopup.tecladoVisible = true;
                }
                onAccepted: {
                    raizPopup.tecladoVisible = false;
                    entradaNombre.focus = false;
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 3
                color: "black"
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: Window.window ? Window.window.width * 0.05 : 64
            anchors.bottomMargin: parent.height * 0.10
            width: Window.window ? Window.window.width * 0.20 : 256
            height: Window.window ? Window.window.height * 0.10 : 80
            color: areaOkPopup.pressed ? "#6b42b5" : "#8b5cf6"
            radius: height / 2

            Text {
                anchors.centerIn: parent
                text: qsTranslate("Main", "Okay")
                color: "black"
                font.pixelSize: parent.height * 0.40
                font.bold: true
            }
            MouseArea {
                id: areaOkPopup
                anchors.fill: parent
                onClicked: raizPopup.aceptado(entradaNombre.text)
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Window.window ? Window.window.width * 0.05 : 64
            anchors.bottomMargin: parent.height * 0.10
            width: Window.window ? Window.window.width * 0.12 : 154
            height: Window.window ? Window.window.height * 0.10 : 80
            color: areaAtrasPopup.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2

            Text {
                anchors.centerIn: parent
                text: "↶"
                color: "black"
                font.pixelSize: parent.height * 0.70
                font.bold: true
            }
            MouseArea {
                id: areaAtrasPopup
                anchors.fill: parent
                onClicked: raizPopup.cancelado()
            }
        }
    }

    TecladoQwerty {
        id: tecladoVirtual
        z: 105
        width: parent.width * 0.95
        height: parent.height * 0.45
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: raizPopup.tecladoVisible ? 10 : parent.height * -0.50
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

        onTeclaPresionada:  function(t) { entradaNombre.text += t }
        onBorrarPresionado: { if (entradaNombre.text.length > 0) entradaNombre.text = entradaNombre.text.slice(0, -1) }
        onIntroPresionado:  { raizPopup.tecladoVisible = false; entradaNombre.focus = false }
        onCerrarPresionado: { raizPopup.tecladoVisible = false; entradaNombre.focus = false }
    }
}
