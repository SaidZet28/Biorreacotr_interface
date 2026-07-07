import QtQuick 2.15
import Prototipo
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_15"

    property bool modoBorrar: false
    property int itemsSeleccionados: 0
    property bool mostrarPopupConfirmarBorrado: false
    property bool mostrarPopupExportar: false
    property int itemExportarIndex: -1
    property string rutaUSBDetectada: ""
    property bool exportarExito: false
    property bool exportarError: false
    property bool exportarFueLocal: false

    Rectangle {
        id: cabeceraRegistro
        width: parent.width * 0.95
        height: appWindow.height * 0.08
        anchors.top: parent.top
        anchors.topMargin: appWindow.height * 0.18
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#6E9C9C"
        radius: height / 2

        Row {
            anchors.fill: parent
            anchors.leftMargin: parent.width * 0.02
            anchors.rightMargin: parent.width * 0.02
            spacing: parent.width * 0.01

            Item { width: parent.width * 0.04; height: parent.height }
            Item {
                width: parent.width * 0.18; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTranslate("Main", "Proyecto"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.18; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTranslate("Main", "Experimento"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.14; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTranslate("Main", "Fecha"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.18; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTranslate("Main", "Tiempo"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.12; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTranslate("Main", "Tamaño"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item { width: parent.width * 0.10; height: parent.height }
        }
    }

    Text {
        id: textoRutaBase
        anchors.top: cabeceraRegistro.bottom
        anchors.topMargin: appWindow.height * 0.008
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTranslate("Main", "Carpeta de datos: ") + backend.rutaBaseData()
        font.pixelSize: appWindow.height * 0.022
        color: "#555555"
        elide: Text.ElideMiddle
        width: parent.width * 0.95
    }

    ListView {
        id: listaRegistro
        width: parent.width * 0.95
        anchors.top: textoRutaBase.bottom
        anchors.topMargin: appWindow.height * 0.02
        anchors.bottom: filaControlesInferiores.top
        anchors.bottomMargin: appWindow.height * 0.02
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        spacing: appWindow.height * 0.02
        model: appWindow.registro_experimentos

        delegate: Rectangle {
            width: listaRegistro.width
            height: appWindow.height * 0.08
            color: "#8DBB5A"
            radius: height / 2

            Row {
                anchors.fill: parent
                anchors.leftMargin: parent.width * 0.02
                anchors.rightMargin: parent.width * 0.02
                spacing: parent.width * 0.01

                Item {
                    width: parent.width * 0.04
                    height: parent.height
                    Rectangle {
                        visible: root.modoBorrar
                        width: parent.height * 0.4
                        height: width
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: "black"
                        border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: "X"
                            font.pixelSize: parent.height * 0.8
                            font.bold: true
                            color: "black"
                            visible: model.seleccionado
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                appWindow.registro_experimentos.setProperty(index, "seleccionado", !model.seleccionado)
                                root.itemsSeleccionados += model.seleccionado ? 1 : -1
                            }
                        }
                    }
                }

                Item {
                    width: parent.width * 0.18; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: model.proyecto; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; elide: Text.ElideRight; width: parent.width - 10; horizontalAlignment: Text.AlignLeft }
                }
                Item {
                    width: parent.width * 0.18; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: model.experimento; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; elide: Text.ElideRight; width: parent.width - 10; horizontalAlignment: Text.AlignLeft }
                }
                Item {
                    width: parent.width * 0.14; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: model.fecha; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; horizontalAlignment: Text.AlignLeft }
                }
                Item {
                    width: parent.width * 0.18; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; width: parent.width - 10; text: model.tiempo; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; elide: Text.ElideRight; horizontalAlignment: Text.AlignLeft }
                }
                Item {
                    width: parent.width * 0.12; height: parent.height
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 10
                        width: parent.width - 10
                        text: model.peso
                        font.pixelSize: parent.height * 0.35
                        font.bold: true
                        color: "black"
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 8
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: parent.width * 0.10
                    height: parent.height
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.90
                        height: parent.height * 0.6
                        radius: height / 2
                        color: areaBotonExportar.pressed ? "#b5b5b5" : "#E0E0E0"
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Exportar"); font.pixelSize: parent.height * 0.35; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaBotonExportar
                            anchors.fill: parent
                            onClicked: {
                                root.itemExportarIndex = index
                                root.exportarExito = false
                                root.exportarError = false
                                root.rutaUSBDetectada = backend.detectarUSB()
                                root.mostrarPopupExportar = true
                            }
                        }
                    }
                }
            }
        }
    }

    Row {
        id: filaControlesInferiores
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: parent.width * 0.05
        spacing: 20

        Rectangle {
            width: appWindow.height * 0.10
            height: appWindow.height * 0.10
            radius: height / 2
            color: areaMouseBasura.pressed ? "#d1d5db" : "#F3F4F6"
            border.color: "black"
            border.width: 1
            Image {
                source: "../../Basura.png"
                anchors.centerIn: parent
                width: parent.width * 0.6
                height: parent.height * 0.6
                fillMode: Image.PreserveAspectFit
            }
            MouseArea {
                id: areaMouseBasura
                anchors.fill: parent
                onClicked: {
                    root.modoBorrar = !root.modoBorrar;
                    if (!root.modoBorrar) {
                        for (let i = 0; i < appWindow.registro_experimentos.count; i++) {
                            appWindow.registro_experimentos.setProperty(i, "seleccionado", false);
                        }
                        root.itemsSeleccionados = 0;
                    }
                }
            }
        }

        Rectangle {
            width: appWindow.width * 0.15
            height: appWindow.height * 0.10
            radius: height / 2
            color: areaMouseEliminar.pressed ? "#a02020" : "#FF2D2D"
            visible: root.modoBorrar && root.itemsSeleccionados > 0
            Text { anchors.centerIn: parent; text: qsTranslate("Main", "Borrar"); color: "white"; font.pixelSize: parent.height * 0.40; font.bold: true }
            MouseArea {
                id: areaMouseEliminar
                anchors.fill: parent
                onClicked: root.mostrarPopupConfirmarBorrado = true
            }
        }
    }

    Rectangle {
        id: botonAtras15
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: parent.width * 0.05
        width: parent.width * 0.12
        height: parent.height * 0.10
        color: areaMouseAtras15.pressed ? "#cc1e1e" : "#FF2D2D"
        radius: height / 2
        Text { anchors.centerIn: parent; text: "←"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
        MouseArea {
            id: areaMouseAtras15
            anchors.fill: parent
            onClicked: appWindow.estadoActual = "pantalla_principal"
        }
    }

    Item {
        anchors.fill: parent
        z: 200
        visible: root.mostrarPopupConfirmarBorrado
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
                text: qsTranslate("Main", "¿Seguro que deseas borrar los documentos seleccionados?")
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
                color: areaOkConfirmarBorrado.pressed ? "#6b42b5" : "#8b5cf6"
                radius: height / 2
                Text { anchors.centerIn: parent; text: qsTranslate("Main", "Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkConfirmarBorrado
                    anchors.fill: parent
                    onClicked: {
                        for (let i = appWindow.registro_experimentos.count - 1; i >= 0; i--) {
                            let item = appWindow.registro_experimentos.get(i);
                            if (item.seleccionado) {
                                backend.eliminarCarpetaExperimento(item.proyecto, item.experimento);
                                appWindow.registro_experimentos.remove(i);
                            }
                        }
                        root.itemsSeleccionados = 0;
                        root.modoBorrar = false;
                        root.mostrarPopupConfirmarBorrado = false;
                    }
                }
            }

            Rectangle {
                width: appWindow.width * 0.15
                height: appWindow.height * 0.08
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.15
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.10
                color: areaAtrasConfirmarBorrado.pressed ? "#cc1e1e" : "#FF2D2D"
                radius: height / 2
                Text { anchors.centerIn: parent; text: "←"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmarBorrado; anchors.fill: parent; onClicked: root.mostrarPopupConfirmarBorrado = false }
            }
        }
    }

    Item {
        anchors.fill: parent
        z: 300
        visible: root.mostrarPopupExportar
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        Rectangle {
            width: parent.width * 0.60
            height: parent.height * 0.50
            anchors.centerIn: parent
            color: Qt.rgba(0.8, 0.8, 0.8, 0.95)
            radius: 20

            // Botón regresar (esquina superior derecha)
            Rectangle {
                width: appWindow.width * 0.07
                height: appWindow.height * 0.07
                radius: height / 2
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.04
                anchors.right: parent.right
                anchors.rightMargin: parent.width * 0.03
                color: areaCerrarExportar.pressed ? "#cc1e1e" : "#FF2D2D"
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: parent.height * 0.65; font.bold: true; color: "black" }
                MouseArea {
                    id: areaCerrarExportar
                    anchors.fill: parent
                    onClicked: {
                        root.mostrarPopupExportar = false
                        root.exportarExito = false
                        root.exportarError = false
                        root.rutaUSBDetectada = ""
                    }
                }
            }

            // -- Estado: éxito ----------------------------------------------
            Column {
                anchors.centerIn: parent
                spacing: parent.height * 0.06
                visible: root.exportarExito

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "✓"
                    font.pixelSize: parent.parent.height * 0.18
                    color: "#2e7d32"
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.exportarFueLocal
                          ? qsTranslate("Main", "Archivo guardado\nlocalmente")
                          : qsTranslate("Main", "Archivo guardado\nen la USB")
                    font.pixelSize: parent.parent.height * 0.09
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: appWindow.width * 0.18
                    height: appWindow.height * 0.08
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: areaOkExitoExportar.pressed ? "#6b42b5" : "#8b5cf6"
                    radius: height / 2
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cerrar"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "black" }
                    MouseArea {
                        id: areaOkExitoExportar
                        anchors.fill: parent
                        onClicked: { root.mostrarPopupExportar = false; root.exportarExito = false; root.exportarFueLocal = false }
                    }
                }
            }

            // -- Estado: error al escribir ----------------------------------
            Column {
                anchors.centerIn: parent
                spacing: parent.height * 0.06
                visible: root.exportarError && !root.exportarExito

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "✗"
                    font.pixelSize: parent.parent.height * 0.18
                    color: "#c62828"
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTranslate("Main", "No se pudo guardar\nel archivo")
                    font.pixelSize: parent.parent.height * 0.09
                    font.bold: true
                    color: "black"
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: appWindow.width * 0.18
                    height: appWindow.height * 0.08
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: areaOkErrorExportar.pressed ? "#6b42b5" : "#8b5cf6"
                    radius: height / 2
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Cerrar"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "black" }
                    MouseArea {
                        id: areaOkErrorExportar
                        anchors.fill: parent
                        onClicked: { root.mostrarPopupExportar = false; root.exportarError = false }
                    }
                }
            }

            // -- Estado: USB detectada, listo para guardar ------------------
            Column {
                anchors.centerIn: parent
                spacing: parent.height * 0.05
                visible: !root.exportarExito && !root.exportarError && root.rutaUSBDetectada !== ""

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTranslate("Main", "USB detectada")
                    font.pixelSize: parent.parent.height * 0.10
                    font.bold: true
                    color: "black"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.rutaUSBDetectada
                    font.pixelSize: parent.parent.height * 0.07
                    color: "#444444"
                    elide: Text.ElideMiddle
                    width: parent.parent.width * 0.80
                    horizontalAlignment: Text.AlignHCenter
                }
                Rectangle {
                    width: appWindow.width * 0.22
                    height: appWindow.height * 0.09
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: areaGuardarUSB.pressed ? "#6b42b5" : "#8b5cf6"
                    radius: height / 2
                    Text { anchors.centerIn: parent; text: qsTranslate("Main", "Guardar en USB"); font.pixelSize: parent.height * 0.35; font.bold: true; color: "black" }
                    MouseArea {
                        id: areaGuardarUSB
                        anchors.fill: parent
                        onClicked: {
                            let item = appWindow.registro_experimentos.get(root.itemExportarIndex)
                            root.exportarFueLocal = false
                            let ok = backend.exportarRegistroCSV(root.rutaUSBDetectada, item.experimento, item.proyecto)
                            if (ok) { root.exportarExito = true }
                            else    { root.exportarError = true }
                        }
                    }
                }
            }

            // -- Estado: sin USB conectada ----------------------------------
            Row {
                anchors.centerIn: parent
                spacing: parent.width * 0.04
                visible: !root.exportarExito && !root.exportarError && root.rutaUSBDetectada === ""

                Image {
                    source: "../../Alerta.png"
                    height: parent.parent.height * 0.22
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: parent.parent.height * 0.06
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTranslate("Main", "Conecte una USB\ne intente de nuevo")
                        font.pixelSize: parent.parent.parent.height * 0.09
                        font.bold: true
                        color: "black"
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Rectangle {
                        width: appWindow.width * 0.18
                        height: appWindow.height * 0.08
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: areaReintentar.pressed ? "#6b42b5" : "#8b5cf6"
                        radius: height / 2
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Reintentar"); font.pixelSize: parent.height * 0.38; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaReintentar
                            anchors.fill: parent
                            onClicked: root.rutaUSBDetectada = backend.detectarUSB()
                        }
                    }
                    Rectangle {
                        width: appWindow.width * 0.22
                        height: appWindow.height * 0.08
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: areaGuardarLocal.pressed ? "#6b42b5" : "#8b5cf6"
                        radius: height / 2
                        Text { anchors.centerIn: parent; text: qsTranslate("Main", "Guardar localmente"); font.pixelSize: parent.height * 0.35; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaGuardarLocal
                            anchors.fill: parent
                            onClicked: {
                                let item = appWindow.registro_experimentos.get(root.itemExportarIndex)
                                root.exportarFueLocal = true
                                let ok = backend.exportarRegistroCSV("", item.experimento, item.proyecto)
                                if (ok) { root.exportarExito = true }
                                else    { root.exportarError = true }
                            }
                        }
                    }
                }

                Image {
                    source: "../../Alerta.png"
                    height: parent.parent.height * 0.22
                    fillMode: Image.PreserveAspectFit
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
