import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow
    property bool mostrarPopupSiesta: false

    visible: appWindow.estadoActual === "pantalla_principal"

    Image {
        source: "../../Hongo_3.png"
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: parent.width * 0.02
        width: parent.width * 0.11
        fillMode: Image.PreserveAspectFit
    }

    Column {
        id: columnaBarrasPrincipales
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.05
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: appWindow.height * 0.03
        spacing: parent.height * 0.03

        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Temperatura:"); textoValor: qsTranslate("Main", "%1 °%2").arg(backend.sensorSerialValido ? (appWindow.unidadTemperatura === "F" ? (backend.sensorTem * 9/5 + 32) : backend.sensorTem).toFixed(1) : "---").arg(appWindow.unidadTemperatura) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de pH:"); textoValor: qsTranslate("Main", "%1").arg(backend.sensorSerialValido ? backend.sensorPH.toFixed(1) : "---") }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de agua:"); textoValor: qsTranslate("Main", "%1 %").arg(backend.sensorNivelValido ? backend.sensorNivel.toFixed(0) : "---") }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "Nivel de luz:"); textoValor: qsTranslate("Main", "%1 %").arg(backend.sensorLuz.toFixed(0)) }
        BarraDisplaySensor { textoEtiqueta: qsTranslate("Main", "OD:"); textoValor: qsTranslate("Main", "%1 mg/L").arg(backend.sensorSerialValido ? backend.sensorDO.toFixed(2) : "---") }
    }

    Column {
        anchors.left: parent.left
        anchors.right: columnaBarrasPrincipales.left
        anchors.top: columnaBarrasPrincipales.top
        spacing: columnaBarrasPrincipales.spacing

        BotonAccionVerde {
            anchors.horizontalCenter: parent.horizontalCenter
            textoBoton: qsTranslate("Main", "Nuevo Proyecto")
            onClicado: {
                appWindow.omitirPedirNombre = false;
                appWindow.estadoActual = "pantalla_nuevo_proyecto";
            }
        }
        BotonAccionVerde {
            anchors.horizontalCenter: parent.horizontalCenter
            textoBoton: qsTranslate("Main", "Datos Guardados")
            onClicado: {
                appWindow.omitirPedirNombre = false;
                appWindow.estadoActual = "pantalla_15";
            }
        }
    }

    Rectangle {
        id: botonAjustes
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: appWindow.width * 0.05
        anchors.bottomMargin: appWindow.height * 0.04
        width: appWindow.width * 0.09
        height: appWindow.height * 0.11
        radius: width * 0.35
        color: areaMouseEngrane.pressed ? "#9ca3af" : "#B3B3B3"

        Image {
            source: "../../Engrane.png"
            anchors.centerIn: parent
            width: parent.width * 0.65
            height: parent.height * 0.65
            fillMode: Image.PreserveAspectFit
        }
        MouseArea {
            id: areaMouseEngrane
            anchors.fill: parent
            onClicked: {
                appWindow.estadoPrevioAjustes = "pantalla_principal"
                appWindow.estadoActual = "pantalla_configuraciones"
            }
        }
    }

    // ── Botón Modo siesta (apaga la RP de forma limpia) ───────────────────────
    Rectangle {
        id: botonSiesta
        anchors.bottom: parent.bottom
        anchors.right: botonAjustes.left
        anchors.rightMargin: appWindow.width * 0.025
        anchors.bottomMargin: appWindow.height * 0.04
        width: appWindow.width * 0.09
        height: appWindow.height * 0.11
        radius: width * 0.35
        color: areaSiesta.pressed ? "#c98a3a" : "#E0A24E"
        Text {
            anchors.centerIn: parent
            text: qsTranslate("Main", "Siesta")
            font.pixelSize: parent.height * 0.24
            font.bold: true
            color: "white"
        }
        MouseArea { id: areaSiesta; anchors.fill: parent; onClicked: root.mostrarPopupSiesta = true }
    }

    // ── Popup confirmar modo siesta ───────────────────────────────────────────
    Item {
        anchors.fill: parent
        z: 300
        visible: root.mostrarPopupSiesta
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.55
            height: parent.height * 0.42
            anchors.centerIn: parent
            color: Qt.rgba(0.92, 0.92, 0.92, 0.97)
            radius: 20

            Column {
                anchors.centerIn: parent
                width: parent.width * 0.86
                spacing: appWindow.height * 0.045

                Text {
                    width: parent.width
                    text: qsTranslate("Main", "¿Poner el equipo en modo siesta? Se detiene todo de forma segura y la Raspberry se apaga.")
                    font.pixelSize: appWindow.height * 0.032
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: appWindow.width * 0.04

                    Rectangle {
                        width: appWindow.width * 0.18
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: areaSiestaOk.pressed ? "#a03030" : "#D64545"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Apagar"); font.pixelSize: parent.height * 0.32; font.bold: true; color: "white" }
                        MouseArea { id: areaSiestaOk; anchors.fill: parent; onClicked: { root.mostrarPopupSiesta = false; backend.apagarSistema() } }
                    }
                    Rectangle {
                        width: appWindow.width * 0.18
                        height: appWindow.height * 0.10
                        radius: height / 2
                        color: areaSiestaNo.pressed ? "#5a8282" : "#6E9C9C"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cancelar"); font.pixelSize: parent.height * 0.32; font.bold: true; color: "white" }
                        MouseArea { id: areaSiestaNo; anchors.fill: parent; onClicked: root.mostrarPopupSiesta = false }
                    }
                }
            }
        }
    }
}
