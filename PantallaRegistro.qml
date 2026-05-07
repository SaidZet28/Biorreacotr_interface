import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    property ApplicationWindow appWindow

    visible: appWindow.estadoActual === "pantalla_15"

    property bool modoBorrar: false
    property int itemsSeleccionados: 0
    property bool mostrarPopupConfirmarBorrado: false

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
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Proyecto"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.18; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Experimento"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.14; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Fecha"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.18; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Tiempo"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item {
                width: parent.width * 0.12; height: parent.height
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: qsTr("Tamaño"); font.pixelSize: parent.height * 0.45; font.bold: true; color: "black" }
            }
            Item { width: parent.width * 0.10; height: parent.height }
        }
    }

    ListView {
        id: listaRegistro
        width: parent.width * 0.95
        anchors.top: cabeceraRegistro.bottom
        anchors.topMargin: appWindow.height * 0.02
        anchors.bottom: filaControlesInferiores.top
        anchors.bottomMargin: appWindow.height * 0.02
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true
        spacing: appWindow.height * 0.02
        model: appWindow.registro_experimentos

        delegate: Rectangle {
            width: parent.width
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
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: model.tiempo; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; horizontalAlignment: Text.AlignLeft }
                }
                Item {
                    width: parent.width * 0.12; height: parent.height
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; text: model.peso; font.pixelSize: parent.height * 0.35; font.bold: true; color: "black"; horizontalAlignment: Text.AlignLeft }
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
                        Text { anchors.centerIn: parent; text: qsTr("Exportar"); font.pixelSize: parent.height * 0.35; font.bold: true; color: "black" }
                        MouseArea {
                            id: areaBotonExportar
                            anchors.fill: parent
                            onClicked: console.log("Exportar presionado para " + model.proyecto)
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
                source: "Basura.png"
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
            Text { anchors.centerIn: parent; text: qsTr("Borrar"); color: "white"; font.pixelSize: parent.height * 0.40; font.bold: true }
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
        Text { anchors.centerIn: parent; text: "↶"; color: "black"; font.pixelSize: parent.height * 0.70; font.bold: true }
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
                text: qsTr("¿Seguro que deseas borrar los documentos seleccionados?")
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
                Text { anchors.centerIn: parent; text: qsTr("Okay"); font.pixelSize: parent.height * 0.40; font.bold: true; color: "black" }
                MouseArea {
                    id: areaOkConfirmarBorrado
                    anchors.fill: parent
                    onClicked: {
                        for (let i = appWindow.registro_experimentos.count - 1; i >= 0; i--) {
                            if (appWindow.registro_experimentos.get(i).seleccionado) {
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
                Text { anchors.centerIn: parent; text: "↶"; font.pixelSize: parent.height * 0.70; font.bold: true; color: "black" }
                MouseArea { id: areaAtrasConfirmarBorrado; anchors.fill: parent; onClicked: root.mostrarPopupConfirmarBorrado = false }
            }
        }
    }
}
