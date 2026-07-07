import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    property string nombreInicial: ""
    property real   tempInicial:   0.0
    property real   phInicial:     0.0
    property real   aguaInicial:   0.0
    property real   luzInicial:    0.0
    property string tiempoInicial: ""

    signal confirmadoEdicion(string nombre, real temp, real ph, real agua, real luz, string tiempo)
    signal cancelado()

    property string campoActivo: ""
    property string entradaTemporal: ""

    QtObject {
        id: datos
        property string nombre: ""
        property real   temp:   0.0
        property real   ph:     0.0
        property real   agua:   0.0
        property real   luz:    0.0
        property string tiempo: ""
    }

    onVisibleChanged: {
        if (visible) {
            datos.nombre = nombreInicial
            datos.temp   = tempInicial
            datos.ph     = phInicial
            datos.agua   = aguaInicial
            datos.luz    = luzInicial
            datos.tiempo = tiempoInicial
            root.campoActivo = ""
            root.entradaTemporal = ""
        }
    }

    function aplicarValor() {
        let val = parseFloat(root.entradaTemporal)
        if (!isNaN(val)) {
            if (root.campoActivo === "Tem") {
                datos.temp = Math.max(20, Math.min(100, appWindow.tempACelsius(val)))   // guardar en °C
            } else if (root.campoActivo === "pH")    datos.ph   = Math.max(1,  Math.min(14,  val))
              else if (root.campoActivo === "Luz")    datos.luz  = Math.max(0,  Math.min(100, val))
              else if (root.campoActivo === "Tiempo") datos.tiempo = Math.max(6, val).toString()
        }
        root.campoActivo = ""
        root.entradaTemporal = ""
    }

    anchors.fill: parent
    z: 200
    focus: visible

    Keys.onPressed: (event) => {
        if (root.campoActivo === "Nombre") {
            if (event.key === Qt.Key_Backspace) {
                if (datos.nombre.length > 0)
                    datos.nombre = datos.nombre.substring(0, datos.nombre.length - 1)
            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                root.campoActivo = ""
            } else if (event.text.length > 0) {
                datos.nombre += event.text
            }
            event.accepted = true
        } else if (root.campoActivo !== "") {
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                let digito = (event.key - Qt.Key_0).toString()
                root.entradaTemporal = (root.entradaTemporal === "0") ? digito : root.entradaTemporal + digito
                event.accepted = true
            } else if (event.key === Qt.Key_Period) {
                if (root.entradaTemporal.indexOf(".") === -1)
                    root.entradaTemporal += (root.entradaTemporal === "" ? "0." : ".")
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (root.entradaTemporal.length > 0)
                    root.entradaTemporal = root.entradaTemporal.substring(0, root.entradaTemporal.length - 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                root.aplicarValor()
                event.accepted = true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.campoActivo = ""
    }

    Rectangle {
        width: parent.width * 0.80
        height: parent.height * 0.85
        anchors.centerIn: parent
        color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
        radius: 20
        clip: true

        MouseArea { anchors.fill: parent; onClicked: root.campoActivo = "" }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTranslate("Main", "Editar Proyecto")
            font.pixelSize: parent.height * 0.06
            font.bold: true
            color: "black"
        }

        Row {
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.15
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.95
            height: parent.height * 0.45
            spacing: 15

            Column {
                width: parent.width * 0.55
                height: parent.height
                spacing: parent.height * 0.035

                Rectangle {
                    width: parent.width; height: parent.height * 0.13; radius: height/2
                    color: root.campoActivo === "Nombre" ? "#A5D6A7" : "#8DBB5A"
                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nombre:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.35; anchors.right: parent.right; anchors.rightMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: root.campoActivo === "Nombre" ? datos.nombre + "|" : datos.nombre; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black"; elide: Text.ElideRight }
                    MouseArea { anchors.fill: parent; onClicked: { root.campoActivo = "Nombre"; root.forceActiveFocus() } }
                }
                Rectangle {
                    width: parent.width; height: parent.height * 0.13; radius: height/2
                    color: root.campoActivo === "Tem" ? "#A5D6A7" : "#8DBB5A"
                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Temp °%1:").arg(appWindow.unidadTemperatura); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: root.campoActivo === "Tem" ? root.entradaTemporal + "|" : datos.temp; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: { root.campoActivo = "Tem"; root.entradaTemporal = ""; root.forceActiveFocus() } }
                }
                Rectangle {
                    width: parent.width; height: parent.height * 0.13; radius: height/2
                    color: root.campoActivo === "pH" ? "#A5D6A7" : "#8DBB5A"
                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel de pH:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: root.campoActivo === "pH" ? root.entradaTemporal + "|" : datos.ph; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: { root.campoActivo = "pH"; root.entradaTemporal = ""; root.forceActiveFocus() } }
                }
                Rectangle {
                    width: parent.width; height: parent.height * 0.13; radius: height/2
                    color: root.campoActivo === "Luz" ? "#A5D6A7" : "#8DBB5A"
                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Nivel luz %:"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: root.campoActivo === "Luz" ? root.entradaTemporal + "|" : datos.luz; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: { root.campoActivo = "Luz"; root.entradaTemporal = ""; root.forceActiveFocus() } }
                }
                Rectangle {
                    width: parent.width; height: parent.height * 0.13; radius: height/2
                    color: root.campoActivo === "Tiempo" ? "#A5D6A7" : "#8DBB5A"
                    Text { anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter; text: qsTranslate("Main", "Duración (h):"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    Text { anchors.left: parent.left; anchors.leftMargin: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter; text: root.campoActivo === "Tiempo" ? root.entradaTemporal + "|" : datos.tiempo; font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                    MouseArea { anchors.fill: parent; onClicked: { root.campoActivo = "Tiempo"; root.entradaTemporal = ""; root.forceActiveFocus() } }
                }
            }

            TecladoNumerico {
                width: parent.width * 0.45 - 15
                height: parent.height * 0.95
                anchors.verticalCenter: parent.verticalCenter
                visible: root.campoActivo !== "" && root.campoActivo !== "Nombre"
                onDigitoPresionado: function(d) { root.entradaTemporal = root.entradaTemporal === "0" ? d : root.entradaTemporal + d }
                onPuntoPresionado:  { if (root.entradaTemporal.indexOf(".") === -1) root.entradaTemporal += root.entradaTemporal === "" ? "0." : "." }
                onBorrarPresionado: { if (root.entradaTemporal.length > 0) root.entradaTemporal = root.entradaTemporal.slice(0, -1) }
                onOkPresionado:     { root.aplicarValor() }
            }
        }

        Rectangle {
            width: appWindow.width * 0.15
            height: appWindow.height * 0.08
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.15
            color: areaOk.pressed ? "#6b42b5" : "#8b5cf6"
            radius: height / 2
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
            MouseArea {
                id: areaOk
                anchors.fill: parent
                enabled: root.campoActivo === ""
                onClicked: root.confirmadoEdicion(datos.nombre, datos.temp, datos.ph, datos.agua, datos.luz, datos.tiempo)
            }
        }

        Rectangle {
            width: appWindow.width * 0.15
            height: appWindow.height * 0.08
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.15
            color: areaAtras.pressed ? "#cc1e1e" : "#FF2D2D"
            radius: height / 2
            Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
            MouseArea {
                id: areaAtras
                anchors.fill: parent
                enabled: root.campoActivo === ""
                onClicked: { root.campoActivo = ""; root.cancelado() }
            }
        }

        TecladoQwerty {
            z: 100
            width: parent.width * 0.95
            height: parent.height * 0.35
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.campoActivo === "Nombre" ? 10 : parent.height * -0.50
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            onTeclaPresionada:  function(t) { datos.nombre += t }
            onBorrarPresionado: { if (datos.nombre.length > 0) datos.nombre = datos.nombre.slice(0, -1) }
            onIntroPresionado:  { root.campoActivo = "" }
            onCerrarPresionado: { root.campoActivo = "" }
        }
    }
}
