import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_13"

    property bool mostrarPopupNoConfirmar: false
    property bool mostrarPopupIngresoNombre: false
    property bool mostrarPopupConfirmarDatos: false
    property bool mostrarPopupGuardado: false

    onVisibleChanged: {
        if (visible) {
            mostrarPopupNoConfirmar = false;
            mostrarPopupIngresoNombre = false;
            mostrarPopupConfirmarDatos = false;
            mostrarPopupGuardado = false;
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: appWindow.height * 0.10

        Text {
            text: qsTr("¿Desea guardar la\nconfiguración?")
            font.pixelSize: appWindow.height * 0.12
            font.bold: true
            color: "black"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            spacing: appWindow.width * 0.10
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                width: appWindow.width * 0.25
                height: appWindow.height * 0.15
                radius: 30
                color: areaBtnSi.pressed ? "#6b42b5" : "#8b5cf6"
                Text { anchors.centerIn: parent; text: qsTr("Si"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaBtnSi
                    anchors.fill: parent
                    onClicked: root.mostrarPopupIngresoNombre = true
                }
            }

            Rectangle {
                width: appWindow.width * 0.25
                height: appWindow.height * 0.15
                radius: 30
                color: areaBtnNo.pressed ? "#cc1e1e" : "#FF2D2D"
                Text { anchors.centerIn: parent; text: qsTr("No"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaBtnNo
                    anchors.fill: parent
                    onClicked: root.mostrarPopupNoConfirmar = true
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupNoConfirmar
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.60
            height: parent.height * 0.40
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20
            Text {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.15
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("¿Seguro que no deseas guardar la configuración?")
                font.pixelSize: parent.height * 0.08
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
                width: parent.width * 0.9
                wrapMode: Text.WordWrap
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.left: parent.left
                anchors.leftMargin: parent.width * 0.10
                color: areaOkNoConfirmado.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkNoConfirmado
                    anchors.fill: parent
                    onClicked: { root.mostrarPopupNoConfirmar = false; appWindow.estadoActual = "pantalla_14"; }
                }
            }
            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasNoConfirmado.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasNoConfirmado; anchors.fill: parent; onClicked: root.mostrarPopupNoConfirmar = false }
            }
        }
    }

    PopupIngresoNombre {
        id: popupGuardadoProyecto13
        visible: root.mostrarPopupIngresoNombre
        tituloPopup: qsTr("Ingrese el nombre del proyecto")
        nombrePorDefecto: ""
        onAceptado: function(name) {
            var nombreFinal = name.trim();
            if (nombreFinal === "") {
                var d = new Date();
                nombreFinal = ("0" + d.getDate()).slice(-2) + "/" + ("0" + (d.getMonth() + 1)).slice(-2) + "/" + d.getFullYear() + "_" + ("0" + d.getHours()).slice(-2) + "_" + ("0" + d.getMinutes()).slice(-2);
            }
            appWindow.var_nombre_proyecto = nombreFinal;
            root.mostrarPopupIngresoNombre = false;
            root.mostrarPopupConfirmarDatos = true;
        }
        onCancelado: {
            root.mostrarPopupIngresoNombre = false;
        }
    }

    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupConfirmarDatos
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            id: cajaPopupGuardar13
            width: parent.width * 0.85
            height: parent.height * 0.65
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20

            Text {
                anchors.top: parent.top
                anchors.topMargin: cajaPopupGuardar13.height * 0.05
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.9
                text: qsTr("El proyecto se guardará como:")
                font.pixelSize: cajaPopupGuardar13.height * 0.06
                font.bold: false
                color: "#cc0000"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: cajaPopupGuardar13.height * 0.02
                width: parent.width * 0.90
                spacing: cajaPopupGuardar13.height * 0.03

                Text {
                    textFormat: Text.RichText
                    text: qsTr("Proyecto: <b>%1</b>").arg(appWindow.var_nombre_proyecto)
                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
                Row {
                    width: parent.width
                    spacing: parent.width * 0.02
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTr("Temperatura: <b>%1 °%2</b>").arg(appWindow.var_deseada_Tem).arg(appWindow.unidadTemperatura)
                        font.pixelSize: cajaPopupGuardar13.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTr("Nivel de pH: <b>%1</b>").arg(appWindow.var_deseada_pH)
                        font.pixelSize: cajaPopupGuardar13.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                }
                Row {
                    width: parent.width
                    spacing: parent.width * 0.02
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTr("Nivel de agua: <b>%1 %</b>").arg(appWindow.var_deseada_Agua)
                        font.pixelSize: cajaPopupGuardar13.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        width: (parent.width/2)-(parent.width*0.01)
                        textFormat: Text.RichText
                        text: qsTr("Nivel de luz: <b>%1 %</b>").arg(appWindow.var_deseada_Luz)
                        font.pixelSize: cajaPopupGuardar13.height * 0.055
                        color: "black"
                        wrapMode: Text.WordWrap
                    }
                }
                Text {
                    textFormat: Text.RichText
                    text: qsTr("Tiempo: Semanas <b>%1</b>, Días <b>%2</b>, Horas <b>%3</b>, Minutos <b>%4</b> (Total: <b>%5 Hrs</b>)").arg(appWindow.var_deseada_tiempo_semanas).arg(appWindow.var_deseada_tiempo_dias).arg(appWindow.var_deseada_tiempo_horas).arg(appWindow.var_deseada_tiempo_minutos).arg(appWindow.var_deseada_tiempo_total_horas.toFixed(1))
                    font.pixelSize: cajaPopupGuardar13.height * 0.055
                    color: "black"
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: appWindow.width * 0.05
                anchors.bottomMargin: parent.height * 0.05
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                color: areaOkGuardarFinal.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTr("Okay"); color: "black"; font.pixelSize: parent.height * 0.40; font.bold: true }
                MouseArea {
                    id: areaOkGuardarFinal
                    anchors.fill: parent
                    onClicked: {
                        let lastIdx = appWindow.registro_experimentos.count - 1;
                        if (lastIdx >= 0) {
                            appWindow.registro_experimentos.setProperty(lastIdx, "proyecto", appWindow.var_nombre_proyecto);
                        }
                        appWindow.datos_guardados.append({
                            nombre: appWindow.var_nombre_proyecto,
                            temp: appWindow.var_deseada_Tem,
                            ph: appWindow.var_deseada_pH,
                            agua: appWindow.var_deseada_Agua,
                            luz: appWindow.var_deseada_Luz,
                            tiempo: appWindow.var_deseada_tiempo_total_horas.toFixed(1)
                        });
                        root.mostrarPopupConfirmarDatos = false;
                        root.mostrarPopupGuardado = true;
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: appWindow.width * 0.05
                anchors.bottomMargin: parent.height * 0.05
                width: appWindow.width * 0.12
                height: appWindow.height * 0.10
                color: areaAtrasGuardarFinal.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
                MouseArea {
                    id: areaAtrasGuardarFinal
                    anchors.fill: parent
                    onClicked: { root.mostrarPopupConfirmarDatos = false; root.mostrarPopupIngresoNombre = true; }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupGuardado
        MouseArea { anchors.fill: parent; hoverEnabled: true }
        Rectangle {
            width: parent.width * 0.65
            height: parent.height * 0.55
            anchors.centerIn: parent
            color: Qt.rgba(0.7, 0.7, 0.7, 0.95)
            radius: 20
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.10
                text: qsTr("Guardado :D")
                font.pixelSize: parent.height * 0.25
                font.bold: true
                color: "black"
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: appWindow.width * 0.20
                height: appWindow.height * 0.10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                color: areaOkPopGuardado.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkPopGuardado
                    anchors.fill: parent
                    onClicked: { root.mostrarPopupGuardado = false; appWindow.estadoActual = "pantalla_14"; }
                }
            }
        }
    }
}
